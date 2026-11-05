#requires -Version 7.0
<#
.SYNOPSIS
    Rebuilds op77_lightrp_titans' two preload packages (dist/bt7274_1.zip, dist/bt7274_2.zip) from the BT-7274 player
    package that Open77's scripts/titans/prepare_bt7274_package.py writes (its --out folder, laid out like the game folder).

.DESCRIPTION
    The package is about 388 MB and the server's limit is 256 MiB per preload archive, so it is cut in two:
      bt7274_1.zip  archive/pc/mod/bt7274.archive(.xl)                inert, the Titan assets (one indivisible archive)
      bt7274_2.zip  r6/scripts, r6/tweaks, red4ext/plugins/AudioXL/... executable (.reds), so the server needs
                                                                      requiredMods.unsecured
    package-manifest.json is the build's own receipt, not a game file: it is left out (no mod root accepts it).

.EXAMPLE
    pwsh tools/build-assets.ps1 -Package D:/orca/workspaces/open77-base/feat-pve-titans/build/titans/bt7274
#>
param([Parameter(Mandatory)][string]$Package)
$ErrorActionPreference = 'Stop'
$dist = Join-Path (Split-Path -Parent $PSScriptRoot) 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

$zip = @'
import os, sys, zipfile
package, target, roots = sys.argv[1], sys.argv[2], sys.argv[3:]
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root in roots:
        top = os.path.join(package, root)
        if not os.path.isdir(top):
            sys.exit(f'missing {top}')
        for folder, _, files in os.walk(top):
            for name in sorted(files):
                path = os.path.join(folder, name)
                z.write(path, os.path.relpath(path, package).replace(os.sep, '/'))
'@
python -I -c $zip $Package (Join-Path $dist 'bt7274_1.zip') 'archive'
if ($LASTEXITCODE) { throw "bt7274_1.zip failed ($LASTEXITCODE)" }
python -I -c $zip $Package (Join-Path $dist 'bt7274_2.zip') 'r6' 'red4ext'
if ($LASTEXITCODE) { throw "bt7274_2.zip failed ($LASTEXITCODE)" }
$limit = 256MB
Get-ChildItem $dist -Filter 'bt7274_*.zip' | ForEach-Object {
    if ($_.Length -gt $limit) { throw "$($_.Name) is $($_.Length) bytes; the server's preload limit is $limit" }
    '{0}  {1:N1} MiB' -f $_.Name, ($_.Length / 1MB)
}
