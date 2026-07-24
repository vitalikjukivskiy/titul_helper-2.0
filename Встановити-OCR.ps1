$ErrorActionPreference = 'Stop'

if([Environment]::OSVersion.Version.Major-eq6-and[Environment]::OSVersion.Version.Minor-eq1){
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show('Windows 7 не містить системного Windows OCR. CyberPW-Asistant працюватиме без автоматичного OCR-сканування; інші функції залишаються доступними.','CyberPW-Asistant')|Out-Null
    exit 0
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $MyInvocation.MyCommand.Path + '"'))
    exit
}

$wanted = @('Language.OCR~~~ru-RU~0.0.1.0','Language.OCR~~~uk-UA~0.0.1.0')
$available = @(Get-WindowsCapability -Online | Where-Object { $_.Name -like 'Language.OCR*' })
foreach ($name in $wanted) {
    $capability = $available | Where-Object Name -eq $name | Select-Object -First 1
    if ($capability -and $capability.State -ne 'Installed') {
        Write-Host "Встановлення $name ..."
        Add-WindowsCapability -Online -Name $name | Out-Null
    }
}

$ru = Get-WindowsCapability -Online -Name 'Language.OCR~~~ru-RU~0.0.1.0'
if ($ru.State -ne 'Installed') { throw 'Не вдалося встановити російський OCR.' }
Add-Type -AssemblyName PresentationFramework
[Windows.MessageBox]::Show('OCR установлено. Тепер перезапустіть Cyber.pw Asistant.','Cyber.pw Asistant') | Out-Null
