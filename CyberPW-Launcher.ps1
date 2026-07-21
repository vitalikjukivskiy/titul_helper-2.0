$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LauncherNative {
  [DllImport("user32.dll")] public static extern bool ReleaseCapture();
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd,int msg,int wParam,int lParam);
}
'@

$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$AssistantPath=Join-Path $AppDir 'CyberPW-Titles.ps1'
$MultiLauncherPath=Join-Path $AppDir 'CyberPW-MultiLauncher.ps1'
$ChestSimulatorPath=Join-Path $AppDir 'CyberPW-ChestSimulator.ps1'
$LogoPath=Join-Path $AppDir 'cyberpw-logo.png'
$TitlesPath=Join-Path $AppDir 'titles.json'
$StatePath=Join-Path $AppDir 'state.json'

$jade=[Drawing.Color]::FromArgb(5,31,27)
$jade2=[Drawing.Color]::FromArgb(10,61,51)
$panel=[Drawing.Color]::FromArgb(222,7,26,23)
$gold=[Drawing.Color]::FromArgb(222,177,54)
$goldSoft=[Drawing.Color]::FromArgb(255,225,143)
$text=[Drawing.Color]::FromArgb(239,245,241)
$muted=[Drawing.Color]::FromArgb(167,190,181)
$cyan=[Drawing.Color]::FromArgb(42,214,183)

function Set-Rounded($control,[int]$radius){
  $path=New-Object Drawing.Drawing2D.GraphicsPath
  $d=$radius*2;$r=New-Object Drawing.Rectangle 0,0,($control.Width-1),($control.Height-1)
  $path.AddArc($r.Left,$r.Top,$d,$d,180,90);$path.AddArc($r.Right-$d,$r.Top,$d,$d,270,90)
  $path.AddArc($r.Right-$d,$r.Bottom-$d,$d,$d,0,90);$path.AddArc($r.Left,$r.Bottom-$d,$d,$d,90,90);$path.CloseFigure()
  $control.Region=New-Object Drawing.Region $path;$path.Dispose()
}
function Style-Button($button,$back,$fore=$text){
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$gold
  $button.BackColor=$back;$button.ForeColor=$fore;$button.Cursor='Hand';$button.Font=New-Object Drawing.Font('Segoe UI Semibold',10)
}
function Open-Link([string]$url){
  try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=$url;$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}
  catch{[Windows.Forms.MessageBox]::Show("Не вдалося відкрити посилання.`r`n$url")|Out-Null}
}
function New-TextLabel($value,$x,$y,$w,$h,$size,$color,$style='Regular'){
  $l=New-Object Windows.Forms.Label;$l.Text=$value;$l.SetBounds($x,$y,$w,$h);$l.ForeColor=$color;$l.BackColor=[Drawing.Color]::Transparent
  $l.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style);$l
}

$total=259;$done=0
try{$parsedTitles=Get-Content $TitlesPath -Raw -Encoding UTF8|ConvertFrom-Json;$total=@($parsedTitles).Count}catch{}
try{$s=Get-Content $StatePath -Raw -Encoding UTF8|ConvertFrom-Json;$done=@($s.done.PSObject.Properties|Where-Object Value -eq $true).Count}catch{}

$form=New-Object Windows.Forms.Form
$form.Text='Cyber.pw Asistant';$form.FormBorderStyle='None';$form.Size='1080,620';$form.StartPosition='CenterScreen'
$form.BackColor=$jade;$form.ForeColor=$text;$form.Font=New-Object Drawing.Font('Segoe UI',10);$form.MaximizeBox=$false
$form.Add_Shown({Set-Rounded $form 18})
$form.Add_Paint({
  param($sender,$e)
  $rect=New-Object Drawing.Rectangle 0,0,$form.Width,$form.Height
  $bg=New-Object Drawing.Drawing2D.LinearGradientBrush $rect,$jade,$jade2,18
  $e.Graphics.FillRectangle($bg,$rect);$bg.Dispose()
  $glow=New-Object Drawing.Drawing2D.GraphicsPath
  $glow.AddEllipse(650,-230,650,650)
  $glowBrush=New-Object Drawing.Drawing2D.PathGradientBrush $glow
  $glowBrush.CenterColor=[Drawing.Color]::FromArgb(80,35,210,159);$glowBrush.SurroundColors=@([Drawing.Color]::FromArgb(0,5,31,27))
  $e.Graphics.FillPath($glowBrush,$glow);$glowBrush.Dispose();$glow.Dispose()
  $pen=New-Object Drawing.Pen $gold,2;$e.Graphics.DrawLine($pen,32,142,1048,142);$e.Graphics.DrawLine($pen,32,568,1048,568);$pen.Dispose()
  $thin=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(90,42,214,183)),1
  for($i=0;$i-lt6;$i++){$e.Graphics.DrawLine($thin,700+$i*34,150,1035,485-$i*14)};$thin.Dispose()
})

