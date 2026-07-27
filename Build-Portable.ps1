$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'Cyber.pw-Asistant'
$zip = Join-Path $dist 'Cyber.pw-Asistant-Portable.zip'

if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }
$resolvedDist = [IO.Path]::GetFullPath($dist).TrimEnd([IO.Path]::DirectorySeparatorChar)
$resolvedStage = [IO.Path]::GetFullPath($stage)
if (-not $resolvedStage.StartsWith($resolvedDist + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Небезпечний шлях папки складання.'
}
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

$files = @(
    'CyberPW-Launcher.ps1',
    'CyberPW-Common.ps1',
    'CyberPW-Design.ps1',
    'CyberPW-MultiLauncher.ps1',
    'CyberPW-Unfreeze.ps1',
    'CyberPW-WorldBosses.ps1',
    'CyberPW-ChestSimulator.ps1',
    'CyberPW-TerritoryMap.ps1',
    'CyberPW-MacroStudio.ps1',
    'VERSION',
    'CyberPW-Titles.ps1',
    'CyberPW-ClientTitleSync.ps1',
    'titles.json',
    'cyberpw-logo.png',
    'gvg-map.png',
    'territory-polygons.json',
    'Запустити.bat'
)
foreach ($name in $files) {
    $source = Join-Path $root $name
    if (-not (Test-Path $source)) { throw "Не знайдено обов'язковий файл: $name" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $stage $name)
}
$iconSource = Join-Path $root 'class-icons'
if (-not (Test-Path -LiteralPath $iconSource -PathType Container)) { throw 'Не знайдено папку class-icons.' }
$iconStage = Join-Path $stage 'class-icons'
New-Item -ItemType Directory -Path $iconStage | Out-Null
foreach ($iconName in @('warrior.png','mage.png','tank.png','druid.png','archer.png','cleric.png','assassin.png','shaman.png','seeker.png','mystic.png')) {
    $iconFile = Join-Path $iconSource $iconName
    if (-not (Test-Path -LiteralPath $iconFile -PathType Leaf)) { throw "Не знайдено іконку класу: $iconName" }
    Copy-Item -LiteralPath $iconFile -Destination (Join-Path $iconStage $iconName)
}
$lootSource = Join-Path $root 'loot-icons'
if (-not (Test-Path -LiteralPath $lootSource -PathType Container)) { throw 'Не знайдено папку loot-icons.' }
Copy-Item -LiteralPath $lootSource -Destination (Join-Path $stage 'loot-icons') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'README-PORTABLE.md') -Destination (Join-Path $stage 'README.md')

$cleanState = [ordered]@{
    done = [ordered]@{}
    config = [ordered]@{
        Process = 'ElementClient'
        OpenOffsetX = 0
        OpenOffsetY = 0
        CoordOffsetX = 0
        CoordOffsetY = 0
        DelayMs = 650
    }
}
$cleanState | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $stage 'state.json') -Encoding UTF8
$cleanCharacters = [ordered]@{ GamePath=''; DelaySeconds=4; Characters=[ordered]@{} }
$cleanCharacters | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $stage 'characters.json') -Encoding UTF8
New-Item -ItemType Directory -Path (Join-Path $stage 'macros') | Out-Null

if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
$hash = Get-FileHash -LiteralPath $zip -Algorithm SHA256
"$($hash.Hash)  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath (Join-Path $dist 'SHA256.txt') -Encoding ASCII
Write-Host "Готово: $zip"
Write-Host "SHA256: $($hash.Hash)"
