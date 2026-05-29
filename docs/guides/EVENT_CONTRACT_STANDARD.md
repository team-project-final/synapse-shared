# Synapse 이벤트 계약 표준 (Avro + Schema Registry) — 초안

> **작성일**: 2026-05-29 · **갱신**: 2026-05-29(방향 전환) · **작성자**: @team-lead · **상태**: 초안
> **결정**: [D-002](../designs/D-002_SCHEMA_FAMILY_DECISION.md) **Option 1 채택 — Avro + Confluent Schema Registry 사수** (PRD "모든 producer 토픽 Registry BACKWARD 등록" 준수)
> **⏰ 구성 완료 기한: W4 1~2일차 (2026-06-01 ~ 06-02)** — 이후 통합/E2E·배포가 여기에 의존

---

## 0. 왜 이 표준이 필요한가 (한 문단)

지금 각 서비스가 Kafka 메시지를 **서로 다른 형식**(누구는 Confluent Avro, 누구는 수동 Avro, 누구는 JSON)으로 보내 **서로 못 읽는다**. 이 문서는 **모든 서비스가 똑같이 따르는 단 하나의 형식 = Avro + Schema Registry**를 정한다. 스키마 정의의 단일 출처는 **synapse-shared**다.

핵심 3가지:
1. **스키마 출처**: 모든 이벤트 Avro 스키마(`.avsc`)는 **synapse-shared가 소유**(`src/main/avro/`). 서비스는 이를 가져다 쓴다(§3).
2. **직렬화**: **Confluent `KafkaAvroSerializer`/`KafkaAvroDeserializer` + Schema Registry**(호환성 `BACKWARD`).
3. **카탈로그**: 토픽·이벤트·필드·발행/소비를 표로 고정(§2). 토픽당 1개 Avro 레코드(타입드).

---

## 1. 메시지 형식 (Avro 레코드)

- **토픽당 value = 단일 Avro 레코드**(bare typed record). 별도 `data:bytes` 중첩 봉투는 **금지**(레지스트리가 페이로드를 검증 못 함).
- 네임스페이스는 **`com.synapse.*`** 로 통일(예: `com.synapse.knowledge.NoteCreated`). 기존 상이 네임스페이스(`com.synapse.event.*`, `com.synapse.learning.event`)·이벤트명(`CardReviewed`)은 본 표준으로 정렬.
- **공통 메타 필드**(모든 이벤트 레코드 필수): `eventId`(string, UUID — 멱등성 키), `tenantId`(string), `occurredAt`(long, timestamp-millis). + 선택 `traceparent`(["null","string"]).
- 시간 표현: `*-At` 필드는 `long`(timestamp-millis) 권장.

---

## 2. 토픽 & 이벤트 카탈로그 (고정)

| 토픽 | Avro 레코드 (`com.synapse.*`) | Producer | Consumer | 도메인 필드(공통 메타 외) |
|------|------|----------|----------|------------|
| `platform.auth.user-registered-v1` | `platform.UserRegistered` | platform | engagement | userId, email, displayName |
| `knowledge.note.note-created-v1` | `knowledge.NoteCreated` | knowledge | learning-ai | noteId, userId, deckId, title |
| `knowledge.note.note-updated-v1` | `knowledge.NoteUpdated` | knowledge | learning-ai | noteId, userId, title |
| `learning.card.review-completed-v1` | `learning.ReviewCompleted` | learning-card | engagement | userId, cardId, rating(AGAIN\|HARD\|GOOD\|EASY), nextReviewAt |
| `learning.card.review-due-v1` | `learning.CardReviewDue` | learning-card | platform(알림,W4) | userId, dueCardCount, dueDate |
| `engagement.gamification.level-up-v1` | `engagement.LevelUp` | engagement | platform(알림,W4) | userId, newLevel *(owner 확정)* |
| `engagement.gamification.badge-earned-v1` | `engagement.BadgeEarned` | engagement | platform(알림,W4) | userId, badgeId *(owner 확정)* |
| `platform.notification.notification-send-v1` | `platform.NotificationSend` | 다수(learning-ai 등) | platform | userId, notificationType, channels[], title, body, emailSubject?, emailHtmlBody? |

> ❌ `learning.ai.cards-generated-v1` 제외 — 카드 등록은 HTTP([D-001](./EVENT_FLOW_MATRIX.md)). 노트 본문은 learning-ai가 `note_client`(HTTP)로 조회.
> ⚠️ 레코드명/필드 단일 출처 = synapse-shared `src/main/avro/`. 변경은 PR + `schema-check`(BACKWARD) 통과 필요.

---

## 3. synapse-shared 스키마 사용법

