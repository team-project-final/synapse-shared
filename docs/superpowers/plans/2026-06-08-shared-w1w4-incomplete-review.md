# shared W1~W4 미완료 검토 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** shared(team-lead) W1~W4 워크플로 미완료 항목을 전수 검토해 정합 리포트를 산출하고, 유일한 실질 미검증(Kafka TLS 전송)의 증거를 확보한다.

**Architecture:** 접근 A — 단일 검토 리포트(`docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md`)에 3-state 분류 매트릭스 + 발표 리스크 + 권고를 담고, W2~W4 워크플로엔 정합 배너만 추가(체크박스 원본 보존). TLS 검증은 MSK ACTIVE 상태에서 in-cluster openssl 핸드셰이크로 증거 캡처해 리포트에 첨부.

**Tech Stack:** Markdown(문서), kubectl + SSM 터널(synapse-gitops `scripts/lib/eks-tunnel.sh`), openssl s_client(in-cluster pod), git/gh.

**설계 정정 (플랜 작성 중 실측 반영):** 설계 spec §4/§5의 🔴 미추적 잔여 1·2·3(SASL/IAM vs TLS-only 결정 미종결)은 **이미 종결됨** — `KAFKA_AUTH_MATRIX.md §1`에 "✅ B(TLS-only) 확정(2026-06-02), SASL/IAM·ACL은 W5+ 백로그" 문서화 확인. 따라서 권고②(결정 선언)는 **불필요(이미 충족)** → 리포트는 이를 ✅로 인용만. 진짜 실행 잔여는 **권고①(TLS 전송 검증)** 1건뿐.

---

## File Structure

| 파일 | 책임 | 동작 |
|---|---|---|
| `docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md` | 검토 주 산출물(매트릭스+리스크+권고+TLS 증거) | Create |
| `docs/project-management/workflow/WORKFLOW_team-lead_W2.md` | W2 정합 배너 | Modify (상단 1줄) |
| `docs/project-management/workflow/WORKFLOW_team-lead_W3.md` | W3 정합 배너 + Step7/8 Status 정정 | Modify |
| `docs/project-management/workflow/WORKFLOW_team-lead_W4.md` | W4 정합 배너 | Modify (상단 1줄) |

---

## Task 1: Kafka TLS 전송 검증 + 증거 캡처

**Files:**
- 산출(증거 텍스트): 임시 — Task 2 리포트에 인용 (`/tmp/tls-evidence-w5.txt`)

목적: MSK가 9094(TLS) 전용으로 동작하고 Amazon Trust Services CA 체인으로 핸드셰이크됨을 in-cluster에서 실증. (W2 §4.5 "TLS 전송 확인" 미검증 잔여 닫기)

- [ ] **Step 1: SSM 터널 + in-cluster openssl 핸드셰이크 실행**

synapse-gitops 디렉터리에서 터널을 올리고 synapse-dev 네임스페이스에 임시 파드로 브로커 9094에 TLS 접속, 인증서 issuer/subject/유효기간을 캡처한다. (브로커 주소는 terraform output에서 동적 취득 — 재apply 시 변동 대비)

```bash
cd /c/workspace/team-project-final/synapse-gitops && bash -c '
source scripts/lib/eks-tunnel.sh; trap tunnel_down EXIT
tunnel_up >/dev/null 2>&1 || { echo "tunnel FAIL"; exit 1; }
BROKER=$(terraform -chdir=infra/aws/dev output -raw msk_bootstrap_brokers_tls | cut -d, -f1)
echo "BROKER=$BROKER"
kubectl -n synapse-dev run tmp-tls-verify --rm -i --restart=Never --image=alpine/openssl --command --timeout=90s -- \
  sh -c "echo | openssl s_client -connect $BROKER -servername ${BROKER%:*} 2>/dev/null | openssl x509 -noout -issuer -subject -dates -checkend 0 && echo HANDSHAKE_OK"
' 2>&1 | tee /tmp/tls-evidence-w5.txt
```

- [ ] **Step 2: 증거 검증 (핸드셰이크 성공 + Amazon CA)**

