# W4 Kafka Work-Order (W3 미완 carryover · 실측 기반 재정렬)

> **작성일**: 2026-05-29 (W3 종료일)
> **작성자**: @team-lead (synapse-shared)
> **선행**: [W3_KAFKA_WORKORDER.md](./W3_KAFKA_WORKORDER.md) (PR 0/5 스냅샷은 폐기 — 아래가 최신 실측)
> **우선순위**: P0 — W3 종료 게이트 미통과 직접 차단요인, W4 통합/배포 선결
> **착수**: W4 Day 1 (2026-06-01 월) · **PR/머지 기한**: 2026-06-02 (화) EOD

## 0. 실측 요약 (05-29, origin 코드 직접 확인)

W3 work-order의 "PR 0/5"는 더 이상 유효하지 않음. 코드 레벨 현황:

| 서비스 | 할당 역할 | 실제 구현 | 위치 | 판정 |
|--------|----------|-----------|------|:----:|
| learning-card | Producer(ReviewCompleted) | CardReviewed + ReviewDue Publisher (+테스트) | **main 머지 (#26)** | 🟢 완료 |
| learning-ai | Producer(CardsGenerated) + Consumer(NoteCreated) | Consumer(NoteCreated) ✅ / 카드 등록은 **HTTP(card_client)**, CardsGenerated **미발행** | **main 머지 (#26)** | 🟡 Consumer만 + 설계 변경 |
| platform-svc | Producer(UserRegistered) + Consumer(CardsGenerated) | Producer(UserRegistered, Outbox) ✅ + audit/notification Consumer ✅ / CardsGenerated 소비 ❌ | **dev (미머지·open PR 없음)** | 🟡 부분·미머지 |
| engagement-svc | Consumer(UserRegistered, ReviewCompleted) | **Consumer ❌** (@KafkaListener 0건) / GamificationKafkaProducer ✅ | **dev (미머지)** | 🟡 역할 불일치·미머지 |
| knowledge-svc | Producer(NoteCreated, NoteUpdated) | **Kafka 전무** (in-process `@TransactionalEventListener`만) | — | 🔴 미구현 |

## 1. ⚠️ 아키텍처 결정 필요 (팀장/owner 합의 — Day 1 데일리)

**cards-generated-v1 경로가 HTTP로 대체됨**: learning-ai가 note-created 소비 후 **learning-card REST API**(`card_client.py`)로 카드를 등록. 그 결과:
- learning.ai.cards-generated-v1 토픽을 **아무도 발행하지 않음**.
- 설계상 이 토픽 소비자였던 **platform-svc(알림)·learning-card(등록)**의 트리거가 사라짐.

**선택지 (Day 1 확정)**:
- **(A) HTTP 유지** → EVENT_FLOW_MATRIX에서 cards-generated 제거, platform 알림은 다른 트리거(예: review-due)로 재설계, learning-ai의 "Producer(CardsGenerated)" 할당 철회.
- **(B) Kafka 복원** → learning-ai에 CardsGenerated 발행 추가, platform/learning-card Consumer 유지.

> 권고: **(A) HTTP 유지** — 이미 동작하는 경로. 단, EVENT_FLOW_MATRIX·E2E 시나리오 S3-2/S3-3·platform 알림 트리거를 문서상 정정.

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

### 🟡 P1-1 — platform-svc (dev→main 머지 + 역할 정정)
- **현 상태**: Producer(UserRegistered, Outbox)·audit/notification Consumer **dev에 구현, main 미머지, open PR 없음**.
- **할 일**: **dev→main PR 생성·머지**. Consumer(CardsGenerated)는 §1 결정에 종속 — (A)면 철회, (B)면 추가. audit/notification Consumer는 W4 본 범위이므로 유지.
- **Done**: main 머지 + S1(user-registered) E2E 확인.
- **이슈**: [#30](https://github.com/team-project-final/synapse-platform-svc/issues/30)

### 🟡 P1-2 — learning-ai (cards-generated 결정 반영)
- **현 상태**: Consumer(NoteCreated) main 머지 ✅. 카드 등록 HTTP. CardsGenerated 미발행.
- **할 일**: §1에서 (B) 선택 시에만 CardsGenerated Producer 추가. (A) 선택 시 **추가 작업 없음**(역할 철회). DLQ 발행 로직은 유지.
- **이슈**: [#22](https://github.com/team-project-final/synapse-learning-svc/issues/22)

### 🟢 완료 — learning-card
- ReviewCompleted + ReviewDue Producer main 머지 완료. **추가 작업 없음**. (cards-generated Consumer는 §1 (A) 시 불필요.)
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
| platform-svc | dev→main PR | ⏳ | ⏳ | ⏳ | P1 |
| learning-ai | §1 결정 반영 | — | — | — | (A)면 무작업 |
| learning-card | — | ✅ | ✅ | ⏳ | 완료 |

> 상태: ⏳ 대기 / 🔄 진행 / ✅ 완료 / ❌ 미착수
