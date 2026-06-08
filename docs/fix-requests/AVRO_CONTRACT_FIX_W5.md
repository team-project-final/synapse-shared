# 수정 요청: Avro 이벤트 계약 정합 (W5 Day1 발견 P0 2건)

> 작성일: 2026-06-08 · 우선순위: **P0 (Day 2 전체 E2E 차단)** · 근거: [E2E_SMOKE_W5_DAY1](../reports/E2E_SMOKE_W5_DAY1.md) §2
> 정본: synapse-shared `src/main/avro/platform/{UserRegistered,NotificationSend}.avsc` — **2026-06-08 표준 정렬 완료** (platform 라이브 writer와 필드 단위 동일, 레지스트리 BACKWARD `is_compatible:true` 검증)
> 규칙: 벤더링 .avsc는 shared 원본과 동일 유지 ([EVENT_CONTRACT_STANDARD §3](../guides/EVENT_CONTRACT_STANDARD.md))

## @engagement owner — F1: UserRegistered reader 깨짐 (P0)

**증상(라이브 재현)**: `platform.auth.user-registered-v1` 소비 시 매 메시지
`AvroTypeException: missing required field registeredAt` → 가입→게이미피케이션 체인 전멸. **dev 브랜치도 동일.**

**원인**: `src/main/avro/platform/UserRegistered.avsc`가 구형(default 없는 `registeredAt` 요구) — platform writer는 이 필드를 발행한 적 없음.

**수정**: shared 정본 `src/main/avro/platform/UserRegistered.avsc`를 그대로 복사(벤더링 교체) 후 코드 재생성.
- 필드: eventId · tenantId · occurredAt(long) · traceparent? · userId · email · displayName
- `registeredAt` 사용 코드가 있으면 `occurredAt`(epoch millis)로 대체
- 참고: 동일 정본으로 `learning/ReviewCompleted.avsc`도 eventId/occurredAt 포함 — 함께 정렬 권장(현재는 비파괴라 P2)

## @learning owner — F2+F3: learning-ai NotificationSend writer 깨짐 (P0)

**증상(정적 확정)**: learning-ai가 발행하는 `platform.notification.notification-send-v1`를 platform이 역직렬화 불가 → 노트→AI카드→알림 체인 전멸.
1. record full-name 불일치: `com.synapse.event.platform.NotificationSend` vs reader `com.synapse.platform.NotificationSend`
2. reader 필수 `eventId`/`occurredAt`이 writer 스키마에 없음

**원인**: `learning-ai/app/kafka/notification_producer.py`의 인라인 스키마가 shared 구 DRAFT(`com.synapse.event.platform`)를 따름 — 해당 DRAFT는 2026-06-08 폐기.

**수정**: 인라인 스키마를 shared 정본 `NotificationSend.avsc`와 동일하게 교체:
- namespace `com.synapse.platform`
- 공통 메타 4종 추가: `eventId`(UUID 문자열) · `tenantId` · `occurredAt`(epoch millis long) · `traceparent`(nullable, default null)
- 기존 `data` map에 넣던 eventId는 최상위 `eventId` 필드로 이동

## 검증 방법 (공통)

synapse-shared 루트에서 서비스 단위 E2E 스택 기동 후 시나리오 재실행:
```bash
docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --build
# 가입 스모크: POST http://localhost:8080/api/platform/api/v1/auth/signup → engagement 로그에 역직렬화 에러 없어야 함
# 알림: 노트 생성 → learning-ai 발행 → platform notification consumer 정상 소비
```

## 참고 — P2 (비차단)

- **F4 (@learning)**: learning-ai가 API 키 빈 값이면 기동 자체 실패 (`main.py` lifespan에서 클라이언트 무조건 생성) → KAFKA_ENABLED 패턴처럼 게이트 권장
- **engagement ReviewCompleted reader**: eventId/occurredAt 누락 (소비는 정상, 멱등성 키를 cardId+reviewedAt로 대체 중) → 정본 정렬 권장
