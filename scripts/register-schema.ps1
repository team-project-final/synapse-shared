param(
    [string]$RegistryUrl = "http://localhost:8081",
    [string]$Subject = "knowledge.note.note-created-v1-value",
    [string]$SchemaPath = ".\src\main\avro\knowledge\note-created-v1.avsc",
    [string]$Compatibility = "BACKWARD_TRANSITIVE",
    [string]$Username,
    [string]$Password
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-SchemaRegistryHeaders {
    param(
        [string]$Username,
        [string]$Password
    )

    $headers = @{
        "Content-Type" = "application/vnd.schemaregistry.v1+json"
    }

    if ($Username -and $Password) {
        $token = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${Username}:${Password}"))
        $headers["Authorization"] = "Basic $token"
    }

    return $headers
}

if (-not (Test-Path -LiteralPath $SchemaPath)) {
    throw "Schema file not found: $SchemaPath"
}

$headers = New-SchemaRegistryHeaders -Username $Username -Password $Password
$resolvedSchemaPath = (Resolve-Path -LiteralPath $SchemaPath).Path
$schema = [System.IO.File]::ReadAllText($resolvedSchemaPath, [System.Text.Encoding]::UTF8)

$compatibilityBody = @{ compatibility = $Compatibility } | ConvertTo-Json -Compress
$compatibilityResponse = Invoke-RestMethod `
    -Method Put `
    -Uri "$RegistryUrl/config/$Subject" `
    -Headers $headers `
    -Body $compatibilityBody

$registerBody = @{ schema = $schema } | ConvertTo-Json -Compress
$registerResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "$RegistryUrl/subjects/$Subject/versions" `
    -Headers $headers `
    -Body $registerBody

[PSCustomObject]@{
    subject = $Subject
    compatibility = $Compatibility
    compatibilityResponse = $compatibilityResponse
    registrationResponse = $registerResponse
} | ConvertTo-Json -Depth 10
