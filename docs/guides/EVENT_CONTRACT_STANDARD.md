# Synapse 이벤트 계약 표준 (CloudEvent JSON) — 초안

> **작성일**: 2026-05-29 · **작성자**: @team-lead · **상태**: 초안(팀 비준 대기)
> **결정 근거**: [D-002_SCHEMA_FAMILY_DECISION](../designs/D-002_SCHEMA_FAMILY_DECISION.md) Option 2 채택안
> **⏰ 구성 완료 기한: W4 1~2일차 (2026-06-01 ~ 06-02)** — 이후 통합/E2E·배포 일정이 여기에 의존

---

## 0. 왜 이 표준이 필요한가 (한 문단)

지금 각 서비스가 Kafka 메시지를 **서로 다른 형식**(누구는 Avro, 누구는 JSON, 필드 이름도 제각각)으로 보내고 있어 **A 서비스가 보낸 메시지를 B 서비스가 읽지 못한다**. 이 문서는 **모든 서비스가 똑같이 따르는 단 하나의 메시지 형식**을 정한다. 이대로만 맞추면 서비스끼리 이벤트가 오간다.

핵심 3가지:
1. **봉투(Envelope)**: 모든 메시지는 아래 CloudEvent JSON 형태로 감싼다.
2. **카탈로그**: 어떤 토픽에 어떤 이벤트를, 누가 보내고 누가 받는지 표로 고정.
3. **Kafka 설정**: 직렬화는 **JSON(문자열)**, 컨슈머 그룹·키 규칙 통일.

---

## 1. CloudEvent JSON 봉투 (모든 메시지 공통)

메시지 value는 **항상 이 JSON 한 덩어리**다. 실제 데이터는 `data` 안에 넣는다.

```json
{
  "specversion": "1.0",
  "id": "9f1c...uuid",                         // 이벤트 고유 ID(UUID) — 중복처리 기준
  "source": "knowledge-svc",                   // 보낸 서비스 이름
  "type": "com.synapse.knowledge.NoteCreated", // 이벤트 종류
  "subject": "note/123",                       // (선택) 대상 식별
  "time": "2026-06-01T09:00:00Z",              // RFC3339 문자열(UTC)
  "tenantid": "tenant-uuid",                   // 테넌트 ID
  "datacontenttype": "application/json",
  "traceparent": null,                         // (선택) 분산추적
  "data": {                                    // ▼ 이벤트별 실제 내용(아래 §2)
    "noteId": "123", "userId": "u1", "tenantId": "tenant-uuid", "deckId": "d1", "title": "..."
  }
}
```

규칙:
- 필드 이름은 **camelCase**로 통일한다(예: `userId`, `noteId`). Python(learning-ai)은 내부 snake_case ↔ 직렬화 시 camelCase로 매핑.
- `time`은 문자열(RFC3339, UTC `Z`). (숫자 timestamp 금지 — 기존 platform `long` 방식은 이 표준으로 교체)
- `data` 안 필드는 §2 카탈로그를 따른다.

---

## 2. 토픽 & 이벤트 카탈로그 (고정)

| 토픽 | type | Producer | Consumer | `data` 필드 |
|------|------|----------|----------|-------------|
| `platform.auth.user-registered-v1` | `...platform.UserRegistered` | platform | engagement | userId, tenantId, email, displayName, registeredAt |
| `knowledge.note.note-created-v1` | `...knowledge.NoteCreated` | knowledge | learning-ai | noteId, userId, tenantId, deckId, title |
| `knowledge.note.note-updated-v1` | `...knowledge.NoteUpdated` | knowledge | learning-ai | noteId, userId, tenantId, title, updatedAt |
| `learning.card.review-completed-v1` | `...learning.ReviewCompleted` | learning-card | engagement | userId, tenantId, cardId, rating(AGAIN\|HARD\|GOOD\|EASY), nextReviewAt, reviewedAt |
| `learning.card.review-due-v1` | `...learning.CardReviewDue` | learning-card | platform(알림, W4) | userId, tenantId, dueCardCount, dueDate |
| `engagement.gamification.level-up-v1` | `...engagement.LevelUp` | engagement | platform(알림, W4) | userId, tenantId, newLevel *(필드 owner 확정)* |
| `engagement.gamification.badge-earned-v1` | `...engagement.BadgeEarned` | engagement | platform(알림, W4) | userId, tenantId, badgeId *(필드 owner 확정)* |
| `platform.notification.notification-send-v1` | `...platform.NotificationSend` | 다수(learning-ai 등) | platform | userId, tenantId, notificationType, channels[], title, body, emailSubject?, emailHtmlBody? |

