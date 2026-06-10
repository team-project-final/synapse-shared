#requires -Version 7
<#
.SYNOPSIS
  각 서비스 OpenAPI 노출 현황을 직접 포트 + gateway 경유로 실측 (FR-TL-304).
.DESCRIPTION
  Spring 서비스는 /v3/api-docs(+/swagger-ui/index.html), FastAPI(learning-ai)는
  /openapi.json(+/docs)를 프로브한다. gateway 라우트가 있는 서비스는 gateway 경유
  (stripPrefix(2)) 경로로도 프로브한다. learning-ai는 gateway 라우트가 없어 N/A.

  판정: 직접 Doc 엔드포인트가 200 → 노출 O, 아니면 X(보완 대상).

  주의(gateway 대조): gateway는 /api/** 전 경로에 JWT 인증을 요구한다
  (SecurityConfig: .pathMatchers("/api/**").authenticated()). 따라서 doc 경로를
  gateway로 인증 없이 호출하면 401이 정상이다 — 노출 판정은 직접 포트 기준으로 한다.
#>
param(
    [string]$GatewayBase = "http://localhost:8080",
    [string]$JsonOut = "docs/reports/api-doc-survey.json"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Service → 직접 base URL + OpenAPI 경로 + gateway route prefix(없으면 $null)
$Targets = @(
    [pscustomobject]@{ Name="platform-svc";     Type="Spring";  Direct="http://localhost:8081"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/platform" }
    [pscustomobject]@{ Name="knowledge-svc";    Type="Spring";  Direct="http://localhost:8082"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/knowledge" }
    [pscustomobject]@{ Name="engagement-svc";   Type="Spring";  Direct="http://localhost:8083"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/engagement" }
    [pscustomobject]@{ Name="learning-card-svc";Type="Spring";  Direct="http://localhost:8084"; Doc="/v3/api-docs"; Ui="/swagger-ui/index.html"; GwPrefix="/api/learning" }
    [pscustomobject]@{ Name="learning-ai-svc";  Type="FastAPI"; Direct="http://localhost:8090"; Doc="/openapi.json"; Ui="/docs"; GwPrefix=$null }
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
        Service   = $t.Name
        Type      = $t.Type
        DocPath   = $t.Doc
        DirectDoc = $directDoc
        DirectUi  = $directUi
        GatewayDoc = $gwDoc
        Exposed   = if ($exposed) { "O" } else { "X" }
    }
}

$results | Format-Table -AutoSize | Out-Host
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonOut -Encoding utf8
Write-Host "survey JSON -> $JsonOut"
