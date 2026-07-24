function Open-CyberPWLink([string]$Url){
  try{
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Url;$info.UseShellExecute=$true
    [Diagnostics.Process]::Start($info)|Out-Null
  }catch{
    [Windows.Forms.MessageBox]::Show("Не вдалося відкрити посилання.`r`n$Url",'CyberPW-Asistant')|Out-Null
  }
}

function Get-CyberPWThemeMode{
  $path=Join-Path $PSScriptRoot 'launcher-theme.json'
  try{$saved=Get-Content -Raw -Encoding UTF8 -LiteralPath $path|ConvertFrom-Json;if($saved.Mode-eq'Light'){return 'Light'}}catch{}
  'Dark'
}

function Set-CyberPWThemeMode([string]$Mode){
  $path=Join-Path $PSScriptRoot 'launcher-theme.json'
  try{[pscustomobject]@{Mode=$Mode}|ConvertTo-Json|Set-Content -Encoding UTF8 -LiteralPath $path}catch{}
}

function Get-CyberPWTheme{
  if((Get-CyberPWThemeMode)-eq'Light'){
    return [pscustomobject]@{
      Mode='Light';Base=[Drawing.Color]::FromArgb(246,243,234);Panel=[Drawing.Color]::FromArgb(237,232,218)
      Field=[Drawing.Color]::FromArgb(250,248,241);Button=[Drawing.Color]::FromArgb(214,207,188)
      Accent=[Drawing.Color]::FromArgb(0,123,105);AccentBright=[Drawing.Color]::FromArgb(18,151,128)
      Gold=[Drawing.Color]::FromArgb(181,132,31);GoldSoft=[Drawing.Color]::FromArgb(111,77,14)
      Text=[Drawing.Color]::FromArgb(29,52,45);Muted=[Drawing.Color]::FromArgb(91,115,106)
      Danger=[Drawing.Color]::FromArgb(166,57,49);Rare=[Drawing.Color]::FromArgb(39,101,164)
    }
  }
  [pscustomobject]@{
    Mode='Dark';Base=[Drawing.Color]::FromArgb(5,31,27);Panel=[Drawing.Color]::FromArgb(14,43,38)
    Field=[Drawing.Color]::FromArgb(9,55,47);Button=[Drawing.Color]::FromArgb(9,55,47)
    Accent=[Drawing.Color]::FromArgb(20,126,99);AccentBright=[Drawing.Color]::FromArgb(42,176,132)
    Gold=[Drawing.Color]::FromArgb(222,177,54);GoldSoft=[Drawing.Color]::FromArgb(255,225,143)
    Text=[Drawing.Color]::FromArgb(239,245,241);Muted=[Drawing.Color]::FromArgb(160,186,176)
    Danger=[Drawing.Color]::FromArgb(218,82,72);Rare=[Drawing.Color]::FromArgb(106,213,255)
  }
}

function Add-CyberPWThemeToggle($Form,[string]$ScriptPath){
  $theme=Get-CyberPWTheme
  $button=New-Object Windows.Forms.Button
  if($theme.Mode-eq'Light'){$button.Text='☾'}else{$button.Text='☀'}
  $button.SetBounds(($Form.ClientSize.Width-58),10,38,30);$button.Anchor='Top,Right'
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$theme.Gold
  $button.BackColor=$theme.Button;$button.ForeColor=$theme.GoldSoft;$button.Cursor='Hand'
  $button.Font=New-Object Drawing.Font('Segoe UI Symbol',10)
  $tip=New-Object Windows.Forms.ToolTip;$tip.SetToolTip($button,'Перемкнути тему')
  $button.Add_Click({
    $next=if((Get-CyberPWThemeMode)-eq'Light'){'Dark'}else{'Light'}
    Set-CyberPWThemeMode $next
    try{
      $Form.Close()
      Start-Sleep -Milliseconds 150
      Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$ScriptPath+'"')) -WorkingDirectory (Split-Path -Parent $ScriptPath)
    }catch{}
  })
  $Form.Controls.Add($button);$button.BringToFront();$button
}

function Add-CyberPWCommunityBar($Form){
  $theme=Get-CyberPWTheme
  $bar=New-Object Windows.Forms.FlowLayoutPanel
  $bar.Height=30;$bar.Dock='Bottom';$bar.WrapContents=$false
  $bar.FlowDirection='LeftToRight';$bar.Padding='12,3,0,0'
  $bar.BackColor=$theme.Base

  $links=@(
    @{Text='СЕРВЕР';Url='https://cyberpw.fun/';Width=135},
    @{Text='ФОРУМ';Url='https://forum.cyberpw.fun/';Width=135},
    @{Text='YOUTUBE';Url='https://www.youtube.com/@Vitalik_Juk';Width=145},
    @{Text='РЕЄСТРАЦІЯ + БОНУС';Url='https://cabinet.cyberpw.fun/register.php?ref=4550';Width=190}
  )
  foreach($link in $links){
    $control=New-Object Windows.Forms.LinkLabel
    $control.Text=$link.Text;$control.Width=[int]$link.Width;$control.Height=22
    $control.TextAlign='MiddleCenter';$control.LinkColor=$theme.Gold
    $control.ActiveLinkColor=$theme.GoldSoft
    $control.VisitedLinkColor=$control.LinkColor;$control.Cursor='Hand';$control.Tag=$link.Url
    $control.Font=New-Object Drawing.Font('Segoe UI Semibold',8)
    $control.Add_LinkClicked({Open-CyberPWLink ([string]$this.Tag)})
    [void]$bar.Controls.Add($control)
  }
  $Form.Controls.Add($bar);$bar.BringToFront()
  $bar
}
