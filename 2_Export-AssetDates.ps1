param(
    [string]$JsonPath = (Join-Path $PSScriptRoot 'needDates.json'),
    [string]$CsvPath = (Join-Path $PSScriptRoot 'needDates.csv'),

    [ValidateNotNullOrEmpty()]
    [string]$DateFormat = 'yyyyMMdd_HHmmssfff'
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture

$data = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
if ($null -eq $data.assets -or $null -eq $data.assets.items) {
    throw 'The JSON must contain an assets.items array.'
}

$assets = @($data.assets.items)
if ($assets.Count -eq 0) {
    throw 'The JSON contains no assets to export.'
}

$rows = @(foreach ($asset in $assets) {
    foreach ($field in 'id', 'originalPath', 'originalFileName') {
        if ([string]::IsNullOrWhiteSpace($asset.$field)) {
            throw "An asset is missing the required field '$field'."
        }
    }

    $fileName = $asset.originalFileName
    $localDate = [datetime]::MinValue
    $found = $false
    :findDate for ($start = 0; $start -lt $fileName.Length; $start++) {
        if ($start -gt 0 -and [char]::IsDigit($fileName[$start - 1])) {
            continue
        }

        for ($end = $fileName.Length; $end -gt $start; $end--) {
            if ($end -lt $fileName.Length -and [char]::IsDigit($fileName[$end])) {
                continue
            }

            if ([datetime]::TryParseExact(
                $fileName.Substring($start, $end - $start),
                $DateFormat,
                $culture,
                [Globalization.DateTimeStyles]::None,
                [ref]$localDate
            )) {
                $found = $true
                break findDate
            }
        }
    }

    if (-not $found) {
        throw "No valid timestamp matching '$DateFormat' found in '$fileName' for asset $($asset.id)."
    }

    $date = [datetimeoffset]::new($localDate, [timespan]::FromHours(-5))
    [pscustomobject][ordered]@{
        id = $asset.id
        originalPath = $asset.originalPath
        OriginalFileName = $asset.originalFileName
        extractedDate = $date.ToString('yyyy-MM-ddTHH:mm:ss.fffzzz', $culture)
    }
})

$rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($rows.Count) assets to $CsvPath."