$drag={if($_.Button-eq[Windows.Forms.MouseButtons]::Left){[LauncherNative]::ReleaseCapture()|Out-Null;[LauncherNative]::SendMessage($form.Handle,0xA1,2,0)|Out-Null}}
$form.Add_MouseDown($drag)

$close=New-Object Windows.Forms.Button;$close.Text='×';$close.SetBounds(1023,13,40,34);Style-Button $close ([Drawing.Color]::FromArgb(75,25,23)) $goldSoft;$close.Font=New-Object Drawing.Font('Segoe UI',16,[Drawing.FontStyle]::Bold);$close.Add_Click({$form.Close()});Set-Rounded $close 9
$min=New-Object Windows.Forms.Button;$min.Text='—';$min.SetBounds(977,13,40,34);Style-Button $min ([Drawing.Color]::FromArgb(8,48,41)) $goldSoft;$min.Add_Click({$form.WindowState='Minimized'});Set-Rounded $min 9

$logo=New-Object Windows.Forms.PictureBox;$logo.SetBounds(310,10,460,128);$logo.SizeMode='Zoom';$logo.BackColor=[Drawing.Color]::Transparent
if(Test-Path $LogoPath){$src=[Drawing.Image]::FromFile($LogoPath);$logo.Image=New-Object Drawing.Bitmap $src;$src.Dispose()}
$logo.Add_MouseDown($drag)

$nav=@(
  @{Text='САЙТ';Url='https://cyberpw.fun/'},
  @{Text='КАБІНЕТ';Url='https://cabinet.cyberpw.fun/'},
  @{Text='РЕЄСТРАЦІЯ + БОНУС';Url='https://cabinet.cyberpw.fun/register.php?ref=4550'},
  @{Text='YOUTUBE';Url='https://www.youtube.com/@Vitalik_Juk'}
)
$navButtons=@();$navX=115
foreach($item in $nav){
  $b=New-Object Windows.Forms.Button;$b.Text=$item.Text;$b.SetBounds($navX,158,205,42);Style-Button $b ([Drawing.Color]::FromArgb(9,49,42)) $goldSoft;Set-Rounded $b 11
  $url=$item.Url;$b.Add_Click({Open-Link $this.Tag});$b.Tag=$url;$navButtons+=,$b;$navX+=215
}

