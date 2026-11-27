param(
    [string]$JsonPath = (Join-Path $PSScriptRoot 'needDates.json'),
    [string]$CsvPath = (Join-Path $PSScriptRoot 'needDates.csv')
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

    $match = [regex]::Match($asset.originalFileName, '(?<!\d)(\d{8}_\d{9})(?!\d)')
    if (-not $match.Success) {
        throw "No YYYYMMDD_HHMMSSfff timestamp found in '$($asset.originalFileName)' for asset $($asset.id)."
    }

    $localDate = [datetime]::MinValue
    if (-not [datetime]::TryParseExact(
        $match.Groups[1].Value,
        'yyyyMMdd_HHmmssfff',
        $culture,
        [Globalization.DateTimeStyles]::None,
        [ref]$localDate
    )) {
        throw "Invalid filename timestamp for asset $($asset.id): $($match.Groups[1].Value)."
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
