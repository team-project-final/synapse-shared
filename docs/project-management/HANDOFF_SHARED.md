# 핸드오프: synapse-shared

> **최종 갱신**: 2026-06-08 (W5 Day 1 — EKS 재apply→dev/staging 5/5, 서비스 단위 E2E 환경 구축, 정본 avsc 표준 정렬(P0 2건 근본 원인 제거))
> **허브 참조**: → [HANDOFF_HUB.md](./HANDOFF_HUB.md)
>
> **W5 Day 1 (06-08) 요약**: ① EKS/MSK/RDS 재apply + ArgoCD 14앱 + monitoring → **dev 16/0/0 · staging 20/0/0 ALL PASSED** (platform/gateway CrashLoop 근본 해소 [gitops#136](https://github.com/team-project-final/synapse-gitops/pull/136): DB 공유 flyway 충돌 + gateway JWT 미매핑) ② 서비스 단위 E2E 환경 `docker-compose.e2e.yml` (origin/main 실빌드, 13/13 healthy, [shared#25](https://github.com/team-project-final/synapse-shared/pull/25)) ③ Avro 전수 감사 → **P0 2건** + 정본 정렬 [shared#26](https://github.com/team-project-final/synapse-shared/pull/26) + owner 지시서 [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md). 상세: [E2E_SMOKE_W5_DAY1](../reports/E2E_SMOKE_W5_DAY1.md)

---

## 1. Avro 스키마 현황

> 계약 표준: [EVENT_CONTRACT_STANDARD.md](../guides/EVENT_CONTRACT_STANDARD.md) (D-002 Option 1: Avro + Schema Registry). 공통 메타(eventId/tenantId/occurredAt) 적용. 전체 `generateAvroJava` 컴파일 확인.

| 스키마 | 네임스페이스 | 토픽 | 공통메타 | 비고 |
|---|---|---|---|---|
| CloudEventEnvelope | com.synapse.shared | (래퍼) | — | |
| UserRegistered | com.synapse.platform | platform.auth.user-registered-v1 | ✅ 보강 | **06-08 정렬**: 구형 registeredAt 제거 → platform writer 정합(displayName+공통메타). reader가 구형 따라 F1 발생 |
| NoteCreated | com.synapse.knowledge | knowledge.note.note-created-v1 | ✅ 보강 | +deckId |
| NoteUpdated | com.synapse.knowledge | knowledge.note.note-updated-v1 | ✅ 보강 | |
| ReviewCompleted | com.synapse.learning | learning.card.review-completed-v1 | ✅ 보강 | |
| **CardReviewDue** | com.synapse.learning | learning.card.review-due-v1 | ✅ | 신규(learning-card 승격) |
| **LevelUp** | com.synapse.engagement | engagement.gamification.level-up-v1 | ✅ | 신규 DRAFT(필드 owner 확정) |
| **BadgeEarned** | com.synapse.engagement | engagement.gamification.badge-earned-v1 | ✅ | 신규 DRAFT(필드 owner 확정) |
| **NotificationSend** | com.synapse.platform | platform.notification.notification-send-v1 | ✅ | **06-08 정렬**: DRAFT `com.synapse.event.platform` 폐기 → `com.synapse.platform`+공통메타(platform reader 정합). learning-ai writer가 구 DRAFT 따라 F2/F3 발생 |
| ~~CardsGenerated~~ | com.synapse.learning | ~~cards-generated-v1~~ | — | deprecated(D-001 HTTP) |
| TenantId / UserId | com.synapse.shared | (공통) | — | |

> 호환성 정책 `BACKWARD`. 신규/보강 필드는 default 포함 → BACKWARD 안전. 발행: GitHub Packages `com.synapse:synapse-shared` (§8).

## 2. Kafka 토픽 / MSK 상태

> **단일 출처**: 토픽·Producer·Consumer 카탈로그는 [EVENT_CONTRACT_STANDARD §2](../guides/EVENT_CONTRACT_STANDARD.md)가 권위. 아래는 그 미러 — 변경 시 카탈로그를 먼저 갱신.
> 파티션 3 / 복제 MSK 2·로컬 1, 호환성 BACKWARD. **MSK 토픽은 terraform 선언 관리**(gitops `infra/aws/dev/kafka-topics/`, 2026-06-02 전환·라이브 입증) → 재apply 시 `terraform apply`로 자동 재생성(수동 `create-kafka-topics.sh`는 로컬·폴백 전용). 검증은 로컬 docker-compose(`kafka-init` 자동생성) 기준.

| 토픽 (8 active) | Avro 레코드 | Producer | Consumer |
|---|---|---|---|
| platform.auth.user-registered-v1 | platform.UserRegistered | platform | engagement |
| knowledge.note.note-created-v1 | knowledge.NoteCreated | knowledge | learning-ai |
| knowledge.note.note-updated-v1 | knowledge.NoteUpdated | knowledge | learning-ai |
| learning.card.review-completed-v1 | learning.ReviewCompleted | learning-card | engagement |
| learning.card.review-due-v1 | learning.CardReviewDue | learning-card | platform(알림, W4) |
| engagement.gamification.level-up-v1 | engagement.LevelUp | engagement | platform(알림, W4) |
| engagement.gamification.badge-earned-v1 | engagement.BadgeEarned | engagement | platform(알림, W4) |
| platform.notification.notification-send-v1 | platform.NotificationSend | 다수(learning-ai 등) | platform |

> 🚫 **deprecated**: `learning.ai.cards-generated-v1` — 카드 등록은 HTTP([D-001](../guides/EVENT_FLOW_MATRIX.md)), 발행자 없음. `create-kafka-topics.sh`에 호환 위해 **잔존**(9번째 엔트리)하나 harness `--avro`(8/8) 대상 제외. 스키마 `CardsGenerated.avsc`도 deprecated(§1). → **물리 산출물 = 토픽 9개(8 active + 1 잔존) / .avsc 12개(11 active + 1 잔존)**.

**MSK 브로커**: PR #42 반영 (endpoint 변경 시 gitops ConfigMap 갱신). EKS destroy 중 — 재기동 후 재확인.

## 3. Docker Compose 현황

13개 서비스 로컬 환경: ✅ 전체 Healthy
- DB/Cache: postgres, redis, zookeeper
- Kafka: kafka, schema-registry
- Search: elasticsearch
- App: platform, engagement, knowledge, learning-card, learning-ai, gateway

> **W5 추가 — 서비스 단위 E2E 오버라이드** `docker-compose.e2e.yml` (06-08, [shared#25](https://github.com/team-project-final/synapse-shared/pull/25)): app 스텁 5개를 **origin/main 고정 worktree(`../.e2e-worktrees/`) 실빌드**로 교체. 서비스별 DB 분리(`synapse_{platform,engagement,knowledge,learning,ai}`, flyway 충돌 방지), postgres→pgvector/pg16, 포트 교정(8081~8084/8090), gateway JWT dev 키, learning-ai alembic 자동. 실행: `docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --build` (헤더에 worktree 준비법). → **기본 compose=전송/계약 검증, e2e overlay=서비스 비즈니스 로직 검증.**

## 4. CI/CD 파이프라인 상태

| 워크플로 | 트리거 | 상태 |
|---|---|---|
| ci-java.yml | PR/push → Gradle build + Modulith verify | ✅ PASS |
| schema-check.yml | PR (*.avsc 변경) → 호환성 검증 | ✅ PASS |
| mirror.yml | push → synapse-mirror 동기화 | ✅ PASS |

## 5. 팀원 체크리스트 + Kafka 구현 추적

→ [TEAM_CHECKLIST_W3.md](../guides/TEAM_CHECKLIST_W3.md) · [W3_KAFKA_WORKORDER.md](../work-orders/W3_KAFKA_WORKORDER.md)

> **work-order**: 05-26 발행 → **05-29 cross-repo 실측으로 재정렬** ([W4_KAFKA_WORKORDER.md](../work-orders/W4_KAFKA_WORKORDER.md)). "Day 2 PR 0/5" 스냅샷 폐기.

**서비스별 Kafka 구현 상태 (2026-06-05 origin/main 실측 — `git fetch` 후 확인)**:

| 서비스 | 역할 | origin/main 머지 | 구현 상태 (06-05) |
|---|---|---|---|
| knowledge-svc | Producer (NoteCreated, NoteUpdated) | ✅ **#40 (06-02)** | 🟢 origin/main에 NoteCreated Producer 존재. dev 3커밋(컨벤션 #42·노트버전이력 #43·MSK TLS #45) 미머지=하드닝 |
| platform-svc | Producer (UserRegistered) + Consumer (audit 전도메인 / notification) | ✅ #46 (06-01) | 🟢 `AuditKafkaConsumer`·`NotificationKafkaConsumer`. dev 11커밋(S6 audit 다중토픽 #52·TLS #54·KAFKA_ENABLED 게이트 #61·staging 프로파일 #48·Step9 E2E #57) 미머지=W4 하드닝 |
| engagement-svc | Producer (gamification) + Consumer (UserRegistered, ReviewCompleted) | ✅ **#23 (06-04)** | 🟢 Consumer + **S5 모더레이션 알림 발행 머지됨**. dev 1커밋(#24 step9-11 flow) 미머지 |
| learning(card/ai) | Producer (ReviewCompleted, ReviewDue) + Consumer (NoteCreated) | ✅ main | 🟢 Avro 전환·알림 발행. 카드등록 HTTP(D-001). TLS는 origin/dev 배선 완료 |

> **종합(06-05 origin/main)**: **4서비스 Kafka Producer/Consumer 전원 origin/main 머지 완료** → 통합 E2E는 머지 대기 없이 로컬 compose 실행 가능. ⚠️ **검증 방법**: 반드시 `git fetch` 후 `origin/main` 기준 확인 — 로컬 stale main으로 보면 미머지 오판(이 표 직전 버전이 그 실수). **dev 잔여는 W4 하드닝**(S6 audit·TLS·KAFKA_ENABLED 게이트·staging 프로파일·E2E 테스트)으로 EKS/MSK 배포·전도메인 audit 커버에 필요, 로컬 E2E엔 불요. cards-generated HTTP(D-001). ✅ **06-08 해소**: shared `NotificationSend.avsc`·`UserRegistered.avsc` 정본을 platform-canonical(`com.synapse.platform`)로 정렬 완료([shared#26](https://github.com/team-project-final/synapse-shared/pull/26)). **잔여 owner P0**(서비스 벤더링 교체, [AVRO_CONTRACT_FIX_W5](../fix-requests/AVRO_CONTRACT_FIX_W5.md)): engagement UserRegistered reader(F1) · learning-ai NotificationSend writer(F2/F3) — Day 2 풀 E2E 선결.

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
| W3 종료 게이트 평가 | `docs/reports/W3_EXIT_GATE.md` | **미통과 (충족 0/5)** — 차단=서비스 Kafka 미완성(knowledge 미구현·platform/engagement dev) |
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
