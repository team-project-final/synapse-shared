# API 문서 Survey + gateway 대조 + 누락 이슈 발행 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 각 서비스의 OpenAPI 노출 현황을 실측하고 gateway 라우팅과 대조한 표를 산출한 뒤, SpringDoc/OpenAPI 누락 서비스마다 각 레포에 *대단히 상세한* 보완 이슈를 발행한다 (FR-TL-304). 서비스 코드는 직접 수정하지 않는다(머지 경계 준수).

**Architecture:** e2e 스택이 기동된 상태에서 survey 스크립트가 각 서비스의 OpenAPI 엔드포인트를 직접(서비스 포트) + gateway 경유로 호출해 노출 여부를 판정한다. gateway 라우트 정의(synapse-gateway 레포)와 대조해 표를 만든다. 누락 항목은 `gh issue create`로 레포별 이슈를 발행한다.

**Tech Stack:** PowerShell 7+(survey 스크립트), docker compose(e2e 스택), `gh` CLI(이슈 발행), curl.

---

## 사전 사실 (e2e compose 실측)

| 서비스 | 타입 | 컨테이너 내부 포트 | OpenAPI 관례 | 레포(이슈 대상) |
|---|---|---|---|---|
| platform-svc | Spring | 8081 | `/v3/api-docs`, `/swagger-ui/index.html` | `team-project-final/synapse-platform-svc` |
| knowledge-svc | Spring | 8082 | `/v3/api-docs`, `/swagger-ui/index.html` | `team-project-final/synapse-knowledge-svc` |
| engagement-svc | Spring | 8083 | `/v3/api-docs`, `/swagger-ui/index.html` | `team-project-final/synapse-engagement-svc` |
| learning-card-svc | Spring | 8084 | `/v3/api-docs`, `/swagger-ui/index.html` | `team-project-final/synapse-learning-svc` (하위 `learning-card/`) |
| learning-ai-svc | FastAPI | 8090 | `/openapi.json`, `/docs` | `team-project-final/synapse-learning-svc` (하위 `learning-ai/`) |
| gateway | Spring Cloud Gateway | 8080 | 라우팅만(자체 OpenAPI 선택) | `team-project-final/synapse-gateway` |

> ⚠️ host 포트는 다른 compose와 충돌 가능 → **하드코딩하지 말고 `docker compose ps`로 실제 published 포트를 조회**한다(Task 1 Step 2).
> ⚠️ gateway는 learning-ai(8090)를 라우팅하지 않음(knowledge가 `SEARCH_AI_BASE_URL`로 직접 호출) — 대조 시 명시.
> ⚠️ A(D-004 Stage1) 머지 후 진행이므로, engagement worktree를 origin/main으로 새로고침한 뒤 재빌드해야 survey가 최신 엔드포인트를 반영한다(Task 1 Step 1).

---

## File Structure

- **Create:** `scripts/api-doc-survey.ps1` — 서비스별 OpenAPI 엔드포인트 직접/gateway 경유 프로브 → 구조화 결과(JSON+콘솔). 단일 책임: "OpenAPI 노출 실측".
- **Create:** `docs/reports/API_DOC_SURVEY_W5_DAY3.md` — survey 결과 + gateway 대조표 + 발행 이슈 URL 표.
- **Create (임시):** `docs/fix-requests/openapi/<service>.md` — 각 이슈 본문(상세) 소스. 이슈 본문 파일로 사용 후 레포 참조용으로 보관.

---

## Task 1: e2e 스택 기동 + survey 스크립트

**Files:**
- Create: `scripts/api-doc-survey.ps1`

- [ ] **Step 1: engagement worktree 새로고침 + e2e 스택 기동**

Run (engagement worktree를 A 머지 후 origin/main으로 갱신):
```bash
git -C ../.e2e-worktrees/synapse-engagement-svc fetch origin
git -C ../.e2e-worktrees/synapse-engagement-svc checkout origin/main --detach
docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --build
```
Then wait for health:
```bash
docker compose -f docker-compose.yml -f docker-compose.e2e.yml ps
```
Expected: platform/engagement/knowledge/learning-card/learning-ai/gateway 가 `healthy`. 미healthy면 `down -v` 후 재기동(stale 볼륨).

- [ ] **Step 2: published 포트 조회 (하드코딩 회피)**

