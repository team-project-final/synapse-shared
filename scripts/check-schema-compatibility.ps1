param(
    [string]$RegistryUrl = "http://localhost:8081",
    [string]$Subject = "knowledge.note.note-created-v1-value",
    [string]$SchemaPath,
    [bool]$ExpectCompatible = $true,
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

if ([string]::IsNullOrWhiteSpace($SchemaPath)) {
    throw "SchemaPath is required."
}

if (-not (Test-Path -LiteralPath $SchemaPath)) {
    throw "Schema file not found: $SchemaPath"
}

$headers = New-SchemaRegistryHeaders -Username $Username -Password $Password
$resolvedSchemaPath = (Resolve-Path -LiteralPath $SchemaPath).Path
$schema = [System.IO.File]::ReadAllText($resolvedSchemaPath, [System.Text.Encoding]::UTF8)
$body = @{ schema = $schema } | ConvertTo-Json -Compress

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$RegistryUrl/compatibility/subjects/$Subject/versions/latest" `
    -Headers $headers `
    -Body $body

if ($response.is_compatible -ne $ExpectCompatible) {
    throw "Expected compatibility=$ExpectCompatible for '$SchemaPath' but got $($response.is_compatible)."
}

[PSCustomObject]@{
    subject = $Subject
    schemaPath = $SchemaPath
    expectedCompatible = $ExpectCompatible
    response = $response
} | ConvertTo-Json -Depth 10
