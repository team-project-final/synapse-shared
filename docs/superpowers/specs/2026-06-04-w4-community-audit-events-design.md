# W4 이벤트 체인 완성 설계 — S5 커뮤니티 알림 + S6 감사 로그 (2026-06-04)

> **상태**: ✅ 설계 승인 (2026-06-04). 출처: `docs/w1-w3-closure-design` 브랜치의 E2E_SCENARIOS_W3 S5/S6 선반영 설계를 구현 설계로 구체화.
> **관련**: [E2E_SCENARIOS_W3 S5/S6](../../guides/E2E_SCENARIOS_W3.md) · [EVENT_FLOW_MATRIX](../../guides/EVENT_FLOW_MATRIX.md) · [NotificationSend.avsc](../../../src/main/avro/platform/NotificationSend.avsc) · [NOTIFICATION_TRIGGER_AI_CARDS](../../designs/NOTIFICATION_TRIGGER_AI_CARDS.md)

## 1. 목표 / 범위

W3에서 설계만 선반영하고 구현은 W4로 이월한 두 이벤트 체인을 완성한다.

- **S5 (engagement-svc)**: 커뮤니티 신고 모더레이션 결정 시 알림 발행 — 신고자·피신고자에게.
- **S6 (platform-svc)**: 감사 소비자를 단일 토픽(user-registered)에서 전 도메인 상태변경 토픽으로 확장 → `audit_logs` 적재.

**두 작업은 서로 다른 서비스/레포의 독립 단위**다. 본 문서는 단일 설계, **구현은 레포별 별도 플랜/PR**. 유일한 공통 의존은 shared `NotificationSend` Avro 계약(S5).

## 2. 확정 결정

| # | 결정 | 근거 |
|---|---|---|
| D-S5-1 | 알림 수신자 = **신고자 + 피신고자** | 모더레이션 결과 양측 통지(완성된 체인) |
| D-S5-2 | 발행 패턴 = engagement **직접 KafkaTemplate**(gamification 미러), outbox 아님 | 기존 `GamificationKafkaProducer` 패턴 일치 |
| D-S6-1 | 감사 범위 = **도메인 상태변경 토픽 전부**(전송/스케줄 토픽 제외) | "각 서비스 이벤트 → audit_logs" 의도, 감사 가치 |
| D-S6-2 | 소비자 구조 = **타입별 @KafkaListener**(범용 봉투 아님) | 기존 `AuditKafkaConsumer` 패턴, audit_logs 범용 스키마의 정밀 매핑 전제 |

## 3. S5 — 모더레이션 → 알림 발행 (engagement-svc)

### 3.1 컴포넌트 (gamification 패턴 미러)
- `CommunityNotificationPublisher` (인터페이스): `publishModerationResult(...)`.
- `CommunityNotificationKafkaProducer implements CommunityNotificationPublisher` — `@ConditionalOnProperty(prefix="synapse.kafka", name="enabled", havingValue="true")`, `KafkaTemplate<String, SpecificRecord>`, 토픽 `${synapse.kafka.topics.notification-send}` = `platform.notification.notification-send-v1`.
- `NoopCommunityNotificationPublisher` — Kafka 비활성 시 무발행(기능 degrade).

### 3.2 훅 — `ModerationService.moderate(reportId, request)`
현재 분기: `APPROVED`(콘텐츠 숨김 — `hideTarget`) / `REJECTED`. 각 분기 **커밋 후 best-effort 발행**:

| 결정 | 신고자(reporterId) | 피신고자(콘텐츠 소유자) |
|---|---|---|
| APPROVED | `notificationType=REPORT_RESOLVED`, "신고가 처리되어 콘텐츠가 제재되었습니다" | `notificationType=CONTENT_REMOVED`, "회원님의 콘텐츠가 신고로 제재되었습니다" |
| REJECTED | `notificationType=REPORT_REJECTED`, "신고가 기각되었습니다" | (발행 없음) |

`channels=[FCM]`, `data={reportId, targetType}`, eventId=UUID(봉투), userId=수신자, tenantId=리포트 테넌트.

### 3.3 피신고자 userId 해결 (서브태스크)
`Report`는 `targetType`/`targetId`만 보유 → 콘텐츠 소유자 userId는 `hideTarget`이 쓰는 동일 서비스에서 조회:
- `SHARED_DECK`/`SHARED_NOTE` → `SharedContentService`에서 소유자 userId 반환 확장.
- `STUDY_GROUP` → `GroupService`에서 그룹장/대상 userId 반환 확장.
소유자 조회 실패 시 피신고자 알림은 skip(신고자 알림은 유지), 로그 남김.