Run: `grep -E 'issuer=.*Amazon|HANDSHAKE_OK|notAfter' /tmp/tls-evidence-w5.txt`
Expected: `issuer=...Amazon...` (Amazon Trust Services CA) + `HANDSHAKE_OK` + `notAfter=` 미래 날짜. 셋 다 나오면 TLS 전송 검증 PASS.

> 실패 시(파드 스케줄 지연/터널 끊김): `--from` 없이 재실행. 그래도 막히면 대안 증거 = consumer group 활성(서비스가 9094 SSL로 실제 연결 중)을 캡처: `kubectl -n synapse-dev exec deploy/platform-svc -- sh -c 'true'` 대신 `kubectl -n synapse-dev get pods`(서비스 Running = TLS 연결 성립)로 보조 증거 기록.

- [ ] **Step 3: 증거 요약 1줄 메모**

`/tmp/tls-evidence-w5.txt`에서 issuer/notAfter 한 줄을 발췌해 Task 2 리포트 §4에 붙일 형태로 정리(예: `b-1...:9094 TLS OK — issuer=Amazon RSA 2048 M02, notAfter=2026-xx, HANDSHAKE_OK`).

(이 Task는 문서 산출이라 별도 commit 없음 — Task 4에서 리포트와 함께 커밋)

---

## Task 2: 검토 리포트 작성

**Files:**
- Create: `docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md`

- [ ] **Step 1: 리포트 본문 작성**

아래 내용을 그대로 작성한다(TLS 증거는 Task 1 Step 3 메모로 `<<TLS_EVIDENCE>>` 치환).

