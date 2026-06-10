# Schema BACKWARD 전토픽 전수 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 9개 이벤트 subject 전수에 대해 Schema Registry BACKWARD 호환성을 강제 프로브(호환 accept·비호환 reject)로 입증하고 리포트를 산출한다 (FR-TL-302, 미발행 토픽 cards-generated 포함).

**Architecture:** 기존 단일-subject 스크립트(`register-schema.ps1`·`check-schema-compatibility.ps1`)를 재사용하고, 그 위에 subject↔avsc 매니페스트를 순회하는 **전수 러너**(`scripts/check-schema-backward-all.ps1`)를 신규 추가한다. 프로브 변형은 정본 avsc를 프로그램적으로 변형해 생성(호환=optional union+default 필드 추가 / 비호환=required no-default 필드 추가). 순수 변형 로직은 `-SelfTest`로 레지스트리 없이 검증한다.

**Tech Stack:** PowerShell 7+, Confluent Schema Registry(`docker-compose.schema-registry.yml`, localhost:8081), 기존 `scripts/*.ps1`.

---

## 배경: Avro BACKWARD 시맨틱 (실측 정정)

`src/test/resources/schema-samples/`의 실제 샘플로 확인:
- **호환 변형** = optional union 필드 + default 추가. 예: `note-created-v2-compatible.avsc`가 `{"name":"summary","type":["null","string"],"default":null}` 추가 → BACKWARD 호환.
- **비호환 변형** = required 필드를 default 없이 추가. 예: `note-created-v2-incompatible.avsc`가 `{"name":"category","type":"string"}`(default 없음) 추가 → BACKWARD 비호환.
- ⚠️ **필드 제거는 BACKWARD 호환**(스펙 초안의 "required 필드 제거=비호환"은 오류 — 본 플랜이 정정한 정의를 사용).

## Subject ↔ avsc 매니페스트 (9종, TopicNameStrategy `<topic>-value`)

| # | Topic | avsc |
|---|---|---|
| 1 | `platform.auth.user-registered-v1` | `src/main/avro/platform/UserRegistered.avsc` |
| 2 | `knowledge.note.note-created-v1` | `src/main/avro/knowledge/NoteCreated.avsc` |
| 3 | `knowledge.note.note-updated-v1` | `src/main/avro/knowledge/NoteUpdated.avsc` |
| 4 | `learning.card.review-completed-v1` | `src/main/avro/learning/ReviewCompleted.avsc` |
| 5 | `learning.card.review-due-v1` | `src/main/avro/learning/CardReviewDue.avsc` |
| 6 | `engagement.gamification.level-up-v1` | `src/main/avro/engagement/LevelUp.avsc` |
| 7 | `engagement.gamification.badge-earned-v1` | `src/main/avro/engagement/BadgeEarned.avsc` |
| 8 | `platform.notification.notification-send-v1` | `src/main/avro/platform/NotificationSend.avsc` |
| 9 | `learning.ai.cards-generated-v1` | `src/main/avro/learning/CardsGenerated.avsc` ← 기존 `--avro` 누락분 |

---

## File Structure

- **Create:** `scripts/check-schema-backward-all.ps1` — 전수 러너(매니페스트 순회 + 변형 생성 + 단일검사기 호출 + 리포트). 단일 책임: "전 subject BACKWARD 전수 오케스트레이션".
- **Create:** `docs/reports/SCHEMA_BACKWARD_W5_DAY3.md` — 산출 리포트(러너가 생성/덮어씀).
- **Reuse (no change):** `scripts/register-schema.ps1`, `scripts/check-schema-compatibility.ps1`.

---

## Task 1: 전수 러너 스캐폴드 + 매니페스트 + SelfTest 변형 로직

**Files:**
- Create: `scripts/check-schema-backward-all.ps1`

- [ ] **Step 1: 러너 스캐폴드 작성 (param·매니페스트·변형 함수·SelfTest 분기)**

