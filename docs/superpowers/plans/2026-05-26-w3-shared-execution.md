# W3 synapse-shared 실행 계획 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** W3(05-26~05-29) 동안 synapse-shared의 team-lead가 클러스터·팀PR에 독립적인 통합 검증·조율·문서 작업(work-order 발행, 로컬 docker-compose E2E, 정직한 리포트, W3→W4 핸드오프)을 완료한다.

**Architecture:** gitops 인프라/배포/관측은 머지된 PR #47 통합 플랜이 담당하므로 제외. shared는 ① 팀 Kafka를 work-order로 외부화·추적 ② 로컬 docker-compose로 토픽/스키마/컨슈머 경로를 "구현된 만큼" 검증 ③ 결과를 정직하게 리포트하고 W4로 이월. 일자별(Day1 언블로킹+harness → Day2~3 리뷰/머지 → Day4 전체 E2E+핸드오프) 진행.

**Tech Stack:** Docker Compose, Kafka(console producer/consumer), Avro/Schema Registry, bash(`scripts/kafka-e2e-test.sh`), GitHub CLI(`gh`), Markdown 문서.

**Spec:** `docs/superpowers/specs/2026-05-26-w3-shared-execution-design.md`

**드롭 우선순위 (시간 부족 시):**
- 절대 보호: Task 1(work-order), Task 3(harness 베이스라인), Task 7~8(리포트/핸드오프)
- 1차 드롭: Task 9(local-k8s 포인터) → W4 이월
- 2차 드롭: Task 5 샘플 갭 보강 → 기존 샘플로 진행

---

## 파일 구조 (생성/수정 대상)

| 경로 | 동작 | 책임 |
|---|---|---|
| `docs/work-orders/W3_KAFKA_WORKORDER.md` | 생성 | 5개 서비스 Kafka 구현 work-order + 추적 테이블 (기존 체크리스트 참조, 중복 없음) |
| `docs/guides/TEAM_CHECKLIST_W3.md` | 수정 | 현 인프라 현실(클러스터 destroy, 로컬 우선) 반영 |
| `docs/reports/E2E_BASELINE_W3.md` | 생성 | Day1 harness 베이스라인 결과 (서비스 구현 0 기준선) |
| `docs/reports/E2E_REPORT_W3.md` | 수정(채움) | 최종 E2E 결과 (미구현/이월 정직 표기) |
| `docs/reports/DEPLOY_REPORT_W3.md` | 수정(채움) | 배포/관측 현황 (gitops 결과 + 미검증 표기) |
| `docs/project-management/HANDOFF_HUB.md` | 수정 | W3→W4 전환, 정합성 갱신 |
| `docs/project-management/HANDOFF_SHARED.md` | 수정 | Kafka 구현 현황 + W3 결과 |
| `docs/project-management/workflow/WORKFLOW_team-lead_W3.md` | 수정 | Step 7/8 체크박스 현행화 |
| `README.md` | 수정 | gitops `local-k8s`(minikube) 포인터 1줄 |

> **명령 실행 환경**: 작업 디렉터리는 `C:\workspace\team-project-final\synapse-shared`. bash 스크립트는 Bash 도구로 실행. docker/gh는 PowerShell·Bash 양쪽 가능.

---

## Day 1 (05-26) — 언블로킹 + harness 베이스라인

### Task 1: cross-repo Kafka work-order 발행

**Files:**
- Create: `docs/work-orders/W3_KAFKA_WORKORDER.md`

- [ ] **Step 1: work-order 디렉터리 + 문서 생성**

`docs/work-orders/W3_KAFKA_WORKORDER.md` 파일을 아래 내용으로 생성한다. 서비스별 상세 구현 항목은 `TEAM_CHECKLIST_W3.md`에 이미 있으므로 **참조**만 하고 중복하지 않는다.

```markdown
# W3 Kafka 구현 Work-Order

> **작성일**: 2026-05-26 (W3 Day 1)
> **작성자**: @team-lead (synapse-shared)
> **우선순위**: P0 — W3/W4 Kafka E2E 통합 차단
> **PR 생성 기한**: 2026-05-27 (수, Day 2 종료)

## 배경

W3 목표는 모든 producer 토픽 발행 + consumer 처리(PRD_W3 FR-*-201 계열). 현재 5개 서비스 Kafka Producer/Consumer **전부 미착수**. 각 owner는 아래 할당 범위를 구현하고 기한 내 PR을 생성한다.

## 인프라 현황 (중요)

- EKS 클러스터는 비용 관리로 **destroy 상태** — 검증은 **로컬 docker-compose** 기준.
- 로컬 Kafka: `localhost:9092`(외부) / `kafka:29092`(컨테이너), Schema Registry `http://schema-registry:8081`.
- (선택) 로컬 k8s로 띄우려면 synapse-gitops `local-k8s/` 참조.