$tab=New-Object Windows.Forms.Button;$tab.Text='◆  TITULHELPER';$tab.SetBounds(48,207,220,34);Style-Button $tab ([Drawing.Color]::FromArgb(20,113,91)) ([Drawing.Color]::White);$tab.Font=New-Object Drawing.Font('Segoe UI Semibold',10);Set-Rounded $tab 10
$multiTab=New-Object Windows.Forms.Button;$multiTab.Text='◆  MULTILAUNCHER';$multiTab.SetBounds(278,207,220,34);Style-Button $multiTab ([Drawing.Color]::FromArgb(9,49,42)) $goldSoft;$multiTab.Font=New-Object Drawing.Font('Segoe UI Semibold',10);Set-Rounded $multiTab 10
$multiTab.Add_Click({
  if(-not(Test-Path $MultiLauncherPath)){[Windows.Forms.MessageBox]::Show('Не знайдено CyberPW-MultiLauncher.ps1')|Out-Null;return}
  try{Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$MultiLauncherPath+'"')) -WorkingDirectory $AppDir;$form.Close()}
  catch{[Windows.Forms.MessageBox]::Show("Не вдалося запустити MultiLauncher.`r`n$($_.Exception.Message)")|Out-Null}
})
$chestTab=New-Object Windows.Forms.Button;$chestTab.Text='◆  СИМУЛЯТОР · BETA';$chestTab.SetBounds(508,207,240,34);Style-Button $chestTab ([Drawing.Color]::FromArgb(126,85,15)) ([Drawing.Color]::White);$chestTab.Font=New-Object Drawing.Font('Segoe UI Semibold',10);Set-Rounded $chestTab 10
$chestTab.Add_Click({
  if(-not(Test-Path $ChestSimulatorPath)){[Windows.Forms.MessageBox]::Show('Не знайдено CyberPW-ChestSimulator.ps1')|Out-Null;return}
  try{Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$ChestSimulatorPath+'"')) -WorkingDirectory $AppDir;$form.Close()}
  catch{[Windows.Forms.MessageBox]::Show("Не вдалося запустити симулятор.`r`n$($_.Exception.Message)")|Out-Null}
})
$left=New-Object Windows.Forms.Panel;$left.SetBounds(48,250,600,290);$left.BackColor=$panel;Set-Rounded $left 18
$eyebrow=New-TextLabel 'CYBER.PW ASISTANT' 28 18 520 24 10 $cyan 'Bold'
$headline=New-TextLabel 'TITULHELPER' 26 44 540 52 27 $goldSoft 'Bold'
$desc=New-TextLabel "Автоматичне сканування отриманих титулів,`r`nпідсвічування прогресу та встановлення міток`r`nіз координатами прямо у CyberPW." 30 110 530 76 11 $text
$launch=New-Object Windows.Forms.Button;$launch.Text='▶  ЗАПУСТИТИ TITULHELPER';$launch.SetBounds(28,203,544,60);Style-Button $launch ([Drawing.Color]::FromArgb(18,126,98)) ([Drawing.Color]::White);$launch.Font=New-Object Drawing.Font('Segoe UI Semibold',14);Set-Rounded $launch 15
$launch.Add_Click({
  if(-not(Test-Path $AssistantPath)){[Windows.Forms.MessageBox]::Show('Не знайдено CyberPW-Titles.ps1')|Out-Null;return}
  try{Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$AssistantPath+'"')) -WorkingDirectory $AppDir;$form.Close()}
  catch{[Windows.Forms.MessageBox]::Show("Не вдалося запустити асистент.`r`n$($_.Exception.Message)")|Out-Null}
})
$left.Controls.AddRange(@($eyebrow,$headline,$desc,$launch))

$right=New-Object Windows.Forms.Panel;$right.SetBounds(678,250,354,290);$right.BackColor=$panel;Set-Rounded $right 18
$statusTitle=New-TextLabel 'СТАН ПРОФІЛЮ' 24 22 300 25 10 $muted 'Bold'
$count=New-TextLabel "$done / $total" 23 48 300 58 29 $goldSoft 'Bold'
$status=New-TextLabel 'титулів позначено у програмі' 26 103 300 25 10 $muted
$barBack=New-Object Windows.Forms.Panel;$barBack.SetBounds(26,139,302,12);$barBack.BackColor=[Drawing.Color]::FromArgb(4,18,16);Set-Rounded $barBack 6
$bar=New-Object Windows.Forms.Panel;$bar.SetBounds(0,0,[Math]::Max(8,[int](302*$done/[Math]::Max(1,$total))),12);$bar.BackColor=$cyan;Set-Rounded $bar 6;$barBack.Controls.Add($bar)
$support=New-Object Windows.Forms.Button;$support.Text='💛  ПІДТРИМАТИ · MONOBANK';$support.SetBounds(26,167,302,50);Style-Button $support ([Drawing.Color]::FromArgb(126,85,15)) ([Drawing.Color]::White);$support.Font=New-Object Drawing.Font('Segoe UI Semibold',11);Set-Rounded $support 13
$support.Add_Click({Open-Link 'https://send.monobank.ua/jar/93N5FBB3zX'})
$credit=New-TextLabel "Створив Кіт Михайло`r`nCyber.pw · клан DarkSide" 26 229 302 48 9 $muted
$right.Controls.AddRange(@($statusTitle,$count,$status,$barBack,$support,$credit))

$footer=New-TextLabel 'CYBER.PW ASISTANT  •  TITULHELPER  •  MULTILAUNCHER  •  СИМУЛЯТОР СКРИНІ' 48 580 984 24 9 $muted 'Bold';$footer.TextAlign='MiddleCenter'
$form.Controls.AddRange(@($logo,$close,$min,$tab,$multiTab,$chestTab,$left,$right,$footer)+$navButtons)
$form.Add_FormClosed({if($logo.Image){$logo.Image.Dispose()}})
[void]$form.ShowDialog()
