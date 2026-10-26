#requires -Version 7.0
<#
Validate wardrobe icon mappings or migrate legacy record-based filenames.
The signed client cache adds a long prefix: keep asset names short even when
the resource source directory is short. No image bytes are changed.
Usage: ./tools/compact-icon-paths.ps1 [-Apply -BackupDirectory <new directory>]
#>
[CmdletBinding()]
param([switch]$Apply, [string]$BackupDirectory)
$ErrorActionPreference = 'Stop'
$webRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../web'))
$iconRoot = Join-Path $webRoot 'icons'
$manifestPath = Join-Path $iconRoot 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
$plan = [Collections.Generic.List[object]]::new()
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$destinations = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

# Validate the whole plan before any write, including unreferenced assets.
if ((Get-Item -LiteralPath $iconRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Linked icon directories are not supported.'
}
foreach ($file in Get-ChildItem -LiteralPath $iconRoot -Recurse -Force) {
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked asset: $($file.FullName)" }
}
foreach ($record in $manifest.Keys) {
    $shortName = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($record))).Substring(0, 16).ToLowerInvariant()
    foreach ($family in $manifest[$record].Keys) {
        $relative = [string]$manifest[$record][$family]
        if ($family -notin @('m', 'f') -or $relative -notmatch "^icons/$family/[A-Za-z0-9_.-]+\.webp$") {
            throw "Invalid icon mapping for $record / $family"
        }
        $source = [IO.Path]::GetFullPath((Join-Path $webRoot $relative))
        $targetRelative = "icons/$family/$shortName.webp"
        $target = [IO.Path]::GetFullPath((Join-Path $webRoot $targetRelative))
        if (-not $source.StartsWith($iconRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            -not $target.StartsWith($iconRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'An icon path escaped its resource directory.'
        }
        if (-not $seen.Add($source) -or -not $destinations.Add($target)) { throw "Duplicate or colliding icon: $relative" }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing icon: $relative" }
        if ($source -ne $target -and (Test-Path -LiteralPath $target)) { throw "Target already exists: $target" }
        $plan.Add([pscustomobject]@{ Record=$record; Family=$family; Source=$source; Target=$target;
            Relative=$relative; TargetRelative=$targetRelative; Hash=(Get-FileHash -LiteralPath $source).Hash })
    }
}
foreach ($file in Get-ChildItem -LiteralPath $iconRoot -Recurse -File -Filter '*.webp') {
    if (-not $seen.Contains($file.FullName)) { throw "Unreferenced icon (must not remain in web/**): $($file.FullName)" }
}
$changes = @($plan | Where-Object { $_.Source -ne $_.Target })
if ($Apply -and $changes.Count -gt 0) {
    if (-not $BackupDirectory) { throw '-BackupDirectory is required when applying a migration.' }
    $backup = [IO.Path]::GetFullPath($BackupDirectory)
    if ($backup.StartsWith($webRoot, [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $backup)) {
        throw 'Backup must be a new directory outside the published web tree.'
    }
    New-Item -ItemType Directory -Path $backup | Out-Null
    Copy-Item -LiteralPath $iconRoot -Destination (Join-Path $backup 'icons') -Recurse
    foreach ($entry in $plan) {
        $saved = Join-Path $backup $entry.Relative
        if ((Get-FileHash -LiteralPath $saved).Hash -ne $entry.Hash) { throw "Backup mismatch: $saved" }
    }
    foreach ($entry in $changes) { Move-Item -LiteralPath $entry.Source -Destination $entry.Target }
    foreach ($entry in $plan) {
        if ((Get-FileHash -LiteralPath $entry.Target).Hash -ne $entry.Hash) { throw "Migrated icon mismatch: $($entry.Target)" }
        $manifest[$entry.Record][$entry.Family] = $entry.TargetRelative
    }
    # Mechanical rewrite: only mapping values change, never clothing record IDs.
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 4 -Compress), [Text.UTF8Encoding]::new($false))
    Write-Output "Migrated $($changes.Count) images without changing bytes. Backup: $backup"
} elseif ($changes.Count -gt 0) {
    throw "$($changes.Count) icons still use legacy paths. Run with -Apply and a new -BackupDirectory."
}
Write-Output "Validated $($manifest.Count) clothing records / $($plan.Count) icons; compact names are 21 characters."
