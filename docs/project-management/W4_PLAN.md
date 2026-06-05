# W4 실행 순서 (월요일 바로 시작용)

> **작성**: 2026-05-29 (W3 종료) · **기간**: 2026-06-01(월)~06-05(금), **6/3(수) 지방선거 휴무 → 4영업일**
> **근거**: [PRD_W4](./prd/PRD_W4.md) · [W4_KAFKA_WORKORDER](../work-orders/W4_KAFKA_WORKORDER.md) · [EVENT_CONTRACT_STANDARD](../guides/EVENT_CONTRACT_STANDARD.md) · [W3_EXIT_GATE](../reports/W3_EXIT_GATE.md)
> **W4 목표(PRD)**: notification(FCM/SES) + audit Kafka 소비 + Admin 모더레이션 + 통합 E2E + dev/staging 배포 검증

> ## 📍 06-05(Day 4, 마지막날) 종료 실측 — 권위 문서: [W4_EXIT_GATE](../reports/W4_EXIT_GATE.md)
> - **서비스 Kafka 4서비스 전원 origin/main 머지 완료** (knowledge #40·platform #46·engagement #23·learning) → §0 "knowledge Producer 미구현/임계경로" 가정은 **해소**. 통합 E2E는 머지 무관.
> - **계약·전송 E2E 06-05 실행 PASS** ([E2E_REPORT_W4](../reports/E2E_REPORT_W4.md)): `--avro` 8/8(게이트 §1)·`--all` 5/5·`--full` 13/13·`--scenarios` 5/5.
> - **잔여(→W5 이월)**: 서비스 비즈니스 로직 E2E 실행(shared compose app=스텁이라 불가, 서비스 스택/staging 필요) · SLA 측정(Step 10) · EKS staging 배포+Observability(Step 11) · 하드닝 dev→main 머지(platform #52 audit/#54 TLS/#48 staging·engagement #24·knowledge #45). → [WORKFLOW_team-lead_W5](./workflow/WORKFLOW_team-lead_W5.md)
> - **PRD §5**: 6기준 모두 **구현 충족·검증 실행 대기**. dev 배포검증 ✅(5/5) / staging 🟡(platform #37, 수정 #48 dev 대기).

---

## 0. 임계 경로 (왜 이 순서인가) — ⚠️ 05-29 작성 시점 가정. 06-05 실측은 위 배너 참조

```
[체인 시작점] knowledge note-created Producer (현재 미구현, P0)
    └─→ learning-ai 소비(구현됨) → AI 카드
[발행원] gamification(engagement)·review-due(learning-card) Producer (dev/일부)
    └─→ platform notification/audit 소비 (W4 핵심 목표)
[배포] EKS destroy → terraform apply (Kafka 무관, 병렬 가능)
    └─→ Step 8 실행·staging·Observability
[계약] Avro 표준 확정·스키마/토픽/harness 검증 완료 → 서비스가 "적용"만 하면 됨
```
- **PRD_W4 §6**: "W3 producer 잔여 시 **6/1 첫날 producer 보완**, **소비는 6/2부터 본격**" — 아래 순서가 이를 따름.
- W3 종료 게이트 미통과(충족 0/5)의 단일 차단 = 서비스 Kafka. W4 Day1이 그 해소일.

---

## 1. 🌅 월요일(06-01) 아침 — 가장 먼저 (병렬 2트랙)

### Track A — 인프라 (on-demand, team-lead / gitops) ※ **Kafka·E2E 임계경로와 무관** — 상세: [W4_DAY1_POST_APPLY](../runbooks/W4_DAY1_POST_APPLY.md)
- [x] `terraform apply` 멱등 검증(06-01) — apply↔destroy 가능 확인. **현재 비용관리 destroy 상태**
- [x] **EKS window 진입 하드닝 완료(06-02, gitops)** — bastion aws-auth/kafka read([#87](https://github.com/team-project-final/synapse-gitops/issues/87)) · 브로커 ConfigMap 자동화([#88](https://github.com/team-project-final/synapse-gitops/issues/88)) · D-026 SG terraform 코드화([#89](https://github.com/team-project-final/synapse-gitops/issues/89)) · MSK 9토픽 terraform화. → **수동 SG/토픽 생성 제거, kubectl 401 해소**(PR #90)
- [ ] **배포 검증 window**(Step 8/11): `terraform apply` → **ArgoCD 부트스트랩([gitops #91](https://github.com/team-project-final/synapse-gitops/issues/91))** → `verify-argocd-deploy.sh synapse-dev` 5/5. (토픽=terraform 자동, 브로커=ConfigMap 자동, SG=코드화 → 수동단계 없음)
- → Step 8(1.7~1.9)·staging·Observability·**EKS 레지스트리** 실검증은 이 window에서. **계약 BACKWARD 실검증은 로컬 `--avro`(8/8)로 06-02 완료 — EKS 불필요(게이트 §1 ✅)**

### Track B — 계약 적용 착수 (team-lead + 각 owner)
- [x] **(team-lead)** shared **v0.1.0 발행 완료(06-02)** — `v0.1.0` 태그 push → publish.yml run 26792658024 성공. `com.synapse:synapse-shared:0.1.0` GitHub Packages 등록. → 서비스가 `com.synapse:synapse-shared` 의존 가능(소비측 read:packages 토큰 배선만 잔여)
- [ ] **(데일리 10:00 합의)** D-002(Avro 사수) 공유 + **2개 필드 확정**: `LevelUp`/`BadgeEarned` 도메인 필드(engagement), `NoteCreated.title`/`deckId` 채움(knowledge·learning-ai) → shared PR로 fix
- [ ] **(knowledge owner, P0 최우선)** note-created/updated **Producer 신규 구현** (이슈 [#26](https://github.com/team-project-final/synapse-knowledge-svc/issues/26)) — **체인 시작점, 이게 늦으면 W4 소비 전체 지연**
- [ ] **(platform/engagement/learning owner)** 계약 표준 적용 + dev→main PR (이슈 [#43](https://github.com/team-project-final/synapse-platform-svc/issues/43)/[#13](https://github.com/team-project-final/synapse-engagement-svc/issues/13)/[#32](https://github.com/team-project-final/synapse-learning-svc/issues/32))
- [x] **(team-lead, 06-02)** 로컬 `docker compose up` + `kafka-e2e-test.sh --avro` 8/8 + BACKWARD 라이브 강제 프로브 → "계약 OK" + 게이트 §1 ✅

---

## 2. 화(06-02) Day 2 — Consumer 본격 (PRD: 소비 6/2부터)

> **✅ team-lead 06-02 완료분** (카프카 조율 외 진행 가능 작업 소진): v0.1.0 발행(PR #9) · 게이트 §1 해소(로컬 `--avro` 8/8, 0/5→1/5) · Step 9.1/10.1 시나리오 정의(E2E_SCENARIOS_W4·SLA_VERIFICATION_W4) · MSK terraform/TLS 문서 정합(PR #10) · gitops 하드닝 #87~89 완료·#91 신규. **잔여 = 서비스 owner consumer 머지(engagement·knowledge 🔴) → 그 후 service E2E·배포 검증.**

- [ ] **(platform, P0)** notification 소비 — gamification.level-up / card.review-due → **FCM 푸시** (FR-PL-401). AI 카드 알림은 [NOTIFICATION_TRIGGER_AI_CARDS](../designs/NOTIFICATION_TRIGGER_AI_CARDS.md) 방식(learning-ai→notification-send-v1)
- [ ] **(platform, P0)** audit 소비 — 전 도메인 이벤트 → `audit_logs` 적재(90일) (FR-PL-404)
- [ ] **(engagement, P0)** user-registered/review-completed Consumer → 프로필/XP (이슈 #13)
- [ ] **(team-lead)** 서비스 PR 리뷰·머지 조율 (코드 리뷰 승인 기준: CloudEvent/Consumer Group/멱등성/Avro)
- [ ] **(team-lead, Step 8)** EKS 재기동 후 staging 수동 Sync + 배포 후 검증(1.7~1.9) + 롤백 1회 테스트
- [ ] **(team-lead, Step 7)** 서비스 기동 후 `E2E_SCENARIOS_W3` S1~S4 **service 단위** E2E 착수

## 3. 수(06-03) — 지방선거 휴무 (작업 없음)

## 4. 목(06-04) Day 3 — 통합 E2E + 운영
- [ ] **(team-lead, FR-TL-401 / NFR-401)** 전체 체인 E2E: **복습→XP→레벨업→알림 < 10초** (TASK Step 9)
- [ ] audit 적재 지연 < 30초 검증 (NFR-403)
- [ ] (knowledge-2) 검색 RRF E2E + 정확도 70%+ (FR-K2-401/402) / (learning-ai) AI 카드 자동생성 E2E (FR-LA-401)
- [ ] (engagement) 신고/모더레이션 API (FR-EG-401/402)
- [ ] **(gitops, W3 이월)** Observability 스택 설치(kube-prometheus-stack) + ServiceMonitor 5 + Grafana
- [ ] **(team-lead, Step 11)** staging 최종 배포 + 모니터링 대시보드

## 5. 금(06-05) Day 4 — 검증·마감
- [x] **PRD_W4 §5 성공 기준 체크리스트** 전수 확인 — [W4_EXIT_GATE §1](../reports/W4_EXIT_GATE.md): 6/6 구현충족·검증대기
- [x] **계약·전송 E2E 실행** — [E2E_REPORT_W4](../reports/E2E_REPORT_W4.md) `--avro`8/8·`--all`5/5·`--full`13/13·`--scenarios`5/5 PASS
- [~] **(team-lead, Step 10)** SLA 성능 검증 — 시나리오 정의 완료(SLA_VERIFICATION_W4), **측정은 서비스 스택/staging 필요 → W5 이월**
- [x] 미해결 이슈 정리 + **W5 인수인계** + HANDOFF 갱신 — [W4_EXIT_GATE §4](../reports/W4_EXIT_GATE.md) + HANDOFF_HUB/SHARED origin 실측 정정 + [WORKFLOW_team-lead_W5](./workflow/WORKFLOW_team-lead_W5.md)

---

## 6. team-lead TASK 매핑
| Step | 내용 | W4 배치 |
|------|------|--------|
| Step 7 (W3 이월) | Kafka E2E service 단위 | Day 2~4 (producer 도착 후) |
| Step 8 (W3 이월) | dev/staging 배포 검증 | **Day 1(EKS apply)** + Day 2(staging 실행) |
| Step 9 | E2E 시나리오 정의/조율 | Day 3 |
| Step 10 | SLA 성능 검증 | Day 4 |
| Step 11 | Staging 최종 배포 + 모니터링 | Day 3~4 |

## 7. 선결 체크 (월요일 출발 전 확인)
- ✅ 이벤트 계약 표준·스키마(11종)·토픽(8종)·harness `--avro`(8/8) — **준비 완료**
- ✅ 서비스 이슈 4건 발행(Avro/shared 사용/Kafka 설정/로컬 실행/DoD/기한)
- ✅ 라이브러리 발행 **완료(06-02)** — `com.synapse:synapse-shared:0.1.0` GitHub Packages 등록(run 26792658024). 소비측 의존 배선만 잔여
- ⛔ EKS destroy — Day1 Track A `terraform apply` 필요
- ⛔ owner 필드 확정 2건 — Day1 데일리

> **한 줄 요약**: 월요일 = (A) EKS 올리고 + (B) **knowledge Producer 착수** + v0.1.0 발행 + 필드 확정. 화요일부터 platform/engagement consumer. 목요일 통합 E2E. 금요일 검증·인계.