```powershell
#requires -Version 7
<#
.SYNOPSIS
  9개 이벤트 subject 전수 BACKWARD 호환성 강제 프로브 러너 (FR-TL-302).
.DESCRIPTION
  각 subject: ① 정본 avsc 등록(register-schema.ps1) ② compat 레벨 단언
  ③ 호환 변형 프로브(ExpectCompatible=$true) ④ 비호환 변형 프로브(ExpectCompatible=$false).
  -SelfTest 는 레지스트리 없이 순수 변형 로직만 검증.
#>
param(
    [string]$RegistryUrl = "http://localhost:8081",
    [string[]]$AllowedCompatibility = @("BACKWARD", "BACKWARD_TRANSITIVE"),
    [string]$RegisterCompatibility = "BACKWARD",
    [string]$ReportPath = "docs/reports/SCHEMA_BACKWARD_W5_DAY3.md",
    [string]$Username,
    [string]$Password,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$RepoRoot  = Split-Path -Parent $ScriptDir

$Manifest = @(
    [pscustomobject]@{ Topic = "platform.auth.user-registered-v1";        Avsc = "src/main/avro/platform/UserRegistered.avsc" }
    [pscustomobject]@{ Topic = "knowledge.note.note-created-v1";           Avsc = "src/main/avro/knowledge/NoteCreated.avsc" }
    [pscustomobject]@{ Topic = "knowledge.note.note-updated-v1";           Avsc = "src/main/avro/knowledge/NoteUpdated.avsc" }
    [pscustomobject]@{ Topic = "learning.card.review-completed-v1";        Avsc = "src/main/avro/learning/ReviewCompleted.avsc" }
    [pscustomobject]@{ Topic = "learning.card.review-due-v1";              Avsc = "src/main/avro/learning/CardReviewDue.avsc" }
    [pscustomobject]@{ Topic = "engagement.gamification.level-up-v1";      Avsc = "src/main/avro/engagement/LevelUp.avsc" }
    [pscustomobject]@{ Topic = "engagement.gamification.badge-earned-v1";  Avsc = "src/main/avro/engagement/BadgeEarned.avsc" }
    [pscustomobject]@{ Topic = "platform.notification.notification-send-v1"; Avsc = "src/main/avro/platform/NotificationSend.avsc" }
    [pscustomobject]@{ Topic = "learning.ai.cards-generated-v1";           Avsc = "src/main/avro/learning/CardsGenerated.avsc" }
)

# 정본 avsc(JSON record)에 호환 변형(optional union + default) 필드를 추가해 반환.
function New-CompatibleSchemaJson {
    param([Parameter(Mandatory)][string]$AvscPath)
    $schema = Get-Content -LiteralPath $AvscPath -Raw | ConvertFrom-Json -Depth 30
    $field = [pscustomobject]@{ name = "probeOptionalField"; type = @("null", "string"); default = $null }
    $schema.fields += $field
    return ($schema | ConvertTo-Json -Depth 30 -Compress)
}

# 정본 avsc에 비호환 변형(required, default 없음) 필드를 추가해 반환.
function New-IncompatibleSchemaJson {
    param([Parameter(Mandatory)][string]$AvscPath)
    $schema = Get-Content -LiteralPath $AvscPath -Raw | ConvertFrom-Json -Depth 30
    $field = [pscustomobject]@{ name = "probeRequiredField"; type = "string" }
    $schema.fields += $field
    return ($schema | ConvertTo-Json -Depth 30 -Compress)
}

function Invoke-SelfTest {
    $sample = Join-Path $RepoRoot "src/main/avro/knowledge/NoteCreated.avsc"
    $compat = New-CompatibleSchemaJson -AvscPath $sample | ConvertFrom-Json -Depth 30
    $incompat = New-IncompatibleSchemaJson -AvscPath $sample | ConvertFrom-Json -Depth 30

    $cField = $compat.fields | Where-Object { $_.name -eq "probeOptionalField" }
    $iField = $incompat.fields | Where-Object { $_.name -eq "probeRequiredField" }

    if (-not $cField) { throw "SelfTest FAIL: 호환 변형에 probeOptionalField 없음" }
    if ($cField.type -notcontains "null") { throw "SelfTest FAIL: 호환 필드가 null union 아님" }
    if ($null -ne $cField.default) { throw "SelfTest FAIL: 호환 필드 default가 null 아님" }
    if (-not $iField) { throw "SelfTest FAIL: 비호환 변형에 probeRequiredField 없음" }
    if ($iField.PSObject.Properties.Name -contains "default") { throw "SelfTest FAIL: 비호환 필드에 default가 있음" }
    if ($iField.type -ne "string") { throw "SelfTest FAIL: 비호환 필드 type이 string 아님" }

    Write-Host "SelfTest PASS — 변형 로직 검증 완료(호환=optional+default / 비호환=required no-default)"
}

if ($SelfTest) { Invoke-SelfTest; return }

throw "Live run 미구현 — Task 2에서 추가"
```

- [ ] **Step 2: SelfTest 실행해 변형 로직 검증**

Run: `pwsh -File scripts/check-schema-backward-all.ps1 -SelfTest`
Expected: `SelfTest PASS — 변형 로직 검증 완료(...)` 출력, 종료코드 0. (레지스트리 불필요)

- [ ] **Step 3: 커밋**

