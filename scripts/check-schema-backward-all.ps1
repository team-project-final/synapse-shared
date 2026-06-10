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
    [pscustomobject]@{ Topic = "platform.auth.user-registered-v1";          Avsc = "src/main/avro/platform/UserRegistered.avsc" }
    [pscustomobject]@{ Topic = "knowledge.note.note-created-v1";             Avsc = "src/main/avro/knowledge/NoteCreated.avsc" }
    [pscustomobject]@{ Topic = "knowledge.note.note-updated-v1";             Avsc = "src/main/avro/knowledge/NoteUpdated.avsc" }
    [pscustomobject]@{ Topic = "learning.card.review-completed-v1";          Avsc = "src/main/avro/learning/ReviewCompleted.avsc" }
    [pscustomobject]@{ Topic = "learning.card.review-due-v1";                Avsc = "src/main/avro/learning/CardReviewDue.avsc" }
    [pscustomobject]@{ Topic = "engagement.gamification.level-up-v1";        Avsc = "src/main/avro/engagement/LevelUp.avsc" }
    [pscustomobject]@{ Topic = "engagement.gamification.badge-earned-v1";    Avsc = "src/main/avro/engagement/BadgeEarned.avsc" }
    [pscustomobject]@{ Topic = "platform.notification.notification-send-v1"; Avsc = "src/main/avro/platform/NotificationSend.avsc" }
    [pscustomobject]@{ Topic = "learning.ai.cards-generated-v1";             Avsc = "src/main/avro/learning/CardsGenerated.avsc" }
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
[void]$sb.AppendLine("> 레지스트리: $RegistryUrl")
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