### 3.4 계약 (리스크)
engagement가 발행하는 `NotificationSend`는 platform `NotificationKafkaConsumer`가 기대하는 **스키마+봉투와 정확히 일치**해야 한다(불일치 시 platform 역직렬화 실패). shared `NotificationSend.avsc`(= platform `PlatformAvroEvents.NOTIFICATION_SEND_SCHEMA` 미러, 봉투=platform CloudEvent 변종 `com.synapse.event.shared`, time:long/data:bytes 중첩)로 생성·발행하고 **schema-registry subject 호환성**(BACKWARD) 확인. *스키마-패밀리 정합 미정 사항을 본 작업에서 확정.*

## 4. S6 — 감사 다중 토픽 적재 (platform-svc)

### 4.1 이벤트 → audit_logs 매핑
`AuditKafkaConsumer`에 타입별 `@KafkaListener` 추가 + `AuditLogService.processEvent` 오버로드. 단일 `auditKafkaListenerContainerFactory`(SpecificRecord) 재사용, 전용 그룹 `platform-audit-group`.

| 토픽 | 이벤트 | action | resource_type | resource_id | user_id |
|---|---|---|---|---|---|
| platform.auth.user-registered-v1 | UserRegistered | USER_REGISTERED | USER | userId | userId *(기존)* |
| knowledge.note.note-created-v1 | NoteCreated | NOTE_CREATED | NOTE | noteId | userId |
| knowledge.note.note-updated-v1 | NoteUpdated | NOTE_UPDATED | NOTE | noteId | userId |
| learning.card.review-completed-v1 | ReviewCompleted | REVIEW_COMPLETED | CARD | cardId | userId |
| engagement.gamification.badge-earned-v1 | BadgeEarned | BADGE_EARNED | BADGE | badgeId | userId |
| engagement.gamification.level-up-v1 | LevelUp | LEVEL_UP | USER | userId | userId |

> 토픽명은 각 서비스 `synapse.kafka.topics.*` 설정 기준으로 확정(구현 시 EVENT_FLOW_MATRIX·각 producer 설정과 대조).

### 4.2 제외 토픽 (도메인 상태변경 아님)
- `platform.notification.notification-send-v1` — 알림 요청(아웃바운드), 상태변경 아님 + S5가 발행하므로 자기 소비 노이즈.
- `learning.card.card-review-due-v1` — 내부 스케줄러 신호.

### 4.3 Avro 의존
platform build에 cross-namespace 스키마 5종(NoteCreated/NoteUpdated/ReviewCompleted/BadgeEarned/LevelUp, shared 보유) Avro 생성 추가. 네임스페이스 상이(`com.synapse.event.{knowledge,learning,engagement}`).

### 4.4 멱등성
`audit_logs.event_id`에 UNIQUE 제약(신규 마이그레이션) + insert 전 존재 체크 → 재전달 시 중복 행 방지.

## 5. 에러 처리

- **S5**: 발행 실패가 모더레이션을 깨지 않음 — 모더레이션 트랜잭션 커밋 후 발행, 실패는 로그(API 응답 비차단). Kafka 비활성 = Noop.
- **S6**: `ErrorHandlingDeserializer`(기존)로 역직렬화 실패 메시지 skip(크래시 없음). 멱등 insert로 재전달 흡수. 감사 = eventually-consistent.

## 6. 테스트

- **S5**: `ModerationService` 단위(결정별 올바른 수신자·notificationType 발행 — mock `CommunityNotificationPublisher`) + Noop(kafka off 시 무발행) + `NotificationSend` Avro 라운드트립 계약(platform 소비자 스키마 호환).
- **S6**: 이벤트별 `processEvent` 매핑 단위(이벤트→audit_logs 필드 정확) + 소비자 통합(Testcontainers Kafka+Schema Registry, 각 토픽 produce→audit_logs 행) + 멱등성(동일 event_id 2회→1행).

## 7. 구현 경계 / 순서

- **별도 플랜/PR 2개**: S5(engagement-svc 레포), S6(platform-svc 레포). 상호 의존 없음.
- 공통 선행: shared `NotificationSend.avsc` 계약 확정(S5만 의존). S6의 5개 스키마는 이미 shared에 존재.
- E2E(S5/S6 시나리오) 라이브 검증은 EKS 윈도 또는 로컬 docker-compose 스택.

## 8. 미해결 / 리스크

- **R1 (S5)**: NotificationSend 스키마-패밀리/봉투 정합 미확정 — 구현 1순위로 platform 소비자와 계약 일치 검증.
- **R2 (S5)**: 피신고자 userId 조회 경로(SharedContent/Group) 소유자 반환 확장 필요 — 미보유 시 피신고자 알림 skip.
- **R3 (S6)**: 토픽명/네임스페이스를 각 producer 실제 설정과 대조 확정(매핑 표는 EVENT_FLOW 기준 초안).
- **R4 (S6)**: gamification 이벤트(badge/level) 감사 가치 — 포함 결정됨("전 토픽"), 노이즈 우려 시 운영 중 필터 재검토.
