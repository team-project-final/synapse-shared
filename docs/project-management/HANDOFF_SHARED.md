# 핸드오프: synapse-shared

> **최종 갱신**: 2026-05-22 (W3 선행 준비)
> **허브 참조**: → [HANDOFF_HUB.md](./HANDOFF_HUB.md)

---

## 1. Avro 스키마 현황

| 스키마 | 네임스페이스 | 토픽 | 호환성 |
|---|---|---|---|
| CloudEventEnvelope | com.synapse.shared | (래퍼) | ✅ BACKWARD |
| UserRegistered | com.synapse.platform | platform.auth.user-registered-v1 | ✅ BACKWARD |
| NoteCreated | com.synapse.knowledge | knowledge.note.note-created-v1 | ✅ BACKWARD |
| NoteUpdated | com.synapse.knowledge | knowledge.note.note-updated-v1 | ✅ BACKWARD |
| ReviewCompleted | com.synapse.learning | learning.card.review-completed-v1 | ✅ BACKWARD |
| CardsGenerated | com.synapse.learning | learning.ai.cards-generated-v1 | ✅ BACKWARD |
| TenantId | com.synapse.shared | (공통) | ✅ |
| UserId | com.synapse.shared | (공통) | ✅ |

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

## 5. 팀원 체크리스트

→ [TEAM_CHECKLIST_W3.md](../guides/TEAM_CHECKLIST_W3.md)

**서비스별 Kafka 구현 상태**:

| 서비스 | 역할 | 구현 상태 |
|---|---|---|
| platform-svc | Producer (UserRegistered) + Consumer (CardsGenerated) | 🔴 미착수 |
| engagement-svc | Consumer (UserRegistered, ReviewCompleted) | 🔴 미착수 |
| knowledge-svc | Producer (NoteCreated, NoteUpdated) | 🔴 미착수 |
| learning-card | Producer (ReviewCompleted) | 🔴 미착수 |
| learning-ai | Producer (CardsGenerated) + Consumer (NoteCreated) | 🔴 미착수 |

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
