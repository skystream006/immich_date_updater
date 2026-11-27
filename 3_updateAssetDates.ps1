param(
    [Parameter(Mandatory)]
    [ValidateScript({ $_.IsAbsoluteUri -and $_.Scheme -in @('http', 'https') })]
    [uri]$ServerUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [ValidateNotNullOrEmpty()]
    [string]$CsvPath = (Join-Path $PSScriptRoot 'needDates.csv'),

    [Alias('no-exif')]
    [switch]$NoExif
)

$ErrorActionPreference = 'Stop'

$counter = 0
Import-Csv -LiteralPath $CsvPath | ForEach-Object {
    if (-not $NoExif) {
        & exiftool -DateTimeOriginal="$($_.extractedDate)" -overwrite_original $_.originalPath
        if ($LASTEXITCODE -ne 0) {
            throw "ExifTool failed for asset $($_.id) with exit code $LASTEXITCODE."
        }
    }

    # Update the asset's dateTimeOriginal field in the server using the API
    $body = @{
        dateTimeOriginal = $_.extractedDate
    } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Put `
        -Uri "$($ServerUrl.AbsoluteUri.TrimEnd('/'))/api/assets/$($_.id)" `
        -Headers @{ 'x-api-key' = $ApiKey } `
        -ContentType 'application/json' `
        -Body $body

    
    $counter++
    Write-Output "[$counter] Updated asset $($_.id) with extracted date $($_.extractedDate)"
}
