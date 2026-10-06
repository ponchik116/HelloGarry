$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-SteamPath {
    $keys = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )
    foreach ($key in $keys) {
        try {
            $p = (Get-ItemProperty $key -ErrorAction Stop).SteamPath
            if ($p) { return $p }
        } catch {}
    }
    return $null
}

function Find-HelloNeighbor {
    $steam = Get-SteamPath
    if (-not $steam) { throw 'Steam не найден.' }

    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $txt = Get-Content -Raw $vdf
        foreach ($m in [regex]::Matches($txt, '"path"\s+"([^"]+)"')) {
            $libraries += $m.Groups[1].Value.Replace('\\','\')
        }
    }

    foreach ($lib in ($libraries | Select-Object -Unique)) {
        $manifest = Join-Path $lib 'steamapps\appmanifest_521890.acf'
        if (Test-Path $manifest) {
            $txt = Get-Content -Raw $manifest
            $m = [regex]::Match($txt, '"installdir"\s+"([^"]+)"')
            if ($m.Success) {
                return Join-Path $lib ('steamapps\common\' + $m.Groups[1].Value)
            }
        }
    }
    throw 'Hello Neighbor (Steam AppID 521890) не найден в библиотеках Steam.'
}

$gameRoot = Find-HelloNeighbor
$win64 = $null
$preferred = @(
    (Join-Path $gameRoot 'HelloNeighbor\Binaries\Win64'),
    (Join-Path $gameRoot 'Binaries\Win64')
)
foreach ($p in $preferred) {
    if (Test-Path (Join-Path $p '*.exe')) { $win64 = $p; break }
    if (Test-Path $p) { $win64 = $p; break }
}
if (-not $win64) {
    $found = Get-ChildItem -Path $gameRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Binaries\\Win64$' } |
        Select-Object -First 1
    if ($found) { $win64 = $found.FullName }
}
if (-not $win64) { throw 'Не найден каталог Hello Neighbor\\Binaries\\Win64.' }

# Current/basic UE4SS layout: <Win64>\Mods. If an old central install exists, reuse <Win64>\ue4ss\Mods.
$legacyRoot = Join-Path $win64 'ue4ss'
if (Test-Path (Join-Path $legacyRoot 'UE4SS.dll')) {
    $modsDir = Join-Path $legacyRoot 'Mods'
} else {
    $modsDir = Join-Path $win64 'Mods'
}

$modDir = Join-Path $modsDir 'GarrysNeighbor'
New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
if (Test-Path $modDir) { Remove-Item -Recurse -Force $modDir }
Copy-Item -Recurse -Force (Join-Path $root 'GarrysNeighbor') $modDir

$modsTxt = Join-Path $modsDir 'mods.txt'
$lines = @()
if (Test-Path $modsTxt) { $lines = @(Get-Content $modsTxt) }
$lines = $lines | Where-Object { $_ -notmatch '^\s*GarrysNeighbor\s*:' }
$lines += 'GarrysNeighbor : 1'
Set-Content -Encoding UTF8 $modsTxt $lines

$ue4ssPresent = (Test-Path (Join-Path $win64 'dwmapi.dll')) -or (Test-Path (Join-Path $win64 'UE4SS.dll')) -or (Test-Path (Join-Path $win64 'ue4ss\UE4SS.dll'))

Write-Host ''
Write-Host '=== GARRY''S NEIGHBOR ===' -ForegroundColor Cyan
Write-Host ('Игра:      ' + $gameRoot)
Write-Host ('Win64:     ' + $win64)
Write-Host ('Мод:       ' + $modDir)
if ($ue4ssPresent) {
    Write-Host 'UE4SS:     найден' -ForegroundColor Green
} else {
    Write-Host 'UE4SS:     НЕ найден' -ForegroundColor Yellow
    Write-Host 'Мод установлен, но для запуска Lua-мода нужен UE4SS.' -ForegroundColor Yellow
    Write-Host 'Официальный релиз: https://github.com/UE4SS-RE/RE-UE4SS/releases' -ForegroundColor Gray
}
Write-Host ''
Write-Host 'Запусти Hello Neighbor, зайди в игровой уровень и нажми H.' -ForegroundColor Green
