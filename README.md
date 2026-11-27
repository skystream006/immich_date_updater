# Update Immich asset dates from filenames

Run these scripts in order:

1. [1_getAssetData.ps1](1_getAssetData.ps1): fetch an album's asset metadata into JSON.
2. [2_Export-AssetDates.ps1](2_Export-AssetDates.ps1): extract filename timestamps into CSV.
3. [3_updateAssetDates.ps1](3_updateAssetDates.ps1): update original-file metadata with ExifTool, then update Immich.

## Before you start

- Use PowerShell and open a terminal in this folder.
- Make sure your Immich server is reachable.
- Install [ExifTool](https://exiftool.org/) and make the `exiftool` command available on your PATH for step 3.
- Back up your original files and Immich database before step 3.
- By default, filenames must contain `YYYYMMDD_HHMMSSfff`, where `fff` is milliseconds.
  Example: `InShot_20201007_203251440.mp4`. Use `-DateFormat` in step 2 for another format.

**Timezone:** filename timestamps are treated as local Eastern Standard Time,
with a fixed `-05:00` offset all year. Daylight saving time is not applied.
The example above becomes `2020-10-07T20:32:51.440-05:00`.

## Obtain an API key

1. Sign in to the Immich web application with an account that can access and update the assets.
2. Open your profile menu, then **User Settings > API Keys**.
3. Create a new key and give it a descriptive name.
4. Grant `asset.read` for metadata searches and `asset.update` for date updates.
5. Copy the generated key and keep it private. Do not put it in this README or commit it with the scripts.

See the official [API getting-started guide](https://api.immich.app/getting-started)
for details. Permission availability can depend on your installed Immich version.

## Obtain the album ID from the browser URL

Open the album in Immich and copy the UUID following `/albums/` in the address bar.
For example:

```text
http://localhost:2283/albums/12345678-1234-1234-1234-123456789abc
```

The album ID is `12345678-1234-1234-1234-123456789abc`.
Copy only the UUID, not the entire URL or any query parameters.
**The album ID comes from the album URL, not from the API key.**

## Set shared values

Run these commands in the same PowerShell session used for the scripts:

```powershell
$serverUrl = 'http://localhost:2283'
$albumId = '12345678-1234-1234-1234-123456789abc'
$env:IMMICH_API_KEY = Read-Host 'Paste your Immich API key'
```

Replace the server URL and album ID with your values. Include the port when
needed, but do not append `/api` to the server URL. Prefer HTTPS when available.
The key prompt avoids putting the key directly in a command saved to shell history.

## Step 1: Fetch asset metadata

```powershell
.\1_getAssetData.ps1 `
    -ServerUrl $serverUrl `
    -ApiKey $env:IMMICH_API_KEY `
    -AlbumId $albumId
```

| Parameter | Required | Default |
| --- | --- | --- |
| `ServerUrl` | Yes | None |
| `ApiKey` | Yes | None |
| `AlbumId` | Yes | None |
| `Size` | No | `1000` (allowed: 1-1000) |
| `Page` | No | `1` (only page 1 is allowed) |
| `OutputPath` | No | `needDates.json` beside the script |

This sends `POST /api/search/metadata` and saves formatted JSON.
An API failure stops the script without replacing the existing output.
A successful run replaces the output file.

**Album size limit:** this workflow is intended for albums with **1,000 or fewer
items**. Fetch only page 1 with a size of up to 1,000 (the defaults). The script
does not automatically fetch additional pages or merge results. Larger albums
are rejected without replacing the output; split them into albums of 1,000 or fewer items first.
Check that the response's `assets.count` matches `assets.total` before continuing.

## Step 2: Create and review the CSV

```powershell
.\2_Export-AssetDates.ps1
```

Optional input and output paths:

```powershell
.\2_Export-AssetDates.ps1 `
    -JsonPath '.\needDates.json' `
    -CsvPath '.\needDates.csv'
```

Defaults are `needDates.json` and `needDates.csv` beside the script.
`DateFormat` defaults to `yyyyMMdd_HHmmssfff` and uses case-sensitive
[.NET date/time format strings](https://learn.microsoft.com/dotnet/standard/base-types/custom-date-and-time-format-strings):
`MM` means month, `mm` means minute, and `HH` means 24-hour time.
Use a local date/time format without a timezone or UTC offset.

For filenames such as `IMG_2020-10-07_20-32-51.jpg`:

```powershell
.\2_Export-AssetDates.ps1 -DateFormat 'yyyy-MM-dd_HH-mm-ss'
```

The script extracts the first valid matching timestamp in each filename,
without starting or ending inside a longer digit sequence. Missing milliseconds
are written as `.000`. The CSV output always uses ISO timestamps with fixed
EST (`-05:00`), regardless of the input format.

The output columns are:

| Column | Value |
| --- | --- |
| `id` | Immich asset ID |
| `originalPath` | Original file path from Immich |
| `OriginalFileName` | Original filename |
| `extractedDate` | ISO timestamp with milliseconds and fixed EST offset |

The script validates every asset before writing the CSV. Missing asset data,
missing filename timestamps, or invalid dates stop the export.
A successful export replaces the output CSV.

**Review the CSV before step 3**, especially the extracted dates and file paths.
Paths such as `/data/library/...` are paths from the Immich server/container;
they may not exist on your Windows computer. Run step 3 where those files are
accessible, or adjust the CSV's `originalPath` values to the correct local paths.
The script does not map paths automatically.

## Step 3: Update file metadata and Immich dates

```powershell
.\3_updateAssetDates.ps1 `
    -ServerUrl $serverUrl `
    -ApiKey $env:IMMICH_API_KEY `
    -CsvPath '.\needDates.csv'
```

`ServerUrl` and `ApiKey` are required.
`CsvPath` defaults to `needDates.csv` beside the script.

For each CSV row, the script:

1. Runs ExifTool to set the original file's `DateTimeOriginal`, using
   `-overwrite_original`.
2. Sends `PUT /api/assets/{id}` with `dateTimeOriginal` set to `extractedDate`.
3. Prints a progress message after the API update succeeds.

**This step modifies both original files and Immich. There is no dry-run mode.**
ExifTool's `-overwrite_original` option does not retain an `_original` backup.
Ensure that the files are writable and their formats support the metadata tag.

Processing stops on an error, but earlier changes are not rolled back.
If an API update fails after ExifTool succeeds, that row's original file has
already been modified even though its Immich update failed.

## Troubleshooting

- **401 or 403:** check the API key, permissions, and access to the assets.
- **Cannot PUT /api/asset/...:** the update route is `/api/assets/{id}` (plural).
- **ExifTool not found:** install it and ensure `exiftool` is on PATH.
- **File not found or not writable:** check `originalPath` on the machine running step 3.
- **Missing or invalid filename timestamp:** correct the input or exclude unsupported assets before exporting.

When finished, remove the key from the current session:

```powershell
Remove-Item Env:\IMMICH_API_KEY
```