**스키마 출처**: synapse-shared `src/main/avro/**/*.avsc` (단일 출처). 가져오는 방법 2가지:

### (현행 권장) .avsc 벤더링 + Avro 플러그인 코드생성 — Java
shared 라이브러리가 아직 레포에 배포되지 않으므로(아래 §6), **필요한 `.avsc`를 자기 서비스 `src/main/avro/`로 복사**하고 Gradle Avro 플러그인으로 클래스 생성:
```kotlin
plugins { id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1" }
dependencies {
    implementation("org.apache.avro:avro:1.12.0")
    implementation("io.confluent:kafka-avro-serializer:7.7.0")
}
```
> 벤더링한 `.avsc`는 **shared 원본과 동일 유지**(임의 수정 금지, 변경은 shared PR로). 향후 §6 라이브러리 발행이 완료되면 `implementation("com.synapse:shared:<ver>")` 의존으로 전환.

### Python (learning-ai)
`confluent-kafka[avro]`의 `AvroDeserializer`/`AvroSerializer` + `SchemaRegistryClient`로 **레지스트리에서 스키마를 받아** 직렬화(코드생성 불필요).

---

## 4. Kafka 설정 (복붙용)

### 4.1 Java (Spring Boot) `application.yml`
```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}        # compose 내부: kafka:29092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
      acks: all
      properties:
        schema.registry.url: ${SCHEMA_REGISTRY_URL:http://localhost:8086}   # compose 내부: http://schema-registry:8081
        auto.register.schemas: true
    consumer:
      group-id: <서비스명>-svc-group
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
      auto-offset-reset: earliest
      properties:
        schema.registry.url: ${SCHEMA_REGISTRY_URL:http://localhost:8086}
        specific.avro.reader: true     # 생성된 SpecificRecord로 역직렬화
```
- 메시지 **key = `tenantId`**(같은 테넌트 순서 보장). subject = `<topic>-value`(기본 TopicNameStrategy), 호환 `BACKWARD`.

발행/소비 예:
```java
kafkaTemplate.send("knowledge.note.note-created-v1", tenantId, noteCreated); // NoteCreated = 생성된 SpecificRecord

@KafkaListener(topics = "platform.auth.user-registered-v1", groupId = "engagement-svc-group")
public void on(UserRegistered ev) { /* ev.getEventId() 중복 체크 후 처리 */ }
```

### 4.2 Python (learning-ai)
```python
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer, AvroSerializer
# SchemaRegistryClient({'url': SCHEMA_REGISTRY_URL}) 로 subject 스키마 fetch
```
- consumer group = `learning-ai-svc-group`.

---

## 5. 공통 규칙
- **멱등성**: `eventId`로 중복 처리 방지(이미 처리한 id는 skip). 예: 동일 reviewId 재수신 시 XP 중복 적립 금지.
- **에러 처리**: 역직렬화/검증 실패 → 에러 로그 + skip(크래시 금지). learning-ai는 DLQ.
- **컨슈머 그룹**: `{서비스명}-svc-group`.
- **스키마 변경**: shared `.avsc` PR → `schema-check.yml`(BACKWARD) 통과 → 각 서비스 재벤더링/재생성.
- **토픽 생성**: `synapse-shared/scripts/create-kafka-topics.sh` — 신규 토픽(review-due/level-up/badge-earned/notification-send) **추가 완료**. 로컬: `kafka-init`이 자동 생성, 또는 `REPLICATION_FACTOR=1 KAFKA_BROKERS=localhost:9092 bash scripts/create-kafka-topics.sh`.

## 6. 배포 메커니즘 (D-002 §7 선결 — shared/team-lead)
현재 shared는 **라이브러리로 배포되지 않음**(publish 대상 미설정·소비 가이드 부재). 단기엔 §3 **벤더링**으로 진행하되, 다음을 확정:
- (a) **Schema Registry를 런타임 단일 출처**로 — shared가 전 스키마를 레지스트리에 등록(BACKWARD), 서비스는 레지스트리에서 소비.
- (b) shared **Java 라이브러리 발행**(발행 repo 지정) → `com.synapse:shared` 의존으로 전환.
- svc-template에도 위 설정 배선.

## 7. 로컬 검증
```bash
bash scripts/kafka-e2e-test.sh --scenarios   # synapse-shared 레포
```

## 8. 미확정(owner 합의)
1. `LevelUp`/`BadgeEarned` 필드 확정(engagement).
2. `NoteCreated.title` 포함 여부(knowledge·learning-ai).
3. 공통 메타 필드(`eventId`,`occurredAt`)를 기존 shared `.avsc`에 추가(현재 일부 누락) — shared PR.
4. Schema Registry 로컬 포트 통일(8086 vs 8081 혼재).
