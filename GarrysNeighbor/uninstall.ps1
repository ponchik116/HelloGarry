$ErrorActionPreference = 'Stop'

function Get-SteamPath {
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try { $p = (Get-ItemProperty $key -ErrorAction Stop).SteamPath; if ($p) { return $p } } catch {}
    }
}
function Find-HelloNeighbor {
    $steam = Get-SteamPath
    if (-not $steam) { return $null }
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $txt = Get-Content -Raw $vdf
        foreach ($m in [regex]::Matches($txt, '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\','\') }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $manifest = Join-Path $lib 'steamapps\appmanifest_521890.acf'
        if (Test-Path $manifest) {
            $txt = Get-Content -Raw $manifest
            $m = [regex]::Match($txt, '"installdir"\s+"([^"]+)"')
            if ($m.Success) { return Join-Path $lib ('steamapps\common\' + $m.Groups[1].Value) }
        }
    }
    return $null
}
$game = Find-HelloNeighbor
if (-not $game) { throw 'Hello Neighbor не найден.' }
$win64 = Get-ChildItem -Path $game -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '\\Binaries\\Win64$' } | Select-Object -First 1
if (-not $win64) { throw 'Win64 не найден.' }
$roots = @($win64.FullName)
if (Test-Path (Join-Path $win64.FullName 'ue4ss')) { $roots += Join-Path $win64.FullName 'ue4ss' }
foreach ($r in $roots) {
    $mod = Join-Path $r 'Mods\GarrysNeighbor'
    if (Test-Path $mod) { Remove-Item -Recurse -Force $mod }
    $txtFile = Join-Path $r 'Mods\mods.txt'
    if (Test-Path $txtFile) {
        $lines = @(Get-Content $txtFile) | Where-Object { $_ -notmatch '^\s*GarrysNeighbor\s*:' }
        Set-Content -Encoding UTF8 $txtFile $lines
    }
}
Write-Host 'Garrys Neighbor удалён.' -ForegroundColor Green
