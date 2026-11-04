#requires -Version 7.0
<#
.SYNOPSIS
    Rebuilds op77_tcg's generated content from the Cyberpunk TCG Collectibles mod zip (Nexus 34654, 1.1):
    the four preload packages (dist/op77_tcg_1..4.zip), the catalogue (shared/catalogue.lua, web/data/catalogue.json)
    and the card / UI images (web/img).

.DESCRIPTION
    The mod's 549 MiB collection archive is over the server's 256 MiB preload limit, so its files are regrouped by card
    into three archives (plus the 47 MiB assets archive) with WolvenKit (extract, pack). Card fronts are decoded from
    the archive's own print textures (DXT5 1024x2048) with tools/xbm2png.py: WolvenKit 8.19 fails on their DDS header.

    Work happens under -Work (default E:/Open77/tmp/op77-tcg-build), a NEW folder each run is safest.

.EXAMPLE
    pwsh tools/build-assets.ps1 -ModZip "C:/Users/me/Downloads/Cyberpunk TCG Collectibles 34654 1.1.zip"
#>
param(
    [Parameter(Mandatory)][string]$ModZip,
    [string]$WolvenKit = 'E:/Open77/Gta2CPPuppet/vendor/wolvenkit/WolvenKit.CLI.exe',
    [string]$Work = 'E:/Open77/tmp/op77-tcg-build'
)
$ErrorActionPreference = 'Stop'
$res = Split-Path -Parent $PSScriptRoot
$tools = $PSScriptRoot
$src = Join-Path $Work 'src'
New-Item -ItemType Directory -Force $src | Out-Null

Write-Host '== Extracting the mod (data only) =='
python -I -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); [z.extract(i, sys.argv[2]) for i in z.infolist() if i.filename.endswith(('.archive','.reds','.yaml'))]" $ModZip $src
$col = Join-Path $src 'archive/pc/mod/cyberpunktcg_collection.archive'
$assets = Join-Path $src 'archive/pc/mod/cyberpunktcg_assets.archive'
& $WolvenKit archiveinfo $col --list | Out-File -Encoding utf8 (Join-Path $src 'collection.list')

Write-Host '== Catalogue =='
python $tools/build_catalogue.py $src $Work
python $tools/emit_catalogue.py (Join-Path $Work 'catalogue.json') $res

Write-Host '== Card fronts =='
$raw = Join-Path $Work 'raw'; $json = Join-Path $Work 'json'
New-Item -ItemType Directory -Force $raw, $json | Out-Null
& $WolvenKit extract $col -o $raw -r '(front_d01|_print_d01|standard_backside|foil_spectrum)\.xbm$' | Out-Null
& $WolvenKit convert serialize (Join-Path $raw 'cyberpunktcg/cards/catalogue') -o $json | Out-Null
python $tools/build_images.py $json (Join-Path $Work 'catalogue.json') (Join-Path $res 'web/img')

Write-Host '== Preload packages =='
$fullCol = Join-Path $Work 'fullcol'; $fullAssets = Join-Path $Work 'fullassets'
& $WolvenKit extract $col -o $fullCol | Out-Null
& $WolvenKit extract $assets -o $fullAssets | Out-Null
python $tools/split_pack.py $fullCol $fullAssets (Join-Path $Work 'pack') (Join-Path $res 'dist')
Get-ChildItem (Join-Path $res 'dist') -Filter *.zip | ForEach-Object { '{0}  {1:N1} MiB' -f $_.Name, ($_.Length / 1MB) }