## 서비스별 할당

| # | 서비스 | 레포 | 역할 | 상세 구현 항목 | 이슈 |
|---|--------|------|------|----------------|------|
| 1 | platform-svc | synapse-platform-svc | Producer(UserRegistered) + Consumer(CardsGenerated) | TEAM_CHECKLIST_W3.md §platform-svc | (issue URL) |
| 2 | knowledge-svc | synapse-knowledge-svc | Producer(NoteCreated, NoteUpdated) | TEAM_CHECKLIST_W3.md §knowledge-svc | (issue URL) |
| 3 | learning-card | synapse-learning-svc | Producer(ReviewCompleted) | TEAM_CHECKLIST_W3.md §learning-card-svc | (issue URL) |
| 4 | learning-ai | synapse-learning-svc | Producer(CardsGenerated) + Consumer(NoteCreated) | TEAM_CHECKLIST_W3.md §learning-ai-svc | (issue URL) |
| 5 | engagement-svc | synapse-engagement-svc | Consumer(UserRegistered, ReviewCompleted) | TEAM_CHECKLIST_W3.md §engagement-svc | (issue URL) |

## 공통 요구사항 + 코드 리뷰 승인 기준

→ [TEAM_CHECKLIST_W3.md](../guides/TEAM_CHECKLIST_W3.md) "공통 요구사항" / "코드 리뷰 승인 기준" 참조.

## 참조 문서

- 이벤트 흐름: [EVENT_FLOW_MATRIX.md](../guides/EVENT_FLOW_MATRIX.md)
- E2E 시나리오: [E2E_SCENARIOS_W3.md](../guides/E2E_SCENARIOS_W3.md)
- E2E 검증 가이드: [KAFKA_E2E_TEST.md](../guides/KAFKA_E2E_TEST.md)

## 추적 (Day 2~3 갱신)

| 서비스 | PR 생성 | 리뷰 | 머지 | 비고 |
|--------|:------:|:----:|:----:|------|
| platform-svc | ⏳ | — | — | |
| knowledge-svc | ⏳ | — | — | |
| learning-card | ⏳ | — | — | |
| learning-ai | ⏳ | — | — | |
| engagement-svc | ⏳ | — | — | |

> 상태: ⏳ 대기 / 🔄 진행 / ✅ 완료 / ❌ 미착수(기한 초과)
```

- [ ] **Step 2: 파일 생성 확인**

Run: `bash -c 'ls -la docs/work-orders/W3_KAFKA_WORKORDER.md'`
Expected: 파일 존재.

- [ ] **Step 3: (선택) GitHub 이슈로 전달**

> 외부 레포에 이슈를 생성하는 작업이다. 실행 전 사용자 확인. 솔로/시뮬레이션 환경이면 문서 전달로 대체 가능.

각 서비스 레포에 work-order 이슈 생성 (learning은 card/ai 2건):
```bash
gh issue create --repo team-project-final/synapse-platform-svc \
  --title "[W3] Kafka Producer(UserRegistered)+Consumer(CardsGenerated) 구현" \
  --body "기한 05-27. 상세: synapse-shared docs/guides/TEAM_CHECKLIST_W3.md §platform-svc. work-order: docs/work-orders/W3_KAFKA_WORKORDER.md"
```
(knowledge-svc, synapse-learning-svc×2, engagement-svc 동일 패턴)
생성된 이슈 URL을 Step 1 문서의 "이슈" 컬럼에 기입.

- [ ] **Step 4: 커밋**

```bash
git add docs/work-orders/W3_KAFKA_WORKORDER.md
git commit -m "docs: W3 Kafka 구현 cross-repo work-order 발행 (5개 서비스)"
```

---

### Task 2: 팀 체크리스트 현행화

**Files:**
- Modify: `docs/guides/TEAM_CHECKLIST_W3.md:5-15` (현재 인프라 상태 블록)

- [ ] **Step 1: "현재 인프라 상태" 블록 교체**

`docs/guides/TEAM_CHECKLIST_W3.md`의 5~15행(현재 인프라 상태 표 + Note)을 아래로 교체한다:

```markdown
## 현재 인프라 상태 (2026-05-26 갱신)

