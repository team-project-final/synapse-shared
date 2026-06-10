# W5 Day3 마무리(closeout) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (or subagent-driven). 체크박스 추적.

**Goal:** owner 작업과 무관하게 오늘 종결 가능한 4항목(platform 커버리지 baseline · W1 풀체인 PASS · SLA P1~P5 리포트 · 추적 정합)을 순서대로 마무리하고 shared PR로 종결.

**Architecture:** 오프라인(gradle) + 라이브(e2e 스택) 혼합. 라이브는 Docker 재기동 후 단일 스택 세션에서 W1 시나리오와 SLA 측정을 함께 수행. 산출 리포트는 shared 직접 머지.

**Tech Stack:** Gradle/JaCoCo, docker compose(e2e), kafka-avro-console-producer, curl, PowerShell/bash.

**Scope OUT:** P6 AI(F4 키), P7 실 FCM 발송률(자격), 커버리지 80%·타서비스 jacoco, owner 이슈(#86/#87/#73/#68). → 스펙 §3.

---

## Task 1 (오프라인): platform 커버리지 baseline

**Files:** Create `docs/reports/COVERAGE_BASELINE_W5.md`

- [ ] **Step 1: platform jacoco 리포트 생성**

Run:
```
pwsh -c "Push-Location C:\workspace\team-project-final\synapse-platform-svc; .\gradlew.bat test jacocoTestReport --console=plain; Pop-Location"
```
Expected: BUILD SUCCESSFUL. 리포트 위치: `synapse-platform-svc/build/reports/jacoco/test/jacocoTestReport.xml`(+html).

- [ ] **Step 2: 커버리지% 추출**

`jacocoTestReport.xml`의 `<counter type="INSTRUCTION"/>`(또는 LINE) covered/missed로 % 산출. (Read 또는 grep `<counter type="LINE"`)

- [ ] **Step 3: COVERAGE_BASELINE_W5.md 작성**

표: 서비스 | jacoco 설정 | 커버리지%(LINE/INSTRUCTION) | 비고.
- platform-svc: 측정값 기입.
- engagement·knowledge·learning-card: **jacoco 미설정 → 측정 불가(owner 빌드 설정 이월)** 명시.
- learning-ai: pytest-cov 여부 확인 결과 기입.
- 결론: 80% 달성은 owner 작업(전 서비스 jacoco + 테스트 보강), 본 baseline은 현황 스냅샷.

- [ ] **Step 4: 커밋**
```
git add docs/reports/COVERAGE_BASELINE_W5.md
git commit -m "docs(coverage): platform 커버리지 baseline + 타서비스 jacoco 현황 (W5)"
```

---

## Task 2 (라이브 준비): Docker 재기동 + e2e 스택

- [ ] **Step 1: Docker Desktop 기동 + 데몬 대기**

`Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"` 후 `docker info` 성공까지 폴링(최대 180s).

- [ ] **Step 2: engagement worktree origin/main 새로고침(A 머지 반영)**
```
git -C ../.e2e-worktrees/synapse-engagement-svc fetch origin
git -C ../.e2e-worktrees/synapse-engagement-svc checkout origin/main --detach
```

- [ ] **Step 3: 스택 기동**
```
docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --build
```
stale 시 `down -v` 후 재기동. `docker compose ... ps`로 platform/engagement/knowledge/learning-card/learning-ai/gateway + kafka/schema-registry healthy 확인. (registry host 포트는 `docker port synapse-schema-registry`로 확인 — 8081은 platform 점유.)

---

## Task 3 (라이브): W1 풀체인 PASS + SLA P3/P4/P5 측정

**Files:** 측정 로그 수집(다음 Task에서 리포트화)

- [ ] **Step 1: W1 풀체인 정식 시나리오**

경계유저(UUID `11111111-1111-1111-1111-111111111111`, UUID tenant) 복습×N(레벨 임계 초과, learning-card XP 10/review·lvl2=100XP → 10건+) `ReviewCompleted` Avro 발행(`learning.card.review-completed-v1`, kafka-avro-console-producer). 검증·계측:
  - engagement: XP 증가 + 레벨업(user_profiles_gamification) — DB 또는 로그.
  - audit: platform `audit_logs`에 레벨업/리뷰 관련 적재(P5 <30s).
  - 알림: platform notification consumer가 LevelUp NotificationSend 소비 + `UUID.fromString` 통과 + "FCM skip for user <UUID>" 로그(경로 OK), notification-send DLT 0.
  - **체인 시간 측정**(P4 <10s): ReviewCompleted 발행 → 레벨업 audit 적재까지 경과.

- [ ] **Step 2: P3 검색 측정(<2s)**

knowledge 검색 API(직접 8082 또는 gateway) 호출 3회, 응답시간 측정. (인증 필요 시 platform JWT 발급 → 검색.) 시맨틱 leg(learning-ai)는 F4로 제외, 키워드/RRF 검색 레이턴시 기록.

- [ ] **Step 3: P1·P2·P5 재확인(기측정 인용)**

P1(API P95<200ms)·P2(Kafka 홉~1.4s)·P5(audit<30s)는 W5 Day2 측정값 인용 + 본 세션에서 관측된 값으로 보강(가능 범위).

- [ ] **Step 4: 측정값 수집 정리** — 각 P별 측정치/PASS-FAIL 메모.

---

## Task 4 (통합): SLA 리포트 + W1 종결 기록

**Files:** Create `docs/reports/SLA_VERIFICATION_W5.md`

- [ ] **Step 1: SLA_VERIFICATION_W5.md 작성**

표: 항목 | 목표 | 측정값 | 판정 | 근거.
- P1 API P95<200ms: ✅(Day2 79.7/15.3ms)
- P2 Kafka<5s: ✅(~1.4s)
- P3 검색<2s: (Task3 측정값)
- P4 체인<10s: (Task3 측정값, 알림 leg 포함)
- P5 audit<30s: ✅(~0.7s)
- P6 AI<30s: ⛔ 보류 — AI키 부재(learning #73/F4)
- P7 FCM>95%: 🟡 경로 OK(skip 검증)·실발송률 보류(FCM 자격) — owner
- **W1 풀체인 종결**: 복습→XP→레벨업→audit→알림(skip) PASS 기록(A 머지로 알림 leg 동작 — W5 Day2 🔴 해소).

- [ ] **Step 2: 커밋**
```
git add docs/reports/SLA_VERIFICATION_W5.md
git commit -m "docs(sla): W5 SLA P1~P5 측정·종결 + W1 풀체인 PASS (P6/P7 보류 명시)"
```

---

## Task 5 (정합·종결): 추적 갱신 + PR

**Files:** Modify `docs/project-management/workflow/WORKFLOW_team-lead_W5.md`, `docs/project-management/HANDOFF_W5_DAY3.md`

- [ ] **Step 1: WORKFLOW_W5 Step10 갱신** — P1~P5 측정 완료([SLA_VERIFICATION_W5]) 반영, P6/P7 보류 사유. FR-ALL-303은 platform baseline + 타서비스 owner 이월 명시.

- [ ] **Step 2: HANDOFF_W5_DAY3 §0 갱신** — SLA P1~P5 종결·W1 풀체인 PASS·커버리지 baseline 추가, 이월에서 해당분 제거(P6/P7/커버리지80%만 잔류).

- [ ] **Step 3: 커밋 + push + PR(shared, feature→main) + admin 머지**
```
git add docs/project-management/...
git commit -m "docs(tracking): W5 SLA P1~P5·W1·커버리지 baseline 종결 반영"
git push -u origin feat/w5-day3-closeout
gh pr create -R team-project-final/synapse-shared --base main --head feat/w5-day3-closeout ...
gh pr merge --squash --admin --delete-branch
```

---

## 완료 기준 (이 플랜)
- COVERAGE_BASELINE_W5.md(platform 측정 + 타서비스 이월) 커밋.
- SLA_VERIFICATION_W5.md(P1~P5 측정·판정 + W1 PASS + P6/P7 보류) 커밋.
- WORKFLOW_W5·HANDOFF 갱신.
- shared PR 머지.
- OUT 항목(P6·P7 실발송·커버리지80%·owner 이슈)은 손대지 않고 사유만 기록.