Run:
```bash
docker compose -f docker-compose.yml -f docker-compose.e2e.yml ps --format '{{.Service}} {{.Publishers}}'
```
Expected: 각 서비스의 `0.0.0.0:<hostPort>->`<containerPort>`/tcp` 매핑 출력. 이 host 포트를 다음 스텝 스크립트의 기본 매핑에 반영(또는 컨테이너 내부 포트와 동일하면 그대로 사용).

- [ ] **Step 3: survey 스크립트 작성**

```powershell
#requires -Version 7
<#
.SYNOPSIS
  각 서비스 OpenAPI 노출 현황을 직접 포트 + gateway 경유로 실측 (FR-TL-304).
#>
param(
    [string]$GatewayBase = "http://localhost:8080",
    [string]$JsonOut = "docs/reports/api-doc-survey.json"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Service → 직접 base URL + OpenAPI 경로 + gateway route prefix(없으면 $null)
$Targets = @(
    [pscustomobject]@{ Name="platform-svc";     Direct="http://localhost:8081"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/platform" }
    [pscustomobject]@{ Name="knowledge-svc";    Direct="http://localhost:8082"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/knowledge" }
    [pscustomobject]@{ Name="engagement-svc";   Direct="http://localhost:8083"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/engagement" }
    [pscustomobject]@{ Name="learning-card-svc";Direct="http://localhost:8084"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/learning" }
    [pscustomobject]@{ Name="learning-ai-svc";  Direct="http://localhost:8090"; Doc="/openapi.json"; Ui="/docs"; GwPrefix=$null }
)

function Get-HttpStatus {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri $Url -Method Get -SkipHttpErrorCheck -TimeoutSec 8
        return [int]$r.StatusCode
    } catch { return -1 }
}

$results = foreach ($t in $Targets) {
    $directDoc = Get-HttpStatus "$($t.Direct)$($t.Doc)"
    $directUi  = Get-HttpStatus "$($t.Direct)$($t.Ui)"
    $gwDoc = if ($t.GwPrefix) { Get-HttpStatus "$GatewayBase$($t.GwPrefix)$($t.Doc)" } else { "N/A(미라우팅)" }
    $exposed = ($directDoc -eq 200)
    [pscustomobject]@{
        Service = $t.Name
        DocPath = $t.Doc
        DirectDoc = $directDoc
        DirectUi = $directUi
        GatewayDoc = $gwDoc
        Exposed = if ($exposed) { "O" } else { "X" }
    }
}

$results | Format-Table -AutoSize | Out-Host
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonOut -Encoding utf8
Write-Host "survey JSON → $JsonOut"
```

- [ ] **Step 4: survey 실행**

Run: `pwsh -File scripts/api-doc-survey.ps1`
Expected: 5행 표(서비스별 DirectDoc/DirectUi/GatewayDoc/Exposed) + `survey JSON → docs/reports/api-doc-survey.json`. DirectDoc=200 이면 노출 O, 404/−1 이면 X(보완 대상).

- [ ] **Step 5: 커밋**

