$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-HelloNeighbor {
    $candidates = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )
    $steamPath = $null
    foreach ($key in $candidates) {
        try { $steamPath = (Get-ItemProperty $key -ErrorAction Stop).SteamPath; if ($steamPath) { break } } catch {}
    }
    if (-not $steamPath) { throw 'Steam path not found.' }

    $libs = @($steamPath)
    $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $txt = Get-Content -Raw $vdf
        foreach ($m in [regex]::Matches($txt, '"path"\s+"([^"]+)"')) {
            $libs += $m.Groups[1].Value.Replace('\\','\')
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $manifest = Join-Path $lib 'steamapps\appmanifest_521890.acf'
        if (Test-Path $manifest) {
            $ac = Get-Content -Raw $manifest
            $m = [regex]::Match($ac, '"installdir"\s+"([^"]+)"')
            if ($m.Success) { return (Join-Path $lib ('steamapps\common\' + $m.Groups[1].Value)) }
        }
    }
    throw 'Hello Neighbor (Steam app 521890) was not found in your Steam libraries.'
}

$game = Find-HelloNeighbor
$win64 = Join-Path $game 'HelloNeighbor\Binaries\Win64'
if (-not (Test-Path $win64)) {
    $alt = Get-ChildItem -Path $game -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '\\Binaries\\Win64$' } | Select-Object -First 1
    if ($alt) { $win64 = $alt.FullName }
}

$ue4ss = Join-Path $win64 'ue4ss'
$mods = Join-Path $ue4ss 'Mods'
New-Item -ItemType Directory -Force -Path $mods | Out-Null

# Install mod payload.
Copy-Item -Recurse -Force (Join-Path $root 'GarrysNeighbor') $mods

$modsTxt = Join-Path $mods 'mods.txt'
if (-not (Test-Path $modsTxt)) { New-Item -ItemType File -Force -Path $modsTxt | Out-Null }
$lines = @(Get-Content $modsTxt -ErrorAction SilentlyContinue)
$lines = $lines | Where-Object { $_ -notmatch '^GarrysNeighbor\s*:' }
$lines += 'GarrysNeighbor : 1'
Set-Content -Encoding UTF8 $modsTxt $lines

Write-Host ''
Write-Host 'Garrys Neighbor installed.' -ForegroundColor Green
Write-Host ('Hello Neighbor: ' + $game)
Write-Host ('UE4SS Mods:     ' + $mods)
Write-Host ''
Write-Host 'Start Hello Neighbor normally, load into a level, then press H.' -ForegroundColor Cyan
