param(
    [Parameter(Mandatory)]
    [ValidateScript({ $_.IsAbsoluteUri -and $_.Scheme -in @('http', 'https') })]
    [uri]$ServerUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [Parameter(Mandatory)]
    [guid]$AlbumId,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Size = 1000,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Page = 1,

    [string]$OutputPath = (Join-Path $PSScriptRoot 'needDates.json')
)

$ErrorActionPreference = 'Stop'

$body = @{
    albumIds = @($AlbumId.ToString())
    size = $Size
    page = $Page
} | ConvertTo-Json -Compress

$response = Invoke-RestMethod -Method Post `
    -Uri "$($ServerUrl.AbsoluteUri.TrimEnd('/'))/api/search/metadata" `
    -Headers @{ 'x-api-key' = $ApiKey } `
    -ContentType 'application/json' `
    -Body $body

$response | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Saved page $Page to $OutputPath."