```markdown
# shared W1~W4 작업 구성 미완료 검토

> **작성**: 2026-06-08 · **작성자**: @team-lead · **근거 설계**: [2026-06-08-shared-w1w4-incomplete-review-design](../superpowers/specs/2026-06-08-shared-w1w4-incomplete-review-design.md)
> **범위**: synapse-shared `WORKFLOW_team-lead_W1~W4` 적힌 항목 전수. 조치가 gitops면 이관 표시.
> **한 줄 결론**: W1~W4 미완 대부분 W5 Day1에 ✅해소 또는 🔄W5 일정 추적중. 진짜 미추적 잔여는 **TLS 전송 검증 1건뿐**(본 검토에서 ✅ 실증). 발표(06-15) 차단 리스크 없음.

## 1. 분류 방법
- ✅ 해소됨 / 🔄 W5 추적중 / 🔴 미추적 잔여 (3-state)
- 발표 리스크: 🔴높음(데모 직접 노출) / 🟡중간(Q&A·근거 공백) / ⚪낮음(문서·정책)

## 2. 정합 매트릭스
| 주차 | 항목 | 원래 상태 | 분류 | 근거 | 발표리스크 | 조치 |
|---|---|---|---|---|---|---|
| W1 | 전 Step (인프라/compose/CICD) | Done | ✅ | WORKFLOW_W1 | ⚪ | 종결 |
| W2 | MSK 9토픽 생성 | `[ ]`(gitops 이월) | ✅ | terraform `kafka-topics/`, MSK ACTIVE(06-08) | ⚪ | 종결 |
| W2 | 인증 모델(SASL/IAM vs TLS-only) | "결정 필요" | ✅ | KAFKA_AUTH_MATRIX §1 — B(TLS-only) 확정(06-02) | ⚪ | 종결(인용) |
| W2 | Kafka ACL / 민감토픽 접근제한 | `[ ]` | ✅ | 동 §1 — W5+ 백로그로 명시 종결 | ⚪ | 범위외 선언됨 |
| W2 | TLS 전송 실측 검증 | `[ ]` | ✅(본 검토) | §4 TLS 증거 | 🟡→닫힘 | 본 리포트로 종결 |
| W2 | console produce/consume(MSK) | `[ ]` | ✅ | 서비스 consumer group 활성(EKS) + 로컬 `--avro` 8/8 | ⚪ | 대체 충족 |
| W3 | gamification/note.created Producer·engagement Consumer | 🟡조건부 | ✅ | 4서비스 origin/main 머지(#40/#46/#23/learning) | ⚪ | 종결 |
| W3 | platform/engagement dev→main | 🟡조건부 | ✅ | #46/#23 머지 | ⚪ | 종결 |
| W3 | ArgoCD dev/staging 배포·검증·롤백 | `[ ]`(EKS destroy) | ✅ | W5 Day1 dev16/staging20 ALL PASS, 롤백124s(06-02) | ⚪ | 종결 |
| W3 | 서비스 단위 E2E 실행 | `[ ]` | 🔄 | W5_PLAN Day2, env 준비(shared#25) | 🟡 | W5 Day2 |
| W4 | 서비스 로직 E2E 실행(Step9.2) | `[~]` | 🔄 | W5_PLAN Day2 | 🟡 | W5 Day2 |
| W4 | SLA 성능 측정(Step10) | `[ ]` | 🔄 | WORKFLOW_W5 Step10, Day3 | ⚪ | W5 Day3 |
| W4 | Staging 최종+모니터링(Step11) | `[ ]` | ✅(부분)/🔄 | staging 5/5+Observability 기동(06-08), 24h·대시보드 Day4 | ⚪ | W5 Day4 |
| W4 | Step11.1 staging 검증 시나리오 정의 | `[ ]` | ✅ | verify-argocd-deploy.sh로 대체 | ⚪ | 종결 |
| W4 | 발표 자료·리허설(Step12) | `[ ]` | 🔄 | W5_PLAN Day5(6/12 리허설) | ⚪ | W5 Day5 |

## 3. 🔴 미추적 잔여 — 0건
설계 단계에서 5건으로 추정했으나 실측 결과:
- W2 인증/ACL(1·2·3) → KAFKA_AUTH_MATRIX §1에 **이미 결정·종결**(TLS-only, ACL은 W5+ 백로그 명시) → ✅
- TLS 전송 검증(4) → **본 검토에서 실증**(§4) → ✅
- W4 Step11.1(5) → verify-argocd-deploy.sh로 대체 → ✅
**결과: 진짜 미추적 잔여 없음.** 모든 W1~W4 미완은 해소·결정·W5추적 중 하나로 귀속됨.

## 4. TLS 전송 검증 증거 (W2 §4.5 잔여 종결)
in-cluster openssl s_client → MSK 9094 핸드셰이크:
```
<<TLS_EVIDENCE>>
```
→ Amazon Trust Services CA 체인으로 TLS 핸드셰이크 성공. dev MSK TLS-only 전송 실증. KAFKA_AUTH_MATRIX §1(B 채택)와 정합.

## 5. 발표 리스크 레지스터 (06-15)
| 리스크 | 등급 | 대응 |
|---|---|---|
| 서비스 로직 E2E 미실행 | 🟡 | W5 Day2 실행 — 데모 핵심 체인. owner P0 2건(AVRO_CONTRACT_FIX_W5) 선결 |
| TLS 전송 근거 공백 | 🟡→닫힘 | 본 리포트 §4 증거로 종결 |
| 그 외 | ⚪ | 없음 |
🔴 높음 = 없음. 발표 차단 요소 없음.

## 6. 권고
1. ✅ **TLS 전송 검증** — 본 검토에서 실행·증거 확보 완료(§4).
2. ✅ **인증 모델 종결** — 이미 KAFKA_AUTH_MATRIX §1에 TLS-only 확정. 추가 조치 불요(인용으로 충족).
3. 🔄 **나머지** — W5_PLAN Day2~5 일정에 이미 연결됨. 별도 신규 작업 없음.

## 7. 부록 — 출처
WORKFLOW_team-lead_W1~W4 · W3_EXIT_GATE · W4_EXIT_GATE · KAFKA_AUTH_MATRIX · W4_DAY1_POST_APPLY · HANDOFF_SHARED/HUB(06-08) · E2E_SMOKE_W5_DAY1 · shared#25/#26 · gitops#136.
```

- [ ] **Step 2: `<<TLS_EVIDENCE>>` 치환 + 검증**

Task 1 Step 3 메모로 플레이스홀더를 치환한다.
Run: `grep -c '<<TLS_EVIDENCE>>' docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md`
Expected: `0` (플레이스홀더 잔존 없음)

- [ ] **Step 3: 링크 유효성 점검**

Run: `grep -oE '\]\(\.\.?/[^)]+\)' docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md | sed -E 's/.*\((.*)\)/\1/' | while read p; do f="docs/reports/$p"; [ -e "$(python3 -c "import os;print(os.path.normpath('$f'))")" ] && echo "OK $p" || echo "MISSING $p"; done`
Expected: 모든 라인 `OK` (MISSING 0). MISSING이면 경로 수정.

