# WORKFLOW: @team-lead — Week 5

> **Task 문서**: [TASK_team-lead.md](../task/TASK_team-lead.md)
> **기간**: 2026-06-08(월) ~ 2026-06-12(금) — 5영업일 · **발표**: 06-15(월, 코드 동결)
> **PRD**: [PRD_W5.md](../prd/PRD_W5.md) · **실행 순서**: [W5_PLAN.md](../W5_PLAN.md) · **이월 출처**: [W4_EXIT_GATE](../../reports/W4_EXIT_GATE.md)

> **📍 W5 = W4 검증 실행 이월 + 발표 준비**. 구현(4서비스 Kafka origin/main)·계약/전송 E2E·시나리오 정의는 W4 완료. W5는 **서비스 단위 E2E·SLA·staging·발표** 실행.

---

## Step 9: 전체 E2E 서비스 단위 실행 (W4 이월)

### 9.2 E2E 테스트 실행
- [x] 계약·전송 E2E (W4 06-05 PASS — E2E_REPORT_W4)
- [x] **서비스 단위 E2E 환경** — `docker-compose.e2e.yml`(origin/main worktree 실빌드, 13/13 healthy, 06-08). 가입 스모크 통과 ([E2E_SMOKE_W5_DAY1](../../reports/E2E_SMOKE_W5_DAY1.md))
- [~] **핵심 시나리오 실행** (FR-ALL-301/NFR-303) — W4·W2·W3·W5·**W1 풀체인 PASS**(Day3, 알림 leg A로 해소). AI생성 leg=F4(learning#73)·검색 leg=nori(gitops#174) 차단
- [x] 전체 체인 < 10초(FR-TL-401) · audit < 30초(NFR-403) — **W1 체인 1.31s·audit 1.31s**(Day3, [SLA_VERIFICATION_W5](../../reports/SLA_VERIFICATION_W5.md))
### 9.3 버그 트리아지
- [x] **P0 선발견(스모크)**: F1 engagement UserRegistered reader / F2·F3 learning-ai NotificationSend writer → 정본 정렬(shared#26) + owner 지시서. P2: F4 learning-ai AI키 게이트
- [x] 잔여 버그 분류·발행 — F7/F9(수정) · F8 platform#86 · F10 D-004 Stage1(해소) · audit DLT platform#87 · nori gitops#174
### 9.4~9.6
- [~] P0 수정(F1/F2/F3/F7/F9/F10 ✅) → 회귀 → **커버리지: platform line 92.4% baseline**([COVERAGE_BASELINE_W5](../../reports/COVERAGE_BASELINE_W5.md), 타서비스 jacoco owner 이월) → **API 문서 ✅(shared#35)·HISTORY 갱신**

**Step 9 Status**: [ ] Not Started / [x] In Progress / [ ] Done — 핵심 시나리오·W1 풀체인·체인 SLA·API문서·커버리지 baseline 완료(Day3). 잔여=커버리지 80%(전서비스 jacoco·owner)·AI/검색 leg(F4·nori)

---

## Step 10: 성능 SLA 검증 (W4 이월)
### 10.1 정의 — [x] SLA_VERIFICATION_W4 P1~P7 (W4 완료)
### 10.2 실행
- [~] **P2 Kafka<5s** — 06-05 **브로커 전송 지연 부분측정 PASS**(발행 p99 113ms·소비 fetch 39ms/1k, [SLA_VERIFICATION_W4 §5.1](../../reports/SLA_VERIFICATION_W4.md)). **잔여=풀 홉(consumer→DB) eventId correlation 측정**(서비스 E2E 후)
- [x] **P1·P2·P4·P5 충족 + W1 풀체인 PASS** (Day3, [SLA_VERIFICATION_W5](../../reports/SLA_VERIFICATION_W5.md)): P1 79.7/15.3ms · P2 ~1.42s · **P4 체인 1.31s(알림 leg 포함)** · **P5 audit 1.31s**. 보류: P3 검색(ES nori 미설치 → [gitops#174](https://github.com/team-project-final/synapse-gitops/issues/174)) · P6 AI(키 부재 → learning#73) · P7 실 FCM 발송률(자격; 경로·DLT 0은 입증)
### 10.3~10.6 — [x] 결과 문서화([SLA_VERIFICATION_W5]) · 미달 P0 없음(측정분 전부 충족)

**Step 10 Status**: [ ] Not Started / [ ] In Progress / [x] Done(측정 가능분) — P1·P2·P4·P5 충족·W1 PASS(Day3 라이브). P3/P6/P7 외부·인프라 의존 보류(이슈 추적)

---

## Step 11: Staging 배포 + 모니터링 대시보드 (W4 이월)
### 11.2 실행
- [x] EKS 재apply → ArgoCD 부트스트랩 → dev 5/5 재확인 — **06-08 완료 (dev 16/0/0)**
- [x] **platform/gateway CrashLoop 해소 → staging 5/5** — **06-08 완료 (staging 20/0/0)**. 근본 원인=DB 공유 flyway 충돌(#37 실체) + gateway JWT 미매핑 → [gitops#136](https://github.com/team-project-final/synapse-gitops/pull/136)
- [x] Observability(kube-prometheus-stack) + Grafana + 알림 규칙 — **bring-up에 포함, 06-08 기동** (ServiceMonitor/대시보드 검증·SLA 알림 튜닝은 Day 4)
- [ ] staging 24h 안정(NFR-305) — Day 4 시작
### 11.6 — [ ] Staging 배포 결과 + 운영 가이드 문서화 — Day 4

**Step 11 Status**: [ ] Not Started / [x] In Progress / [ ] Done — dev/staging 5/5 + monitoring 기동 완료(06-08, Day1에 Day4 일부 선반영). 잔여=24h 안정·대시보드 검증·문서화(Day 4)

---

## Step 12: 최종 발표 자료 + 시연 리허설
- [ ] 슬라이드 15~20 + 데모 스크립트 5분 (FR-TL-305)
- [ ] 시연 환경 사전 점검 (staging/네트워크/시드/깨진링크 0)
- [ ] **전체 팀 리허설 1회+ (06-12, 발표 D-3)** + 회고 → 보완
- [ ] 코드 동결 (06-15 전, P0 hotfix만)

**Step 12 Status**: [ ] Not Started / [ ] In Progress / [ ] Done — 실행 Day 5

---

## team-lead 외 추가 W5 책무 (PRD §2.2)
- [x] FR-TL-302 Schema BACKWARD 전 토픽 전수 — 9 subject 강제 프로브 전수(cards-generated 포함) 9/9 PASS, `scripts/check-schema-backward-all.ps1` + [SCHEMA_BACKWARD_W5_DAY3](../../reports/SCHEMA_BACKWARD_W5_DAY3.md)
- [x] FR-TL-304 API 문서 최신화 — 5서비스 OpenAPI survey + gateway 대조([API_DOC_SURVEY_W5_DAY3](../../reports/API_DOC_SURVEY_W5_DAY3.md)). 노출 O: engagement·learning-ai / 누락 3서비스 레포 상세 이슈 발행: platform#84·knowledge#67·learning#72(learning-card)
- [~] FR-ALL-303 커버리지 종합 집계 — platform **line 92.4%(>80%)** baseline([COVERAGE_BASELINE_W5](../../reports/COVERAGE_BASELINE_W5.md)). engagement·knowledge·learning **jacoco 미설정 → owner 이월**(전 서비스 80% 달성 미완)

## 미완 owner 이슈 레지스터 (06-10 실측 발행, team-lead 직접 머지 불가)
| 이슈 | 항목 | 차단 |
|---|---|---|
| platform [#86](https://github.com/team-project-final/synapse-platform-svc/issues/86) | F8 ADMIN role 발급 부재 | W4-3 모더레이션 E2E |
| platform [#87](https://github.com/team-project-final/synapse-platform-svc/issues/87) | audit 컨슈머 ReviewCompleted DLT(라이브 재현) | audit 정합 |
| platform [#91](https://github.com/team-project-final/synapse-platform-svc/issues/91) | 미커밋 V28 oauth rename(버전충돌·스키마 갭) | DB 테스트·OAuth |
| learning [#73](https://github.com/team-project-final/synapse-learning-svc/issues/73) | F4 AI키 graceful 게이트 | W4-5 AI E2E·P6 |
| knowledge [#68](https://github.com/team-project-final/synapse-knowledge-svc/issues/68) | dev→main 18커밋 미반영(F9·TLS·검색) | 배포 정합 |
| gitops [#174](https://github.com/team-project-final/synapse-gitops/issues/174) | ES analysis-nori 미설치 | W4-4 검색·P3 |
| gitops [#175](https://github.com/team-project-final/synapse-gitops/issues/175) | bringup.out .gitignore | 정리 |
| API문서 | platform#84·knowledge#67·learning#72 | FR-TL-304 갭 |
| knowledge [#71](https://github.com/team-project-final/synapse-knowledge-svc/issues/71) | note→ES 인덱서 컨슈머 미등록 | P3 기능검색(결과 0) |
| knowledge [#72](https://github.com/team-project-final/synapse-knowledge-svc/issues/72) | 청킹 pgvector 타입 불일치 | 시맨틱/임베딩 |
| knowledge [#74](https://github.com/team-project-final/synapse-knowledge-svc/issues/74) | note-create deckId 계약 갭 | P6 AI카드 트리거 |
| learning [#77](https://github.com/team-project-final/synapse-learning-svc/issues/77) | Anthropic 모델ID 폐기(404) | P6 AI 생성 |
| learning [#78](https://github.com/team-project-final/synapse-learning-svc/issues/78) | note 본문 fetch 계약 불일치 | P6 체인(500→DLQ) |
| 커버리지 jacoco | engagement#39·knowledge#73·learning#76 | FR-ALL-303 80% |

### P3/P6/P7 착수 결과 (06-10, owner 무관 진전분)
- **P3** 🟢 nori 해소(shared#42, 검색 200·0.012s≪2s) / 기능검색은 knowledge#71·#72 / EKS는 gitops#174(ECR)
- **P6** 🔴 키 인증 OK이나 체인 4중 갭(knowledge#74·learning#77/#78·OpenAI 할당량) → 측정불가
- **P7** 🟢 FCM 배선·인증 검증(SA 주입·실 FCM API 호출, skip 해소) / >95% 발송률은 실 디바이스 토큰 필요. minor: notification status=SENT 부분실패 미반영(platform)
- **보안** secrets/ .gitignore(shared#44)

> **머지 정책 주의**: 서비스 레포 작업은 직접 머지하지 말 것(owner 직접). team-lead 직접 가능 = gitops/shared/gateway. 머지 상태 확인은 `git fetch` 후 origin/main 기준([W4_EXIT_GATE §4](../../reports/W4_EXIT_GATE.md)).
