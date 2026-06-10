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
- [ ] **핵심 10 시나리오 풀 실행** (FR-ALL-301/NFR-303) — Day 2. **선결: owner P0 2건 수정**(AVRO_CONTRACT_FIX_W5)
- [ ] 전체 체인 < 10초(FR-TL-401) · audit 적재 < 30초(NFR-403) — Day 2
### 9.3 버그 트리아지
- [x] **P0 선발견(스모크)**: F1 engagement UserRegistered reader / F2·F3 learning-ai NotificationSend writer → 정본 정렬(shared#26) + owner 지시서. P2: F4 learning-ai AI키 게이트
- [ ] Day 2 풀 시나리오 후 잔여 버그 P0/P1/P2 분류
### 9.4~9.6
- [ ] P0 수정 지시·추적 → 회귀 → 커버리지 80%(9.5) → API 문서/HISTORY(9.6)

**Step 9 Status**: [ ] Not Started / [x] In Progress / [ ] Done — 환경 구성·스모크·P0 선발견 완료(06-08), 풀 10시나리오는 owner P0 수정 후 Day 2

---

## Step 10: 성능 SLA 검증 (W4 이월)
### 10.1 정의 — [x] SLA_VERIFICATION_W4 P1~P7 (W4 완료)
### 10.2 실행
- [~] **P2 Kafka<5s** — 06-05 **브로커 전송 지연 부분측정 PASS**(발행 p99 113ms·소비 fetch 39ms/1k, [SLA_VERIFICATION_W4 §5.1](../../reports/SLA_VERIFICATION_W4.md)). **잔여=풀 홉(consumer→DB) eventId correlation 측정**(서비스 E2E 후)
- [ ] P1 API P95<200ms · P3 검색<2s · P4 체인<10s · P5 audit<30s · P6 AI카드<30s · P7 FCM>95% (3회 평균, Day 3)
### 10.3~10.6 — [ ] 미달 P0 수정 → 회귀 → 결과 문서화

**Step 10 Status**: [ ] Not Started / [x] In Progress / [ ] Done — P2 브로커 전송 지연 부분측정(06-05). 나머지·풀 홉은 E2E 통과 후(Day 3)

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
- [ ] FR-TL-304 API 문서 최신화 (SpringDoc + gateway 라우팅 대조)
- [ ] FR-ALL-303 커버리지 80% 종합 집계 조율

> **머지 정책 주의**: 서비스 레포 작업은 직접 머지하지 말 것(owner 직접). team-lead 직접 가능 = gitops/shared/gateway. 머지 상태 확인은 `git fetch` 후 origin/main 기준([W4_EXIT_GATE §4](../../reports/W4_EXIT_GATE.md)).