> ❌ `learning.ai.cards-generated-v1`은 **제외** — 카드 등록은 HTTP로 처리([D-001](../guides/EVENT_FLOW_MATRIX.md)). 노트 본문이 필요한 경우 learning-ai가 `note_client`(HTTP)로 조회.
> ⚠️ 이벤트명/필드는 본 표준이 단일 출처. 기존 상이 명칭(예: learning-card `CardReviewed` → `ReviewCompleted`)은 본 표로 정렬.

---

## 3. Kafka 설정 (복붙용)

### 3.1 Java (Spring Boot) — `application.yml`

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}   # 로컬 compose 내부는 kafka:29092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer   # JSON 문자열 직접 전송
      acks: all
    consumer:
      group-id: <서비스명>-svc-group       # 예: engagement-svc-group
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      auto-offset-reset: earliest
```

- value는 **StringSerializer**로 두고, CloudEvent 객체 ↔ JSON 문자열 변환은 **Jackson `ObjectMapper`** 로 직접 한다(서비스 간 타입 헤더 의존 제거 → 언어 무관 호환).
- 메시지 **key = `tenantId`**(또는 집계 루트 ID) — 같은 테넌트 이벤트 순서 보장.

발행 예:
```java
String json = objectMapper.writeValueAsString(cloudEvent);   // CloudEvent → JSON
kafkaTemplate.send("knowledge.note.note-created-v1", tenantId, json);
```
소비 예:
```java
@KafkaListener(topics = "platform.auth.user-registered-v1", groupId = "engagement-svc-group")
public void on(String json) {
    CloudEvent ev = objectMapper.readValue(json, CloudEvent.class);
    // ev.data 처리 (멱등성: ev.id 중복 체크)
}
```

### 3.2 Python (FastAPI, learning-ai) — 이미 JSON 사용 중

```python
# 발행
await producer.send_and_wait(topic, json.dumps(cloud_event).encode("utf-8"), key=tenant_id.encode())
# 소비 (기존 consumer.py 유지) — 봉투에서 data 추출 후 처리
```
- 내부 모델은 snake_case 유지하되, **봉투/`data` 직렬화 시 camelCase**로 매핑(alias).

---

## 4. 공통 규칙

- **멱등성**: 컨슈머는 `envelope.id`(이벤트 ID)로 중복 처리 방지(이미 처리한 id는 skip). 예: 동일 reviewId 재수신 시 XP 중복 적립 금지.
- **에러 처리**: 역직렬화/검증 실패 → **에러 로그 + 메시지 skip**(서비스 크래시 금지). learning-ai는 DLQ로 보냄.
- **컨슈머 그룹**: `{서비스명}-svc-group` 고정.
- **토픽 생성**: 로컬은 `synapse-shared/scripts/create-kafka-topics.sh`. 신규 토픽(`review-due`, `level-up`, `badge-earned`, `notification-send`)은 이 스크립트에 추가 필요.

## 5. 로컬 검증

```bash
# synapse-shared 레포에서 — 토픽별 발행/소비 라운드트립
bash scripts/kafka-e2e-test.sh --scenarios
```
- `"specversion"` 문자열 검증은 JSON CloudEvent에도 그대로 유효.

## 6. 미확정(owner 합의 필요)

1. `LevelUp`/`BadgeEarned` `data` 필드 확정(engagement owner).
2. `NoteCreated` `title` 포함 여부(없으면 learning-ai가 전부 HTTP 조회) — knowledge·learning-ai 합의.
3. 신규 토픽 4종 파티션/보존 설정.