```bash
git add scripts/check-schema-backward-all.ps1
git commit -F - <<'EOF'
feat(schema): 전수 BACKWARD 러너 스캐폴드 + 변형 로직 SelfTest (FR-TL-302)

9 subject 매니페스트 + 호환/비호환 변형 생성 함수.
호환=optional union+default, 비호환=required no-default (실 샘플 시맨틱).
-SelfTest로 레지스트리 없이 순수 변형 로직 검증.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## Task 2: Live 전수 — 등록·레벨 단언·양방향 프로브·리포트

**Files:**
- Modify: `scripts/check-schema-backward-all.ps1` (Step 1의 `throw "Live run 미구현..."`를 본 구현으로 교체)

- [ ] **Step 1: 레지스트리 가용 확인 (없을 때만 기동 — 충돌 회피)**

먼저 8081이 이미 응답하는지 확인(A 라이브 검증/C로 e2e 스택이 이미 떠 있으면 레지스트리도 8081에 존재):
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/subjects
```
- `200`이면 그대로 사용(별도 기동 불요).
- 연결 거부(`000`)면 standalone 기동:
```bash
docker compose -f docker-compose.schema-registry.yml up -d
```
그 후 `curl -s http://localhost:8081/subjects` 가 `200`(`[]` 또는 기존 subject 배열)일 때까지 30초 간격 재시도(기동 지연).

- [ ] **Step 2: Live 구현으로 교체 (`throw "Live run 미구현 — Task 2에서 추가"` 한 줄을 아래로 교체)**

```powershell
# ── Live 전수 ─────────────────────────────────────────────
$registerScript = Join-Path $ScriptDir "register-schema.ps1"
$checkScript    = Join-Path $ScriptDir "check-schema-compatibility.ps1"
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "schema-backward-probe"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$rows = @()
$anyFail = $false

foreach ($entry in $Manifest) {
    $subject = "$($entry.Topic)-value"
    $avscAbs = Join-Path $RepoRoot $entry.Avsc
    $row = [ordered]@{
        Subject = $subject; Avsc = $entry.Avsc
        Level = ""; CompatProbe = ""; IncompatProbe = ""; Result = "PASS"
    }

    try {
        # ① 정본 등록(+ subject-level compat 설정)
        & $registerScript -RegistryUrl $RegistryUrl -Subject $subject -SchemaPath $avscAbs `
            -Compatibility $RegisterCompatibility -Username $Username -Password $Password | Out-Null

        # ② compat 레벨 단언
        $cfg = Invoke-RestMethod -Method Get -Uri "$RegistryUrl/config/$subject"
        $row.Level = $cfg.compatibilityLevel
        if ($AllowedCompatibility -notcontains $cfg.compatibilityLevel) {
            throw "compat 레벨 '$($cfg.compatibilityLevel)' 이(가) 허용집합($($AllowedCompatibility -join ',')) 밖"
        }

        # ③ 호환 변형 프로브 → 호환이어야 PASS
        $compatPath = Join-Path $tmpDir "$subject.compatible.avsc"
        New-CompatibleSchemaJson -AvscPath $avscAbs | Set-Content -LiteralPath $compatPath -Encoding utf8
        & $checkScript -RegistryUrl $RegistryUrl -Subject $subject -SchemaPath $compatPath `
            -ExpectCompatible $true -Username $Username -Password $Password | Out-Null
        $row.CompatProbe = "accept ✅"

        # ④ 비호환 변형 프로브 → 거부여야 PASS
        $incompatPath = Join-Path $tmpDir "$subject.incompatible.avsc"
        New-IncompatibleSchemaJson -AvscPath $avscAbs | Set-Content -LiteralPath $incompatPath -Encoding utf8
        & $checkScript -RegistryUrl $RegistryUrl -Subject $subject -SchemaPath $incompatPath `
            -ExpectCompatible $false -Username $Username -Password $Password | Out-Null
        $row.IncompatProbe = "reject ✅"
    }
    catch {
        $row.Result = "FAIL — $($_.Exception.Message)"
        $anyFail = $true
    }
    $rows += [pscustomobject]$row
    Write-Host ("[{0}] {1}" -f $row.Result, $subject)
}

# ── 리포트 작성 ───────────────────────────────────────────
$reportAbs = Join-Path $RepoRoot $ReportPath
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Schema BACKWARD 전토픽 전수 리포트 — W5 Day3")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("> 생성: ``scripts/check-schema-backward-all.ps1`` · FR-TL-302 · 9 subject 전수(미발행 cards-generated 포함)")
[void]$sb.AppendLine("> 정의: 호환=optional union+default 추가 / 비호환=required no-default 추가 (Avro BACKWARD)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Subject | avsc | compat 레벨 | 호환 프로브 | 비호환 프로브 | 결과 |")
[void]$sb.AppendLine("|---|---|---|---|---|---|")
foreach ($r in $rows) {
    [void]$sb.AppendLine("| $($r.Subject) | $($r.Avsc) | $($r.Level) | $($r.CompatProbe) | $($r.IncompatProbe) | $($r.Result) |")
}
[void]$sb.AppendLine("")
$pass = ($rows | Where-Object { $_.Result -eq "PASS" }).Count
[void]$sb.AppendLine("**합계**: $pass/$($rows.Count) PASS")
Set-Content -LiteralPath $reportAbs -Value $sb.ToString() -Encoding utf8

