# 핸드오프: synapse-shared

> **최종 갱신**: 2026-05-29 (W3 종료 Day 4 — 이벤트 계약 표준(Avro) + 라이브러리 발행)
> **허브 참조**: → [HANDOFF_HUB.md](./HANDOFF_HUB.md)

---

## 1. Avro 스키마 현황

> 계약 표준: [EVENT_CONTRACT_STANDARD.md](../guides/EVENT_CONTRACT_STANDARD.md) (D-002 Option 1: Avro + Schema Registry). 공통 메타(eventId/tenantId/occurredAt) 적용. 전체 `generateAvroJava` 컴파일 확인.

| 스키마 | 네임스페이스 | 토픽 | 공통메타 | 비고 |
|---|---|---|---|---|
| CloudEventEnvelope | com.synapse.shared | (래퍼) | — | |
| UserRegistered | com.synapse.platform | platform.auth.user-registered-v1 | ✅ 보강 | |
| NoteCreated | com.synapse.knowledge | knowledge.note.note-created-v1 | ✅ 보강 | +deckId |
| NoteUpdated | com.synapse.knowledge | knowledge.note.note-updated-v1 | ✅ 보강 | |
| ReviewCompleted | com.synapse.learning | learning.card.review-completed-v1 | ✅ 보강 | |
| **CardReviewDue** | com.synapse.learning | learning.card.review-due-v1 | ✅ | 신규(learning-card 승격) |
| **LevelUp** | com.synapse.engagement | engagement.gamification.level-up-v1 | ✅ | 신규 DRAFT(필드 owner 확정) |
| **BadgeEarned** | com.synapse.engagement | engagement.gamification.badge-earned-v1 | ✅ | 신규 DRAFT(필드 owner 확정) |
| **NotificationSend** | com.synapse.event.platform | platform.notification.notification-send-v1 | (platform 계약) | 신규(platform 미러) |
| ~~CardsGenerated~~ | com.synapse.learning | ~~cards-generated-v1~~ | — | deprecated(D-001 HTTP) |
| TenantId / UserId | com.synapse.shared | (공통) | — | |

> 호환성 정책 `BACKWARD`. 신규/보강 필드는 default 포함 → BACKWARD 안전. 발행: GitHub Packages `com.synapse:synapse-shared` (§8).

## 2. Kafka 토픽 / MSK 상태

| 토픽 | MSK 생성 | 파티션 | 복제 | 프로듀서 | 컨슈머 |
|---|---|---|---|---|---|
| platform.auth.user-registered-v1 | ✅ | 3 | 2 | platform-svc | engagement, learning-card |
| knowledge.note.note-created-v1 | ✅ | 3 | 2 | knowledge-svc | learning-ai |
| knowledge.note.note-updated-v1 | ✅ | 3 | 2 | knowledge-svc | learning-ai, opensearch |
| learning.card.review-completed-v1 | ✅ | 3 | 2 | learning-card | engagement-svc |
| learning.ai.cards-generated-v1 | ✅ | 3 | 2 | learning-ai | learning-card |

**MSK 브로커**: PR #42 반영 완료 (endpoint 변경 시 gitops ConfigMap 갱신 필요)

## 3. Docker Compose 현황

13개 서비스 로컬 환경: ✅ 전체 Healthy
- DB/Cache: postgres, redis, zookeeper
- Kafka: kafka, schema-registry
- Search: opensearch
- App: platform, engagement, knowledge, learning-card, learning-ai, gateway

## 4. CI/CD 파이프라인 상태

| 워크플로 | 트리거 | 상태 |
|---|---|---|
| ci-java.yml | PR/push → Gradle build + Modulith verify | ✅ PASS |
| schema-check.yml | PR (*.avsc 변경) → 호환성 검증 | ✅ PASS |
| mirror.yml | push → synapse-mirror 동기화 | ✅ PASS |

## 5. 팀원 체크리스트 + Kafka 구현 추적

