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
    'CyberPW-Titles.ps1',
    'titles.json',
    'ocr-rules.json',
    'cyberpw-logo.png',
    'Запустити.bat',
    'Встановити-OCR.ps1',
    'Встановити OCR.bat'
)
foreach ($name in $files) {
    $source = Join-Path $root $name
    if (-not (Test-Path $source)) { throw "Не знайдено обов'язковий файл: $name" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $stage $name)
}
Copy-Item -LiteralPath (Join-Path $root 'README-PORTABLE.md') -Destination (Join-Path $stage 'README.md')

$cleanState = [ordered]@{
    done = [ordered]@{}
    config = [ordered]@{
        ProcessName = 'ElementClient'
        OffsetX = 0
        OffsetY = 0
        TitleOffsetX = 0
        TitleOffsetY = 0
        DelayMs = 650
    }
}
$cleanState | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $stage 'state.json') -Encoding UTF8

if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
$hash = Get-FileHash -LiteralPath $zip -Algorithm SHA256
"$($hash.Hash)  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath (Join-Path $dist 'SHA256.txt') -Encoding ASCII
Write-Host "Готово: $zip"
Write-Host "SHA256: $($hash.Hash)"