| 항목 | 상태 |
|------|------|
| 검증 기준 환경 | **로컬 docker-compose** (클러스터 비용 관리로 destroy) |
| EKS dev/staging | ⏸ destroy 상태 — 클라우드 E2E는 W4 이월 |
| 로컬 Kafka | `localhost:9092`(외부) / `kafka:29092`(컨테이너) |
| Schema Registry | `http://schema-registry:8081` |
| MSK 토픽(클라우드) | 5개 정의됨, 재apply 시 재생성 (gitops HANDOFF_W3 참조) |
| 로컬 k8s(선택) | synapse-gitops `local-k8s/` (minikube) 참조 |

> **Note**: W3 Kafka 검증은 **로컬 우선**입니다. 각 서비스는 `docker compose up`으로 기동해 Kafka 연결·발행·소비를 확인하세요. 클라우드(dev/staging) 검증은 인프라 재구축 후 W4에 진행합니다.
```

- [ ] **Step 2: 변경 확인**

Run: `bash -c 'grep -n "로컬 docker-compose" docs/guides/TEAM_CHECKLIST_W3.md'`
Expected: 라인 매치 출력(교체 반영됨).

- [ ] **Step 3: 커밋**

```bash
git add docs/guides/TEAM_CHECKLIST_W3.md
git commit -m "docs: 팀 체크리스트 인프라 현황 현행화 — 로컬 우선·클러스터 destroy 반영"
```

---

### Task 3: 로컬 E2E harness 베이스라인

**Files:**
- Create: `docs/reports/E2E_BASELINE_W3.md`

- [ ] **Step 1: docker-compose 기동**

Run: `bash -c 'docker compose up -d && sleep 5 && docker compose ps'`
Expected: kafka, schema-registry, postgres, redis, opensearch 등 컨테이너 Up. `synapse-kafka` 컨테이너 존재.

> Kafka가 healthy 될 때까지 10~20초 소요될 수 있음. `docker compose ps`에서 kafka가 running인지 확인.

- [ ] **Step 2: 토픽 5개 생성 (멱등)**

Run:
```bash
bash -c 'for t in platform.auth.user-registered-v1 knowledge.note.note-created-v1 knowledge.note.note-updated-v1 learning.card.review-completed-v1 learning.ai.cards-generated-v1; do docker exec synapse-kafka kafka-topics --bootstrap-server kafka:29092 --create --if-not-exists --topic "$t" --partitions 3 --replication-factor 1; done'
```
Expected: 각 토픽 `Created topic ...` 또는 이미 존재 시 메시지 없이 통과.

- [ ] **Step 3: 토픽 생성 확인**

Run: `bash -c 'docker exec synapse-kafka kafka-topics --bootstrap-server kafka:29092 --list'`
Expected: 위 5개 토픽이 목록에 표시.

- [ ] **Step 4: harness 정상 흐름 실행**

Run: `bash scripts/kafka-e2e-test.sh --all`
Expected: 5개 토픽 produce/consume `RESULT: PASSED`. (서비스 구현과 무관 — 토픽/전송 경로 검증)

> FAIL 시: kafka 미기동 또는 토픽 부재가 원인. Step 1~3 재확인.

- [ ] **Step 5: 베이스라인 결과 기록**

`docs/reports/E2E_BASELINE_W3.md` 생성. Step 4의 실제 PASS/FAIL/TIME 수치를 채운다:

```markdown
# W3 로컬 E2E harness 베이스라인

> **작성일**: 2026-05-26 (W3 Day 1)
> **목적**: 서비스 Kafka 구현 0인 상태에서 harness(토픽/전송/스크립트) 자체 동작 검증

## 환경
- docker-compose 로컬, Kafka `kafka:29092`, 토픽 5개 생성됨

## 결과 (`scripts/kafka-e2e-test.sh --all`)

| 항목 | 값 |
|------|----|
| PASS | (기입) |
| FAIL | (기입) |
| TIME | (기입)s |
| RESULT | PASSED / FAILED |