→ [TEAM_CHECKLIST_W3.md](../guides/TEAM_CHECKLIST_W3.md) · [W3_KAFKA_WORKORDER.md](../work-orders/W3_KAFKA_WORKORDER.md)

> **work-order**: 05-26 발행 → **05-29 cross-repo 실측으로 재정렬** ([W4_KAFKA_WORKORDER.md](../work-orders/W4_KAFKA_WORKORDER.md)). "Day 2 PR 0/5" 스냅샷 폐기.

**서비스별 Kafka 구현 상태 (2026-05-29 origin 코드 실측)**:

| 서비스 | 역할 | GH 이슈 | 위치 | 구현 상태 |
|---|---|---|---|---|
| learning-card | Producer (ReviewCompleted, ReviewDue) | [#21](https://github.com/team-project-final/synapse-learning-svc/issues/21) | main(#26) | 🟢 완료 |
| learning-ai | Producer (CardsGenerated) + Consumer (NoteCreated) | [#22](https://github.com/team-project-final/synapse-learning-svc/issues/22) | main(#26) | 🟡 Consumer만 — 카드등록 HTTP, CardsGenerated 미발행 |
| platform-svc | Producer (UserRegistered) + Consumer (CardsGenerated) | [#30](https://github.com/team-project-final/synapse-platform-svc/issues/30) | dev(미머지) | 🟡 Producer+audit/noti Consumer 구현, open PR 없음 |
| engagement-svc | Consumer (UserRegistered, ReviewCompleted) | [#9](https://github.com/team-project-final/synapse-engagement-svc/issues/9) | dev(미머지) | 🟡 Producer만 — **Consumer 미구현(역할 불일치)** |
| knowledge-svc | Producer (NoteCreated, NoteUpdated) | [#22](https://github.com/team-project-final/synapse-knowledge-svc/issues/22) | — | 🔴 미구현 (in-process 이벤트만) |

> **종합**: main 머지 learning-svc뿐. platform/engagement dev 고립. knowledge 미구현. **cards-generated 경로 HTTP 대체 → D-001 HTTP 확정**(EVENT_FLOW_MATRIX 정정). AI카드 알림은 platform 알림 버스(notification-send-v1) 재사용으로 **설계 완료**([NOTIFICATION_TRIGGER_AI_CARDS](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md)), 구현·스키마공유 W4.

## 6. W3 선행 준비 산출물 (05-22)

| 산출물 | 경로 |
|--------|------|
| 이벤트 흐름 매트릭스 | `docs/guides/EVENT_FLOW_MATRIX.md` |
| E2E 시나리오 문서 | `docs/guides/E2E_SCENARIOS_W3.md` |
| 배포 검증 리포트 템플릿 | `docs/reports/DEPLOY_REPORT_W3.md` |
| E2E 결과 리포트 템플릿 | `docs/reports/E2E_REPORT_W3.md` |
| card-review-due 샘플 이벤트 | `src/test/resources/e2e-samples/card-review-due.json` |
| note-updated 멀티테넌트 샘플 | `src/test/resources/e2e-samples/multi-tenant/note-updated-tenant2.json` |
| 코드 리뷰 승인 기준 | TASK_team-lead.md Step 7 반영 |
| Security 1차 (PII 점검) | TASK_team-lead.md Step 7 Constraints 반영 |
| 팀원 체크리스트 정비 | `docs/guides/TEAM_CHECKLIST_W3.md` (일정/리뷰 기준/참조 링크 추가) |
| W3 작업 구성 설계 | `docs/superpowers/specs/2026-05-22-w3-work-composition-design.md` |
| W3 구현 계획 | `docs/superpowers/plans/2026-05-22-w3-work-composition.md` |

## 7. W3 실행 산출물 (05-26~27, Day 1~2)

| 산출물 | 경로 | 비고 |
|--------|------|------|
| W3 실행 설계 스펙 | `docs/superpowers/specs/2026-05-26-w3-shared-execution-design.md` | 로컬 E2E 중심 · work-order 추적 |
| W3 실행 구현 플랜 | `docs/superpowers/plans/2026-05-26-w3-shared-execution.md` | Day1~4 |
| Kafka cross-repo work-order | `docs/work-orders/W3_KAFKA_WORKORDER.md` | 5개 서비스 할당 + GH 이슈 + PR 추적 |
| 로컬 E2E harness 베이스라인 | `docs/reports/E2E_BASELINE_W3.md` | `--all` 5/5, `--full` 13/13 PASSED |
| E2E harness 개선 | `scripts/kafka-e2e-test.sh` | `compact_json`(jq -c) 추가 — CloudEvent 단위 검증 복구 (D-2 해결) |

### W3 Day 4 (05-29) 종료 산출물

| 산출물 | 경로 | 비고 |
|--------|------|------|
| W3 종료 게이트 평가 | `docs/reports/W3_EXIT_GATE.md` | **미통과 1/5** — 차단=서비스 Kafka 미완성(knowledge 미구현·platform/engagement dev) |
| E2E 결과 리포트 | `docs/reports/E2E_REPORT_W3.md` | 전송 경로 5/5·13/13, service 단위 미실행 |
| 스키마 호환성 리뷰 | `docs/reports/SCHEMA_COMPAT_REVIEW_W3.md` | 8종 형식·컴파일·CloudEvent 필드 통과, 레지스트리 실등록 미검증 |
| 배포 전략·롤백 정의 | `docs/reports/DEPLOY_REPORT_W3.md` | §A~C 정의 완료, 실배포 검증 보류(EKS destroy) |
| harness 시나리오 스캐폴딩 | `scripts/kafka-e2e-test.sh --scenarios` | S1~S4 의존성 순서 produce + service-check 안내 |
| **이벤트 계약 표준** | `docs/guides/EVENT_CONTRACT_STANDARD.md` | Avro+Registry, 봉투·카탈로그·Kafka 설정 |
| **아키텍처 결정** | `EVENT_FLOW_MATRIX.md`(D-001) · `docs/designs/D-002_SCHEMA_FAMILY_DECISION.md` | cards HTTP / Avro 사수 |
| **알림 트리거 설계** | `docs/designs/NOTIFICATION_TRIGGER_AI_CARDS.md` | platform 알림 버스 재사용 |
| **신규/보강 Avro 스키마** | `src/main/avro/{learning/CardReviewDue,engagement/LevelUp,engagement/BadgeEarned,platform/NotificationSend}` + 기존 4종 공통메타 | generateAvroJava 컴파일 확인 |
| **신규 토픽 4종** | `scripts/create-kafka-topics.sh` + `docker-compose.yml` kafka-init | review-due/level-up/badge-earned/notification-send |
| **라이브러리 발행** | `build.gradle.kts` + `.github/workflows/publish.yml` + `docs/runbooks/PUBLISH_SHARED_LIBRARY.md` | GitHub Packages `com.synapse:synapse-shared` |
| **harness Avro 모드** | `scripts/kafka-e2e-test.sh --avro` | 8토픽 Avro 라운드트립 |
| **W4 work-order + 서비스 이슈** | `docs/work-orders/W4_KAFKA_WORKORDER.md` + 이슈 #43/#13/#26/#32 | 계약 표준 적용, 기한 W4 D1-2 |

**인프라 방침**: EKS는 비용관리로 **destroy 상태** → 검증은 **로컬 docker-compose** 기준. 세션 종료 시 `docker compose down -v` 권장(stale ZK znode 재발 방지, D-1).
**W4 선결(잔여)**: org GitHub Packages 활성화 + `v0.1.0` 태그 발행 / svc-template 배선 / owner 필드 확정(LevelUp·BadgeEarned, NoteCreated title·deckId) / `--avro` 라이브 검증.
