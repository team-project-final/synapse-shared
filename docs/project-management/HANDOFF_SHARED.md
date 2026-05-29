# 핸드오프: synapse-shared

> **최종 갱신**: 2026-05-29 (W3 Day 1~2 실행 — work-order + 로컬 E2E harness)
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

> **종합**: main 머지 learning-svc뿐. platform/engagement dev 고립. knowledge 미구현. **cards-generated 경로 HTTP 대체 → D-001 HTTP 확정**(EVENT_FLOW_MATRIX 정정 완료), platform AI카드 알림 트리거 재설계 open.

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

**인프라 방침**: EKS는 비용관리로 **destroy 상태** → 검증은 **로컬 docker-compose** 기준. 세션 종료 시 `docker compose down -v` 권장(stale ZK znode 재발 방지, D-1).