## 해석

- 이 테스트는 **전송 경로(토픽 produce→consume + CloudEvent JSON 라운드트립)** 검증이며, 서비스의 consumer 비즈니스 로직은 검증하지 않는다.
- 서비스 구현 도착 시(Day 2~3) `E2E_SCENARIOS_W3.md` 시나리오로 consumer 처리까지 확장 검증.
```

- [ ] **Step 6: 커밋**

```bash
git add docs/reports/E2E_BASELINE_W3.md
git commit -m "test: W3 로컬 E2E harness 베이스라인 — 토픽/전송 경로 검증"
```

- [ ] **Step 7: Day 1 종료 게이트**

```
□ work-order 발행 (Task 1)
□ 팀 체크리스트 현행화 (Task 2)
□ harness 베이스라인 PASSED + 기록 (Task 3)
```

---

## Day 2~3 (05-27~28) — 추적 + 리뷰 + 머지 + 구현분 E2E

### Task 4: work-order 추적 + PR 리뷰/머지 조율

**Files:**
- Modify: `docs/work-orders/W3_KAFKA_WORKORDER.md` (추적 테이블)

- [ ] **Step 1: 각 서비스 레포 PR 현황 조회**

Run:
```bash
bash -c 'for r in synapse-platform-svc synapse-knowledge-svc synapse-learning-svc synapse-engagement-svc; do echo "--- $r ---"; gh pr list --repo team-project-final/$r --state open --limit 10; done'
```
Expected: 각 레포 열린 PR 목록. (없으면 해당 owner 미착수 → 추적 테이블 ❌)

- [ ] **Step 2: PR 도착분 리뷰 (승인기준 기반)**

각 PR에 대해 `TEAM_CHECKLIST_W3.md` "코드 리뷰 승인 기준" 7항목 점검:
```bash
gh pr view <PR_NUMBER> --repo team-project-final/<repo> --comments
```
체크: Avro BACKWARD / CloudEvent 래핑 / Consumer Group(`{svc}-group`) / 멱등성(eventId) / 단위테스트 / application.yml Kafka 설정 / 에러 핸들링.
미흡 시 리뷰 코멘트로 피드백:
```bash
gh pr review <PR_NUMBER> --repo team-project-final/<repo> --comment --body "<피드백>"
```

- [ ] **Step 3: 승인 + 머지 조율 (Producer 먼저)**

리뷰 통과분을 순차 머지 — 순서: platform-svc → knowledge-svc → learning-card → learning-ai → engagement-svc (Producer 먼저, Consumer 나중):
```bash
gh pr review <PR_NUMBER> --repo team-project-final/<repo> --approve
gh pr merge <PR_NUMBER> --repo team-project-final/<repo> --squash
```

- [ ] **Step 4: 추적 테이블 갱신**

`docs/work-orders/W3_KAFKA_WORKORDER.md`의 "추적" 테이블을 실제 상태로 갱신 (PR 생성/리뷰/머지 컬럼을 ⏳/🔄/✅/❌로).

- [ ] **Step 5: 커밋**

```bash
git add docs/work-orders/W3_KAFKA_WORKORDER.md
git commit -m "docs: W3 work-order 추적 갱신 — PR 리뷰/머지 현황"
```

---

### Task 5: 구현분 로컬 E2E + 샘플 갭 보강

**Files:**
- Reference: `docs/guides/E2E_SCENARIOS_W3.md`, `src/test/resources/e2e-samples/`

- [ ] **Step 1: 머지된 서비스 로컬 재기동**

Run: `bash -c 'docker compose pull && docker compose up -d --build && docker compose ps'`
Expected: 머지된 서비스 코드가 반영된 컨테이너 기동.

> 로컬 이미지가 레포 코드를 빌드하는 구성이면 `--build`. ECR/ghcr pull 구성이면 머지 후 이미지 태그 갱신 필요(없으면 W2 코드로 기동됨 → 리포트에 명시).

- [ ] **Step 2: 시나리오별 E2E (구현 완료분)**

`E2E_SCENARIOS_W3.md`의 시나리오 중 **구현 머지된 서비스가 관여하는 것**만 실행. 예 — Scenario 4(회원가입→프로필, platform+engagement 머지 시):
```bash
curl -s -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e-day3@test.com","password":"Test1234!"}'
sleep 3
docker exec synapse-postgres psql -U synapse -c \
  "SELECT email FROM engagement.user_profiles WHERE email='e2e-day3@test.com'"