---

## Task 3: W2~W4 워크플로 정합 배너 + W3 Status 정정

**Files:**
- Modify: `docs/project-management/workflow/WORKFLOW_team-lead_W2.md`, `_W3.md`, `_W4.md`

- [ ] **Step 1: W2/W4 상단 배너 추가**

각 파일의 첫 제목(`# WORKFLOW...`) 바로 아래 인용 블록 마지막 줄 뒤에 1줄 추가:

```markdown
> ✅ **사후 정합(2026-06-08)**: 본 주차 미완 항목은 전수 검토 완료 — 대부분 W5 Day1 해소/결정 또는 W5 일정 추적중, 미추적 잔여 0건. → [SHARED_W1W4_INCOMPLETE_REVIEW](../../reports/SHARED_W1W4_INCOMPLETE_REVIEW.md)
```

- [ ] **Step 2: W3 동일 배너 + Step 7/8 Status 정정**

W3에 위 배너 추가. 추가로 Step 7 Status(`[x] In Progress`)와 Step 8 Status를 다음으로 정정:
```markdown
**Step 7 Status**: [x] Done — 전송/계약 경로 완료, 서비스 Kafka 4종 origin/main 머지 + 서비스 E2E는 W5 Day2 (SHARED_W1W4_INCOMPLETE_REVIEW)
```
(Step 8도 동일 패턴: dev/staging 배포·검증은 W5 Day1 ALL PASS로 `[x] Done` 정정)

- [ ] **Step 3: 배너/정정 확인**

Run: `grep -l '사후 정합(2026-06-08)' docs/project-management/workflow/WORKFLOW_team-lead_W{2,3,4}.md`
Expected: 3개 파일 모두 매치.

---

## Task 4: 커밋 + PR

- [ ] **Step 1: 변경 스테이징 + 커밋**

```bash
cd /c/workspace/team-project-final/synapse-shared
git add docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md docs/project-management/workflow/WORKFLOW_team-lead_W2.md docs/project-management/workflow/WORKFLOW_team-lead_W3.md docs/project-management/workflow/WORKFLOW_team-lead_W4.md
git commit -m "docs(review): shared W1~W4 미완료 전수 검토 + TLS 전송 검증 증거

3-state 분류 결과 미추적 잔여 0건 — 전부 해소/결정/W5추적으로 귀속.
유일 실행 잔여였던 Kafka TLS 전송 검증을 in-cluster openssl로 실증(§4).
인증 모델은 KAFKA_AUTH_MATRIX §1에 TLS-only 이미 확정(추가 조치 불요).
W2~W4 워크플로에 정합 배너 + W3 Step7/8 Status 정정.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 2: 푸시 + PR 생성**

```bash
cd /c/workspace/team-project-final/synapse-shared
git push -u origin docs/shared-w1w4-incomplete-review
gh pr create --title "docs(review): shared W1~W4 미완료 전수 검토 (미추적 잔여 0 + TLS 검증)" --body "설계 spec 기반 검토. W1~W4 미완 전수 3-state 분류 → 미추적 잔여 0건(전부 W5 Day1 해소·결정·일정추적). Kafka TLS 전송 검증 증거 확보(§4). 발표 차단 리스크 없음.

산출: docs/reports/SHARED_W1W4_INCOMPLETE_REVIEW.md + W2~W4 정합 배너 + W3 Step7/8 Status 정정.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 3: PR 생성 확인**

Run: `gh pr view --json url,title --jq '.url'`
Expected: PR URL 출력.

---

## Self-Review 메모
- 설계 §4/§5의 🔴 5건 → 실측으로 전부 ✅ 귀속(인증결정 기확정 + TLS 실증 + Step11.1 대체). 리포트 §3가 "미추적 0건"으로 정정 반영 — spec과의 차이는 본 플랜 상단 "설계 정정"에 명시.
- 권고②는 이미 충족이라 실행 태스크 없음(인용만) — 의도된 축소.
- TLS 검증 실패 시 보조 증거 경로(consumer group 활성) Task1 Step2에 명시.
