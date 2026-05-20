# W3 팀원 Kafka 구현 체크리스트

> **목적**: W3~W4 Kafka E2E 검증 전에 각 서비스가 준비해야 할 항목

## 공통 요구사항

모든 Producer/Consumer는 다음을 충족해야 합니다:

- [ ] **Avro 직렬화/역직렬화**: Schema Registry 연동 (`KafkaAvroSerializer`/`KafkaAvroDeserializer`)
- [ ] **CloudEvent 래핑**: `CloudEventEnvelope.avsc` 기반 (specversion, id, source, type, subject, time, tenantid, traceparent)
- [ ] **Consumer Group**: 서비스명 기반 (`{service-name}-group`)
- [ ] **에러 핸들링**: 역직렬화 실패 시 로그 + 스킵 (DLT 전송은 Phase 2)
- [ ] **멱등성**: 동일 이벤트 재처리 시 부작용 없음 (eventId 기반 중복 체크)
- [ ] **application.yml 설정**: Kafka bootstrap, Schema Registry URL, consumer group

### 공통 Kafka 설정 예시 (application.yml)

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BROKERS:kafka:29092}
    properties:
      schema.registry.url: ${SCHEMA_REGISTRY_URL:http://schema-registry:8081}
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
    consumer:
      group-id: ${spring.application.name}-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
      properties:
        specific.avro.reader: true
```

## 서비스별 체크리스트

### platform-svc

**Producer:**
- [ ] `UserRegistered` 이벤트 발행 → `platform.auth.user-registered-v1`
- [ ] 회원가입 API 성공 후 이벤트 발행
- [ ] 단위 테스트: Producer mock으로 이벤트 발행 검증

**Consumer:**
- [ ] `CardsGenerated` 이벤트 수신 ← `learning.ai.cards-generated-v1`
- [ ] 알림 트리거 로직 구현
- [ ] 단위 테스트: Consumer mock으로 이벤트 처리 검증

### knowledge-svc

**Producer:**
- [ ] `NoteCreated` 이벤트 발행 → `knowledge.note.note-created-v1`
- [ ] `NoteUpdated` 이벤트 발행 → `knowledge.note.note-updated-v1`
- [ ] 노트 생성/수정 API 성공 후 이벤트 발행
- [ ] 단위 테스트

**Consumer:** 없음

### learning-card-svc

**Producer:**
- [ ] `ReviewCompleted` 이벤트 발행 → `learning.card.review-completed-v1`
- [ ] 카드 복습 API 성공 후 이벤트 발행
- [ ] 단위 테스트

**Consumer:** 없음

### learning-ai-svc

**Producer:**
- [ ] `CardsGenerated` 이벤트 발행 → `learning.ai.cards-generated-v1`
- [ ] AI 카드 생성 완료 후 이벤트 발행
- [ ] Python Avro 직렬화 (`confluent-kafka[avro]` 패키지)

**Consumer:**
- [ ] `NoteCreated` 이벤트 수신 ← `knowledge.note.note-created-v1`
- [ ] 노트 수신 → AI 카드 생성 파이프라인 트리거
- [ ] Consumer group: `learning-ai-svc-group`

### engagement-svc

**Consumer:**
- [ ] `UserRegistered` 이벤트 수신 ← `platform.auth.user-registered-v1`
- [ ] 프로필 레코드 자동 생성
- [ ] `ReviewCompleted` 이벤트 수신 ← `learning.card.review-completed-v1`
- [ ] XP 포인트 적립 로직
- [ ] 멱등성 처리 (동일 reviewId 중복 적립 방지)

**Producer:** 없음

## 완료 기준

각 서비스가 아래를 모두 충족하면 E2E 검증 시작:

1. Docker Compose로 기동 시 Kafka 연결 성공 (로그 확인)
2. Producer: API 호출 → 토픽에 메시지 발행 확인 (`kafka-console-consumer`로 확인)
3. Consumer: 토픽 메시지 수신 → 비즈니스 로직 실행 확인 (로그 + DB 확인)
4. 단위 테스트 통과

## E2E 검증 가이드

구현 완료 후 `docs/guides/KAFKA_E2E_TEST.md`의 시나리오를 순서대로 실행하세요.