```
Expected: 프로필 레코드 존재(engagement consumer 동작). 미구현 서비스 시나리오는 "미구현"으로 결과 기록.
> 테이블/스키마명(`engagement.user_profiles`)은 engagement-svc 실제 스키마에 맞게 조정.

- [ ] **Step 3: 샘플 갭 확인 (필요 시만)**

Run: `bash -c 'ls src/test/resources/e2e-samples/ src/test/resources/e2e-samples/error/ src/test/resources/e2e-samples/multi-tenant/'`
Expected: 시나리오가 요구하는 샘플 존재. 누락분만 추가(기존 샘플 형식 따라). 없으면 이 스텝 스킵.

- [ ] **Step 4: (샘플 추가 시) 커밋**

```bash
git add src/test/resources/e2e-samples/
git commit -m "test: W3 E2E 시나리오 샘플 갭 보강"
```

---

## Day 4 (05-29) — 전체 E2E + 리포트 + 핸드오프

### Task 6: 전체 로컬 E2E (--full)

**Files:** (변경 없음 — 검증 작업, 결과는 Task 7 리포트에 반영)

- [ ] **Step 1: docker-compose 상태 확인**

Run: `bash -c 'docker compose ps'`
Expected: 핵심 서비스 Up. 아니면 `docker compose up -d`.

- [ ] **Step 2: 전체 모드 실행**

Run: `bash scripts/kafka-e2e-test.sh --full`
Expected: 정상 5건 + 에러/멀티테넌트 케이스 실행. PASS/FAIL/TIME 수치 확보(Task 7에 기입). 실패 시 원인 메모.

---

### Task 7: 리포트 채우기

**Files:**
- Modify: `docs/reports/E2E_REPORT_W3.md` (실제 결과)
- Modify: `docs/reports/DEPLOY_REPORT_W3.md` (실제 결과)

- [ ] **Step 1: E2E_REPORT_W3 채우기**

`docs/reports/E2E_REPORT_W3.md`의 결과 표를 실제 값으로 채운다. 각 시나리오 행을 `✅`(검증) / `❌`(실패) / `미구현`(서비스 Kafka 미머지) 중 하나로 표기. Task 6의 `--full` PASS/FAIL/TIME과 Task 5 시나리오 결과를 반영. EKS(클라우드) E2E 섹션은 **"W4 이월 — 클러스터 destroy"**로 표기.

- [ ] **Step 2: DEPLOY_REPORT_W3 채우기**

`docs/reports/DEPLOY_REPORT_W3.md`를 채운다:
- Dev/Staging 환경: "destroy 상태 — W4 재구축 후 검증" 표기 (gitops HANDOFF_W3 기준)
- Observability: gitops PR #47 라이브 검증분 ✅ + "클러스터 destroy로 현재 미가동" 병기
- 롤백/terraform: gitops 통합 플랜 참조로 위임
- 미해결 항목: staging 5/5, 클라우드 E2E, 잔여 팀 Kafka → W4 이월

- [ ] **Step 3: 커밋**

```bash
git add docs/reports/E2E_REPORT_W3.md docs/reports/DEPLOY_REPORT_W3.md
git commit -m "docs: W3 E2E/배포 리포트 — 로컬 결과 + 미구현/이월 정직 표기"
```

---

### Task 8: W3→W4 핸드오프 동기화

**Files:**
- Modify: `docs/project-management/HANDOFF_SHARED.md`
- Modify: `docs/project-management/HANDOFF_HUB.md`
- Modify: `docs/project-management/workflow/WORKFLOW_team-lead_W3.md`

- [ ] **Step 1: HANDOFF_SHARED 갱신**

`docs/project-management/HANDOFF_SHARED.md`:
- §5 팀원 체크리스트의 "서비스별 Kafka 구현 상태" 표를 Task 4 추적 결과로 갱신(🔴→✅ 또는 잔여 🔴).
- §6 아래에 W3 결과 블록 추가: 로컬 E2E harness 베이스라인 ✅, `--full` 결과, work-order 발행/추적, W4 이월(클라우드 E2E·staging 5/5·잔여 Kafka).
- 헤더 "최종 갱신"을 2026-05-29로.

- [ ] **Step 2: HANDOFF_HUB 갱신 (W3→W4 전환)**

`docs/project-management/HANDOFF_HUB.md`:
- 헤더: 최종 갱신 2026-05-29, 현재 주차 W4.
- §1 서비스 Kafka Producer/Consumer 행: 실제 머지 현황 반영.
- §2 교차 의존관계: 해소된 블로커 제거, W4 블로커(클라우드 E2E·staging 5/5·잔여 Kafka) 추가.
- §3 스포크 참조: HANDOFF_SHARED 최종 갱신일 2026-05-29.
- §4 다음 세션 작업 순서: W4 항목으로 교체(클러스터 재구축 → 클라우드 E2E → staging 5/5).
- §5 마일스톤: W3 상태 갱신(완료분 + 이월분 명시).

- [ ] **Step 3: WORKFLOW Step 7/8 현행화**

`docs/project-management/workflow/WORKFLOW_team-lead_W3.md`:
- Step 7: 완료 항목 `[x]`, 로컬 E2E·리뷰/머지·결과정리 반영. 미완료(클라우드 E2E 등)는 항목 옆에 "W4 이월" 명시.
- Step 8: gitops 위임 항목은 "gitops PR #47 통합 플랜에서 처리"로 주석, 클라우드 검증 미완은 "W4 이월".
- Step 7/8 Status: 완료분만 충족 시 `In Progress` 유지 + 하단에 W4 이월 사유. 전부 충족 시 `Done`.

- [ ] **Step 4: 정합성 점검 (SESSION_CLOSE_CHECKLIST 3문항)**

```
□ 허브 서비스/Kafka 상태가 실제(work-order 추적·로컬 E2E)와 같은가?
□ 허브의 "스포크 최종 갱신일"이 2026-05-29인가?
□ 허브의 "다음 세션 작업"에 오늘 완료한 항목이 남아있지 않은가?
```
하나라도 ❌이면 수정.

- [ ] **Step 5: 커밋 + 푸시**

```bash
git add docs/project-management/HANDOFF_HUB.md docs/project-management/HANDOFF_SHARED.md docs/project-management/workflow/WORKFLOW_team-lead_W3.md
git commit -m "docs: W3 close — 핸드오프 허브/스포크 W4 동기화 + WORKFLOW 현행화"
git push origin main
```

---

### Task 9: shared 로컬 셋업에 gitops local-k8s 포인터

**Files:**
- Modify: `README.md`

- [ ] **Step 1: README에 포인터 1줄 추가**

`README.md`의 로컬 실행/개발 안내 섹션에 아래 1줄 추가(적절한 위치):

```markdown
> 로컬 k8s(minikube)로 MSA를 띄우려면 synapse-gitops `local-k8s/` 참조 (compose 대신 k8s 배포 경로 검증용).
```

- [ ] **Step 2: 커밋**

```bash
git add README.md
git commit -m "docs: README에 gitops local-k8s(minikube) 포인터 추가"
```

- [ ] **Step 3: W3 종료 게이트 최종 확인**

```
□ work-order 발행 + 추적 완료
□ 로컬 harness 베이스라인 + --full 실행·기록
□ E2E/배포 리포트 실제 결과로 채움 (미구현/이월 정직 표기)
□ HANDOFF_HUB/SHARED 정합성 ✅ + W4 이월 명시
□ WORKFLOW Step 7/8 현행화
□ (선택) local-k8s 포인터 추가
```

---

## PRD/스펙 커버리지 체크

| 스펙 항목 | 태스크 |
|---|---|
| 결정 D1 shared 중심 | 전체 (gitops 트랙 제외) |
| 결정 D2 로컬 docker-compose E2E | Task 3, 5, 6 |
| 결정 D3 work-order 추적 | Task 1, 4 |
| 결정 D4 minikube gitops 잔류 + 포인터 | Task 9 |
| 산출물: work-order ×5 | Task 1 |
| 산출물: 팀 체크리스트 현행화 | Task 2 |
| 산출물: harness 베이스라인 | Task 3 |
| 산출물: 리포트 채움 | Task 7 |
| 산출물: 핸드오프 동기화 | Task 8 |
| DoD: W4 이월 명시 | Task 7, 8 |
| 리스크: 팀 PR 0건에도 가치 생성 | Task 1, 3, 7, 8 (PR 무관 산출물) |