```bash
git add scripts/api-doc-survey.ps1 docs/reports/api-doc-survey.json
git commit -F - <<'EOF'
feat(docs): API OpenAPI 노출 survey 스크립트 + 실측 결과 (FR-TL-304)

5서비스 직접/gateway 경유 OpenAPI 프로브. learning-ai=FastAPI /openapi.json.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## Task 2: gateway 라우팅 대조 + 대조표 리포트

**Files:**
- Read: synapse-gateway 라우트 설정(`../.e2e-worktrees/synapse-gateway/src/main/resources/application*.yml` 또는 `../synapse-gateway/...`)
- Create: `docs/reports/API_DOC_SURVEY_W5_DAY3.md`

- [ ] **Step 1: gateway 라우트 정의 추출**

Run (라우트 predicate·uri 확인):
```bash
grep -rn -A4 "routes:" ../.e2e-worktrees/synapse-gateway/src/main/resources/ 2>/dev/null || \
grep -rn -A4 "routes:" ../synapse-gateway/src/main/resources/
```
Expected: `spring.cloud.gateway.routes` 항목들 — 각 `id`, `uri: ${..._SVC_URI}`, `predicates: Path=/api/<svc>/**`. 이 경로 prefix를 survey의 GwPrefix와 대조.

- [ ] **Step 2: 대조표 리포트 작성**

`docs/reports/API_DOC_SURVEY_W5_DAY3.md` 생성:
```markdown
# API 문서 Survey + gateway 라우팅 대조 — W5 Day3

> 생성: `scripts/api-doc-survey.ps1` 실측 + gateway 라우트 대조 · FR-TL-304
> e2e 스택(origin/main, engagement는 D-004 Stage1 머지 후) 기준

## 1. OpenAPI 노출 실측

| 서비스 | 타입 | Doc 경로 | 직접 Doc | 직접 UI | gateway 경유 Doc | 노출 | 비고 |
|---|---|---|---|---|---|---|---|
| platform-svc | Spring | /v3/api-docs | <DirectDoc> | <DirectUi> | <GatewayDoc> | <O/X> | |
| knowledge-svc | Spring | /v3/api-docs | … | … | … | … | |
| engagement-svc | Spring | /v3/api-docs | … | … | … | … | D-004 Stage1 변경 반영 |
| learning-card-svc | Spring | /v3/api-docs | … | … | … | … | |
| learning-ai-svc | FastAPI | /openapi.json | … | … | N/A(미라우팅) | … | gateway 라우트 없음 |

## 2. gateway 라우팅 대조

| gateway route id | predicate(Path) | uri | 대상 서비스 | OpenAPI 노출 일치 |
|---|---|---|---|---|
| <id> | /api/platform/** | ${PLATFORM_SVC_URI} | platform-svc | <O/X> |
| … | | | | |

> learning-ai는 gateway 라우트 부재 — 외부 노출은 knowledge 경유(SEARCH_AI_BASE_URL) 내부 호출만. (정책 결정: gateway 라우트 추가 여부는 별도)

## 3. 누락 판정 → 발행 이슈

| 서비스 | 누락 내용 | 발행 이슈 |
|---|---|---|
| <svc> | SpringDoc 미노출(404) | <issue URL> |
```
실측값(`docs/reports/api-doc-survey.json`)으로 `<…>` 채움. 노출 X인 서비스가 §3 발행 대상.

- [ ] **Step 3: 커밋**

```bash
git add docs/reports/API_DOC_SURVEY_W5_DAY3.md
git commit -F - <<'EOF'
docs(api): OpenAPI 노출 + gateway 라우팅 대조표 (FR-TL-304)

5서비스 실측 + gateway route 대조. learning-ai 미라우팅 명시.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## Task 3: 누락 서비스 상세 이슈 발행

> 노출 O(이미 SpringDoc 노출)인 서비스는 이슈 발행하지 않는다. 노출 X 서비스마다 1건 발행.

**Files:**
- Create: `docs/fix-requests/openapi/<service>.md` (이슈 본문 소스, 서비스마다)

- [ ] **Step 1: 이슈 본문 작성 (노출 X 서비스마다 1파일)**

`docs/fix-requests/openapi/<service>.md` 작성. **Spring 서비스 템플릿**(예: engagement-svc):
```markdown
## 배경 / 근거
W5 FR-TL-304 API 문서 최신화. shared의 OpenAPI survey(2026-06-10)에서 본 서비스의
SpringDoc 미노출 확인.
- 증거: `GET http://localhost:8083/v3/api-docs` → <status> (기대 200)
- gateway 경유: `GET http://localhost:8080/api/engagement/v3/api-docs` → <status>
- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`

## 현재 상태
- [ ] `springdoc-openapi-starter-webmvc-ui` 의존성 부재 / 버전 미일치 (택1, 실태 기입)
- [ ] `/v3/api-docs` 200 미응답
- [ ] Swagger UI(`/swagger-ui/index.html`) 미렌더
- [ ] gateway 라우트로 doc 경로 미통과(필요 시)

## 정확한 변경 지점
1. `build.gradle(.kts)` 의존성 추가:
   `implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.6.0")`
   (Spring Boot 3.x 기준; 정상 노출 중인 타 서비스 버전과 일치시킬 것)
2. (선택) `application.yml`:
   ```yaml
   springdoc:
     api-docs.path: /v3/api-docs
     swagger-ui.path: /swagger-ui/index.html
   ```
3. 주요 컨트롤러에 `@Tag`/`@Operation` 부여(최소 1개 도메인 컨트롤러부터):
   - 본 서비스 REST 컨트롤러(예: `GamificationController`, 신고 컨트롤러 등)
4. 인증 필터/SecurityConfig에서 `/v3/api-docs/**`, `/swagger-ui/**` permitAll 확인.

## 검증 (DoD)
- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/v3/api-docs` → `200`
- [ ] gateway 경유 `.../api/engagement/v3/api-docs` → `200`
- [ ] `/swagger-ui/index.html` 브라우저 렌더 + 주요 엔드포인트 N개 노출
- [ ] 정상 노출 중인 타 서비스와 동일한 응답 구조

## 참조
- 대조표: synapse-shared `docs/reports/API_DOC_SURVEY_W5_DAY3.md`
- 세션 스펙: synapse-shared `docs/superpowers/specs/2026-06-10-w5-day3-d004stage1-schema-apidocs-design.md`
- 정상 예시: 노출 O 서비스(survey 표 참조)
```

**FastAPI(learning-ai) 템플릿 차이**(노출 X일 때만):
- 의존성/어노테이션 대신 `app.main`의 `FastAPI(docs_url=..., openapi_url=...)` 설정·라우터 등록 점검
- DoD: `GET http://localhost:8090/openapi.json` → 200, `/docs` 렌더
- 레포: `synapse-learning-svc` (하위 `learning-ai/`) — 이슈 제목에 `[learning-ai]` 명시

- [ ] **Step 2: 이슈 발행 (`gh issue create`)**

노출 X 서비스마다:
```bash
gh issue create \
  -R team-project-final/synapse-engagement-svc \
  --title "docs(openapi): SpringDoc 노출 보완 — engagement-svc (W5 FR-TL-304)" \
  --body-file docs/fix-requests/openapi/engagement-svc.md
```
- learning-card / learning-ai 는 동일 레포 `synapse-learning-svc`로 발행하되 제목에 `[learning-card]`/`[learning-ai]` + 본문에 하위 디렉터리 명시.
- 출력된 이슈 URL을 기록.
Expected: 각 명령이 `https://github.com/team-project-final/synapse-<svc>/issues/<n>` 출력.

- [ ] **Step 3: 대조표 §3 + 이슈 URL 반영 + 커밋**

`docs/reports/API_DOC_SURVEY_W5_DAY3.md` §3 표에 서비스별 이슈 URL 기입 후:
```bash
git add docs/reports/API_DOC_SURVEY_W5_DAY3.md docs/fix-requests/openapi/
git commit -F - <<'EOF'
docs(api): OpenAPI 누락 서비스 상세 이슈 발행 + URL 반영 (FR-TL-304)

노출 X 서비스별 보완 이슈(변경지점·DoD 상세) 발행, 대조표 §3 갱신.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## Task 4: 추적 갱신

**Files:**
- Modify: `docs/project-management/workflow/WORKFLOW_team-lead_W5.md`

- [ ] **Step 1: 워크플로 갱신**

라인:
```
- [ ] FR-TL-304 API 문서 최신화 (SpringDoc + gateway 라우팅 대조)
```
를:
```
- [x] FR-TL-304 API 문서 최신화 — 5서비스 OpenAPI survey + gateway 대조([API_DOC_SURVEY_W5_DAY3](../../reports/API_DOC_SURVEY_W5_DAY3.md)), 누락 서비스 레포 상세 이슈 발행
```
(누락 0이면 "전 서비스 노출 O — 보완 이슈 불요"로 기입)

- [ ] **Step 2: 커밋**

```bash
git add docs/project-management/workflow/WORKFLOW_team-lead_W5.md
git commit -F - <<'EOF'
docs(workflow): FR-TL-304 API 문서 survey+대조+이슈 완료 반영

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## 완료 기준 (이 플랜)

- `scripts/api-doc-survey.ps1` 실행 → 5서비스 노출 실측 JSON 산출.
- `docs/reports/API_DOC_SURVEY_W5_DAY3.md` — 노출 표 + gateway 대조표 + 이슈 URL 표 커밋.
- 노출 X 서비스마다 해당 레포 상세 이슈 발행(변경지점·DoD 포함) — 코드 직접 수정 없음.
- `WORKFLOW_team-lead_W5.md` FR-TL-304 `[x]`.
- 누락 0이면 이슈 없이 "전 서비스 노출 O" 기록.