if ($anyFail) {
    Write-Error "전수 FAIL 존재 — $reportAbs 확인"
    exit 1
}
Write-Host "전수 PASS ($pass/$($rows.Count)) — $reportAbs"
```

- [ ] **Step 3: SelfTest 회귀 확인 (Live 추가가 SelfTest를 깨지 않았는지)**

Run: `pwsh -File scripts/check-schema-backward-all.ps1 -SelfTest`
Expected: `SelfTest PASS ...`, 종료코드 0.

- [ ] **Step 4: Live 전수 실행**

Run: `pwsh -File scripts/check-schema-backward-all.ps1`
Expected: 9줄 `[PASS] <subject>` 출력 + `전수 PASS (9/9) — docs/reports/SCHEMA_BACKWARD_W5_DAY3.md`. 종료코드 0.
- FAIL 시: 해당 subject 행의 사유 확인 → 정본 avsc/레지스트리 상태 점검(정본 정렬 필요 여부 기록). FAIL을 임의로 통과 처리하지 말 것.

- [ ] **Step 5: 리포트 검토 + 커밋**

리포트 표가 9행 모두 `accept ✅`/`reject ✅`/`PASS`인지 육안 확인 후:
```bash
git add scripts/check-schema-backward-all.ps1 docs/reports/SCHEMA_BACKWARD_W5_DAY3.md
git commit -F - <<'EOF'
feat(schema): BACKWARD 전토픽 전수 강제 프로브 + 리포트 (FR-TL-302)

9 subject 전수(cards-generated 포함): 등록→레벨 단언→호환 accept·비호환 reject.
산출: docs/reports/SCHEMA_BACKWARD_W5_DAY3.md (9/9 PASS).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## Task 3: 추적 갱신

**Files:**
- Modify: `docs/project-management/workflow/WORKFLOW_team-lead_W5.md` (FR-TL-302 항목)

- [ ] **Step 1: 워크플로 체크박스 갱신**

`docs/project-management/workflow/WORKFLOW_team-lead_W5.md`의 라인:
```
- [ ] FR-TL-302 Schema BACKWARD 전 토픽 전수 (`--avro` 라이브 + 강제 프로브)
```
를 다음으로 교체:
```
- [x] FR-TL-302 Schema BACKWARD 전 토픽 전수 — 9 subject 강제 프로브 전수(cards-generated 포함) 9/9 PASS, `scripts/check-schema-backward-all.ps1` + [SCHEMA_BACKWARD_W5_DAY3](../../reports/SCHEMA_BACKWARD_W5_DAY3.md)
```

- [ ] **Step 2: 커밋**

```bash
git add docs/project-management/workflow/WORKFLOW_team-lead_W5.md
git commit -F - <<'EOF'
docs(workflow): FR-TL-302 Schema BACKWARD 전토픽 전수 완료 반영

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
```

---

## Task 2.5 (선택): `--avro` 라이브 라운드트립 보조 확인

> 스펙 §4 (보조). B의 PASS 기준은 (주) 강제 프로브에 둔다 — 이 단계는 직렬화 라운드트립 보강용. e2e 스택(Kafka+Registry) 기동 중일 때만.

- [ ] **Step 1: 라운드트립 실행 + cards-generated 갭 확인**

Run: `bash scripts/kafka-e2e-test.sh --avro`
Expected: 기존 8토픽 라운드트립 PASS. ⚠️ `kafka-e2e-test.sh`의 `run_avro`는 `learning.ai.cards-generated-v1`을 포함하지 않음 — 강제 프로브(주, Task 2)가 9번째를 커버하므로 BACKWARD 전수는 충족. cards-generated 라운드트립까지 원하면 `run_avro`에 한 줄 추가는 후속(이 플랜 범위 밖, 리포트에 메모).

## 완료 기준 (이 플랜)

- `scripts/check-schema-backward-all.ps1 -SelfTest` PASS (레지스트리 무관).
- Live 전수 9/9 PASS — 각 subject BACKWARD 레벨 + 호환 accept + 비호환 reject.
- `docs/reports/SCHEMA_BACKWARD_W5_DAY3.md` 커밋(9행 표).
- `WORKFLOW_team-lead_W5.md` FR-TL-302 `[x]`.
- FAIL 발생 시: 사유·후속(정본 정렬 필요 여부)을 리포트에 기록 — 은폐 금지.
