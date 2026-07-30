$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $root 'src\CyberPW.Assistant2'
$output = Join-Path $root 'dist-csharp-2.0-beta'
$exe = Join-Path $output 'CyberPW Assistant 2 Beta.exe'

$cscCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe')
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $csc) { throw 'Не знайдено C# compiler .NET Framework 4.x.' }

if (Test-Path -LiteralPath $output) {
    $resolvedRoot = [IO.Path]::GetFullPath($root).TrimEnd('\')
    $resolvedOutput = [IO.Path]::GetFullPath($output)
    if (-not $resolvedOutput.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Небезпечний шлях папки C# складання.'
    }
    Remove-Item -LiteralPath $output -Recurse -Force
}

New-Item -ItemType Directory -Path $output | Out-Null
New-Item -ItemType Directory -Path (Join-Path $output 'data') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $output 'macros') | Out-Null

$sources = @(Get-ChildItem -LiteralPath $source -Filter '*.cs' -File | ForEach-Object FullName)
if (-not $sources.Count) { throw 'Не знайдено C# source files.' }

& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
    /reference:System.dll `
    /reference:System.Core.dll `
    /reference:System.Drawing.dll `
    /reference:System.Windows.Forms.dll `
    /reference:System.Web.Extensions.dll `
    /reference:System.Security.dll `
    "/win32icon:$(Join-Path $root 'cyberpw-logo.ico')" `
    "/out:$exe" `
    $sources

if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw 'Не вдалося зібрати CyberPW Assistant 2.0 Beta.'
}
$updaterSource = Join-Path $root 'src\CyberPW.Updater\Program.cs'
$updaterExe = Join-Path $output 'CyberPW Updater.exe'
& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
    /reference:System.dll `
    /reference:System.Core.dll `
    /reference:System.IO.Compression.dll `
    /reference:System.IO.Compression.FileSystem.dll `
    /reference:System.Windows.Forms.dll `
    "/win32icon:$(Join-Path $root 'cyberpw-logo.ico')" `
    "/out:$updaterExe" `
    $updaterSource
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $updaterExe -PathType Leaf)) {
    throw 'Не вдалося зібрати CyberPW Updater.'
}

foreach ($name in @('titles.json', 'memory-offsets.json', 'state.json', 'chest-drops.json', 'bosses.json')) {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path (Join-Path $output 'data') $name)
}
Copy-Item -LiteralPath (Join-Path $root 'cyberpw-logo.ico') -Destination (Join-Path $output 'cyberpw-logo.ico')
Copy-Item -LiteralPath (Join-Path $root 'ui-assets') -Destination (Join-Path $output 'ui-assets') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'cyberpw-logo.png') -Destination (Join-Path $output 'cyberpw-logo.png')
Copy-Item -LiteralPath (Join-Path $root 'loot-icons') -Destination (Join-Path $output 'loot-icons') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'class-icons') -Destination (Join-Path $output 'class-icons') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'README-PORTABLE.md') -Destination (Join-Path $output 'README-PORTABLE.md')
Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination (Join-Path $output 'VERSION')

Write-Output "C# Beta готова: $exe"
