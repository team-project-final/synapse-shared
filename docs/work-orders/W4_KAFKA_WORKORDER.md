# W4 Kafka Work-Order (W3 미완 carryover · 실측 기반 재정렬)

> **작성일**: 2026-05-29 (W3 종료일)
> **작성자**: @team-lead (synapse-shared)
> **선행**: [W3_KAFKA_WORKORDER.md](./W3_KAFKA_WORKORDER.md) (PR 0/5 스냅샷은 폐기 — 아래가 최신 실측)
> **우선순위**: P0 — W3 종료 게이트 미통과 직접 차단요인, W4 통합/배포 선결
> **착수**: W4 Day 1 (2026-06-01 월) · **PR/머지 기한**: 2026-06-02 (화) EOD

## ⏰ 계약 표준 적용 — W4 1~2일차(06-01~06-02) 구성 완료 (각 서비스 이슈 발행됨)

전 서비스 [이벤트 계약 표준(Avro + Schema Registry)](../guides/EVENT_CONTRACT_STANDARD.md) 적용 — 05-29 각 레포 이슈 등록:

| 서비스 | 표준 적용 이슈 | 핵심 |
|--------|--------------|------|
| platform-svc | [#43](https://github.com/team-project-final/synapse-platform-svc/issues/43) | 수동 Avro→**Confluent Avro+Registry**(`com.synapse.platform`), user-registered 발행 + notification-send 소비, dev→main |
| engagement-svc | [#13](https://github.com/team-project-final/synapse-engagement-svc/issues/13) | **JSON(StringSerializer)→Confluent Avro**, **Consumer 신규**(user-registered/review-completed) + gamification 발행 정렬 |
| knowledge-svc | [#26](https://github.com/team-project-final/synapse-knowledge-svc/issues/26) | **Producer 신규**(note-created/updated, shared Avro) — 체인 시작점 |
| learning-svc | [#32](https://github.com/team-project-final/synapse-learning-svc/issues/32) | learning-card 정렬(`CardReviewed`→`ReviewCompleted`, `com.synapse.learning`), **learning-ai JSON→Avro** + 알림 발행 |

> 기준: D-002 **Option 1(Avro + Schema Registry 사수)**. **이 표준 적용이 아래 모든 구현의 선행.**

---

## 0. 실측 요약 (05-29, origin 코드 직접 확인)

W3 work-order의 "PR 0/5"는 더 이상 유효하지 않음. 코드 레벨 현황:

| 서비스 | 할당 역할 | 실제 구현 | 위치 | 판정 |
|--------|----------|-----------|------|:----:|
| learning-card | Producer(ReviewCompleted) | CardReviewed + ReviewDue Publisher (+테스트) | **main 머지 (#26)** | 🟢 완료 |
| learning-ai | Producer(CardsGenerated) + Consumer(NoteCreated) | Consumer(NoteCreated) ✅ / 카드 등록은 **HTTP(card_client)**, CardsGenerated **미발행** | **main 머지 (#26)** | 🟡 Consumer만 + 설계 변경 |
| platform-svc | Producer(UserRegistered) + Consumer(CardsGenerated) | Producer(UserRegistered, Outbox) ✅ + audit/notification Consumer ✅ / CardsGenerated 소비 ❌ | **dev (미머지·open PR 없음)** | 🟡 부분·미머지 |
| engagement-svc | Consumer(UserRegistered, ReviewCompleted) | **Consumer ❌** (@KafkaListener 0건) / GamificationKafkaProducer ✅ | **dev (미머지)** | 🟡 역할 불일치·미머지 |
| knowledge-svc | Producer(NoteCreated, NoteUpdated) | **Kafka 전무** (in-process `@TransactionalEventListener`만) | — | 🔴 미구현 |

## 0.5 06-01 코드 실측 갱신 (전체 레포 pull → origin/dev 직접 확인)

W4 Day1 전체 레포 pull 후 재확인 — §0(05-29) 대비:

| 서비스 | 06-01 상태 | 잔여 |
|---|---|---|
| **platform** 🟢 | Avro+Registry 전환(#44/#45) · UserRegistered **Outbox** · **notification + audit Consumer** · 멱등성(`ProcessedEvent`) · ErrorHandler | **dev→main PR**(열린 PR 0건) |
| **learning** 🟢 | learning-ai **Avro 소비 전환 + 알림(notification-send) 발행**(#35) · learning-card 정렬(#33) · **#32 CLOSED** | dev→main PR |
| **engagement** 🔴 | Producer만(level-up/badge-earned) · **Consumer 여전히 0건**(@KafkaListener 없음) · ⚠️ **자체 스키마 비호환** | Consumer 신규 + **스키마 표준화** |
| **knowledge** 🔴 | **NoteCreated Kafka Producer 여전히 부재**(in-process `@TransactionalEventListener`만) · 06-01엔 검색(RRF) 작업 | **P0 Producer 신규** |

### 🚨 신규 발견 — engagement 스키마 비호환 (D-002 재발, 코드 실측)
engagement가 shared `engagement.LevelUp`을 벤더링하지 않고 **자체 스키마**(`src/main/resources/avro/GamificationLevelUp.avsc`, 자체 `CloudEventEnvelope.java`)를 작성. **5개 축 비호환**:

| 축 | shared 표준 | engagement 자체 | 영향 |
|---|---|---|---|
| record name | `LevelUp` | `GamificationLevelUp` | subject `…-value` 스키마 불일치 |
| namespace | `com.synapse.engagement` | `com.synapse.event.engagement` | 〃 |
| **eventId(멱등성)** | ✅ string | **없음** | 중복 적립 방지 불가 |
| **occurredAt** | 평문 long | **logicalType=timestamp-millis** | **표준 §1 명시 금지** (콘솔/폴리글랏·BACKWARD 위험) |
| userId | string(UUID) | **long** | 타입 불일치 |

→ engagement 발행 시 platform notification Consumer(shared 스키마 기대)가 **역직렬화 실패/불일치** 가능. **#13은 단순 미적용이 아니라 능동적 스키마 충돌** → 데일리 최우선 + **shared 벤더링 강제**(자체 .avsc 폐기).

---

## 1. ✅ 아키텍처 결정 — D-001 확정 (2026-05-29, HTTP 채택)

**결정**: cards-generated-v1 경로는 **(A) HTTP 동기 호출 유지**. learning-ai → learning-card REST API(`card_client.py`)로 카드 등록. `cards-generated-v1` Kafka 토픽/Producer/Consumer는 **현 설계에서 제외(deprecated)**. 상세: [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md) §결정 D-001.

**확정에 따른 역할 변경**:
- learning-ai: CardsGenerated **Producer 불요** → 추가 작업 없음.
- learning-card: cards-generated **Consumer 불요** (HTTP 직접 수신).
- platform-svc: cards-generated 소비 기반 **AI 카드 알림 트리거 소멸** → **재설계 필요(open, §2 P1-1에 포함)**.

> D-001은 이미 머지된 코드(#26)의 실제 동작에 계약을 맞춘 것. (B) Kafka 복원은 비동기 대량/재시도 요구 발생 시 재검토.

### 🚨 추가 안건 D-002 (W4 아키텍처 논의) — 스키마 패밀리 분기

실측 결과 **5개 서비스가 4가지 비호환 방식**(Confluent-Avro / 수동-Avro-bytes / JSON-string / JSON-pydantic)을 쓰고 **synapse-shared Avro를 의존하는 서비스는 없음**(고아). 현재 어떤 크로스서비스 체인도 wire 호환 불성립.

→ **확정 = Option 1 (Avro + Schema Registry 사수)** — [D-002_SCHEMA_FAMILY_DECISION.md](../designs/D-002_SCHEMA_FAMILY_DECISION.md) 결정, [EVENT_CONTRACT_STANDARD.md](../guides/EVENT_CONTRACT_STANDARD.md) 수립 완료. 초기 권고(Option 2 JSON)는 **폐기**. **전 서비스 shared `.avsc` 벤더링이 모든 Kafka 구현의 선결** — 06-01 실측상 engagement만 미준수(자체 스키마, §0.5).

## 2. 서비스별 액션 (P0 → P1)

### 🔴 P0-1 — knowledge-svc (가장 치명적: 체인 B 시작점)
- **현 상태**: Kafka 코드 없음. note 생성/수정은 in-process 이벤트만.
- **할 일**: `NoteCreated`·`NoteUpdated` **Kafka Producer 구현** → `knowledge.note.note-created-v1` / `note-updated-v1` 발행. 기존 `@TransactionalEventListener`를 Kafka 발행으로 브리지(Outbox 권장).
- **Done**: 노트 생성/수정 API → 토픽 발행 확인(로컬 harness `--scenarios` S3-1/S4 통과). learning-ai Consumer 수신 확인.
- **이슈**: [#22](https://github.com/team-project-final/synapse-knowledge-svc/issues/22)

### 🔴 P0-2 — engagement-svc (역할 미이행: Consumer 부재)
- **현 상태**: `GamificationKafkaProducer`(dev)만, **Consumer 미구현**.
- **할 일**: `@KafkaListener` 추가 — `platform.auth.user-registered-v1`(프로필 생성), `learning.card.review-completed-v1`(XP 적립). Consumer Group `engagement-svc-group`. **멱등성**(reviewId 중복 적립 방지) 필수.
- **추가**: 구현된 GamificationKafkaProducer(level_up/badge_earned)는 PRD FR-EG-205 충족분 → 유지·머지.
- **Done**: dev→main **PR 생성**, S1/S2 Consumer 처리 확인.
- **이슈**: [#9](https://github.com/team-project-final/synapse-engagement-svc/issues/9)

### 🟡 P1-1 — platform-svc (dev→main 머지 + 알림 재설계)
- **현 상태**: Producer(UserRegistered, Outbox)·audit/notification Consumer **dev에 구현, main 미머지, open PR 없음**.
- **할 일**: ① **dev→main PR 생성·머지**. ② Consumer(CardsGenerated)는 D-001로 **철회**(불요). ③ **AI 카드 알림** — 설계 확정([NOTIFICATION_TRIGGER_AI_CARDS](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md), A1): platform은 **기존 NotificationKafkaConsumer 재사용**(거의 무변경), `notificationType=AI_CARDS_READY` 수용 + **eventId dedupe 확인**만. audit/notification Consumer(W4 범위)는 유지.
- **Done**: main 머지 + S1(user-registered) E2E 확인 + notification-send-v1 AI_CARDS_READY 처리 확인.
- **이슈**: [#30](https://github.com/team-project-final/synapse-platform-svc/issues/30)

### 🟡 P1-3 — learning-ai (알림 발행 추가 / D-001로 CardsGenerated는 불요)
- Consumer(NoteCreated) main 머지 ✅, 카드 등록 HTTP. **CardsGenerated Producer 불요**.
- **할 일(신규)**: HTTP 카드 등록 2xx & cardCount>0 시 `platform.notification.notification-send-v1`에 **NotificationSend(AI_CARDS_READY) 발행** — 기존 Avro CloudEvent 도구 재사용, 멱등 eventId(uuidv5(noteId+userId)). 설계: [NOTIFICATION_TRIGGER_AI_CARDS](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md).
- **선결**: NotificationSend 스키마 공유(§아래 shared 액션) — platform owner 합의.
- **이슈**: [#22](https://github.com/team-project-final/synapse-learning-svc/issues/22)

### 📐 shared / @team-lead — 알림 계약 공유
- `NotificationSend` 스키마를 synapse-shared로 승격(또는 platform published contract 공개) → learning-ai 발행 가능하게. **platform owner와 스키마 소유권 합의(최대 선결)**. EVENT_FLOW_MATRIX notification-send-v1 행은 반영 완료.

### 🟢 완료 — learning-card
- ReviewCompleted + ReviewDue Producer main 머지 완료. **추가 작업 없음**. cards-generated Consumer는 D-001로 불요(HTTP 수신).
- **이슈**: [#21](https://github.com/team-project-final/synapse-learning-svc/issues/21)

## 3. 공통 요구사항 / 코드 리뷰 승인 기준

→ [TEAM_CHECKLIST_W3.md](../guides/TEAM_CHECKLIST_W3.md) "코드 리뷰 승인 기준" 준수 (CloudEvent 8필드, Consumer Group `{svc}-group`, 멱등성, application.yml Kafka 설정, 역직렬화 실패 시 로그+스킵).

## 4. 검증 / 추적

- 로컬 검증: `bash scripts/kafka-e2e-test.sh --scenarios` (S1~S4 의존성 순서) — 서비스 구현 후 service-check까지 확장.
- 참조: [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md) · [E2E_SCENARIOS_W3.md](../guides/E2E_SCENARIOS_W3.md) · [W3_EXIT_GATE.md](../reports/W3_EXIT_GATE.md)

| 서비스 | 액션 | PR | 머지 | E2E | 비고 |
|--------|------|:--:|:----:|:---:|------|
| knowledge-svc | Producer 신규 구현 | ⏳ | ⏳ | ⏳ | P0 |
| engagement-svc | Consumer 추가 + dev→main | ⏳ | ⏳ | ⏳ | P0 |
| platform-svc | dev→main PR + 알림(AI_CARDS_READY) 수용·dedupe 확인 | ⏳ | ⏳ | ⏳ | P1 |
| learning-ai | 알림 NotificationSend 발행 추가 (CardsGenerated는 불요) | ⏳ | ⏳ | ⏳ | P1-3 |
| learning-card | — | ✅ | ✅ | ⏳ | 완료 |
| shared/team-lead | NotificationSend 스키마 공유(platform 합의) | ⏳ | — | — | 알림 선결 |

> 상태: ⏳ 대기 / 🔄 진행 / ✅ 완료 / ❌ 미착수
