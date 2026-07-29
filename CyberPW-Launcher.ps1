$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if($PSVersionTable.PSVersion.Major-lt5){
  [Windows.Forms.MessageBox]::Show('Для CyberPW Assistant потрібен Windows PowerShell 5.1. На Windows 7 встановіть Windows Management Framework 5.1 і запустіть програму повторно.','Потрібен PowerShell 5.1')|Out-Null
  exit
}

$nativeSource=@'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class LauncherNative {
  [DllImport("user32.dll")] public static extern bool ReleaseCapture();
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd,int msg,int wParam,int lParam);
}
public sealed class ResizableBorderlessForm : Form {
  [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  private struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  private const int WM_NCHITTEST=0x84, HTCLIENT=1, HTLEFT=10, HTRIGHT=11, HTTOP=12;
  private const int HTTOPLEFT=13, HTTOPRIGHT=14, HTBOTTOM=15, HTBOTTOMLEFT=16, HTBOTTOMRIGHT=17;
  private readonly int grip=9;
  protected override CreateParams CreateParams {
    get {
      const int WS_THICKFRAME=0x00040000;
      const int WS_MAXIMIZEBOX=0x00010000;
      CreateParams parameters=base.CreateParams;
      parameters.Style|=WS_THICKFRAME|WS_MAXIMIZEBOX;
      return parameters;
    }
  }
  protected override void WndProc(ref Message message) {
    if(message.Msg==WM_NCHITTEST && WindowState==FormWindowState.Normal) {
      RECT rect;
      if(GetWindowRect(Handle,out rect)) {
        long value=message.LParam.ToInt64();
        int x=(short)(value&0xffff), y=(short)((value>>16)&0xffff);
        bool left=x<rect.Left+grip, right=x>=rect.Right-grip;
        bool top=y<rect.Top+grip, bottom=y>=rect.Bottom-grip;
        if(left&&top) { message.Result=(IntPtr)HTTOPLEFT; return; }
        if(right&&top) { message.Result=(IntPtr)HTTOPRIGHT; return; }
        if(left&&bottom) { message.Result=(IntPtr)HTBOTTOMLEFT; return; }
        if(right&&bottom) { message.Result=(IntPtr)HTBOTTOMRIGHT; return; }
        if(left) { message.Result=(IntPtr)HTLEFT; return; }
        if(right) { message.Result=(IntPtr)HTRIGHT; return; }
        if(top) { message.Result=(IntPtr)HTTOP; return; }
        if(bottom) { message.Result=(IntPtr)HTBOTTOM; return; }
      }
    }
    base.WndProc(ref message);
  }
}
'@
Add-Type -TypeDefinition $nativeSource -ReferencedAssemblies @('System.Windows.Forms.dll','System.Drawing.dll')

$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'CyberPW-Common.ps1')
$AssistantPath=Join-Path $AppDir 'CyberPW-Titles.ps1'
$MultiLauncherPath=Join-Path $AppDir 'CyberPW-MultiLauncher.ps1'
$ChestSimulatorPath=Join-Path $AppDir 'CyberPW-ChestSimulator.ps1'
$UnfreezePath=Join-Path $AppDir 'CyberPW-Unfreeze.ps1'
$WorldBossesPath=Join-Path $AppDir 'CyberPW-WorldBosses.ps1'
$TerritoryMapPath=Join-Path $AppDir 'CyberPW-TerritoryMap.ps1'
$MacroStudioPath=Join-Path $AppDir 'CyberPW-MacroStudio.ps1'
$LogoPath=Join-Path $AppDir 'cyberpw-logo.png'
$HeaderPath=Join-Path $AppDir 'github-header-kitmikhailo.png'
$TitlesPath=Join-Path $AppDir 'titles.json'
$StatePath=Join-Path $AppDir 'state.json'
$ThemePath=Join-Path $AppDir 'launcher-theme.json'
$SummerAssetPath=Join-Path $AppDir 'ui-assets\summer'
$IconAssetPath=Join-Path $AppDir 'ui-assets\icons'
$MainBackgroundPath=Join-Path $AppDir 'ui-assets\main-summer.jpg'
$script:cardImages=@()

function Set-ThemePalette([string]$mode){
  if($mode-eq'Light'){
    $script:ink=[Drawing.Color]::FromArgb(246,243,234)
    $script:jade=[Drawing.Color]::FromArgb(229,224,210)
    $script:jade2=[Drawing.Color]::FromArgb(214,207,188)
    $script:jade3=[Drawing.Color]::FromArgb(197,188,163)
    $script:panel=[Drawing.Color]::FromArgb(250,248,241)
    $script:panelSoft=[Drawing.Color]::FromArgb(237,232,218)
    $script:gold=[Drawing.Color]::FromArgb(181,132,31)
    $script:goldSoft=[Drawing.Color]::FromArgb(111,77,14)
    $script:text=[Drawing.Color]::FromArgb(29,52,45)
    $script:muted=[Drawing.Color]::FromArgb(91,115,106)
    $script:cyan=[Drawing.Color]::FromArgb(0,123,105)
    $script:danger=[Drawing.Color]::FromArgb(166,57,49)
    $script:CalendarRowA=[Drawing.Color]::FromArgb(247,244,235)
    $script:CalendarRowB=[Drawing.Color]::FromArgb(235,230,216)
  }else{
    $script:ink=[Drawing.Color]::FromArgb(3,17,15)
    $script:jade=[Drawing.Color]::FromArgb(5,31,27)
    $script:jade2=[Drawing.Color]::FromArgb(8,47,40)
    $script:jade3=[Drawing.Color]::FromArgb(12,69,57)
    $script:panel=[Drawing.Color]::FromArgb(10,38,33)
    $script:panelSoft=[Drawing.Color]::FromArgb(16,52,45)
    $script:gold=[Drawing.Color]::FromArgb(222,177,54)
    $script:goldSoft=[Drawing.Color]::FromArgb(255,225,143)
    $script:text=[Drawing.Color]::FromArgb(239,245,241)
    $script:muted=[Drawing.Color]::FromArgb(158,184,174)
    $script:cyan=[Drawing.Color]::FromArgb(42,214,183)
    $script:danger=[Drawing.Color]::FromArgb(218,82,72)
    $script:CalendarRowA=[Drawing.Color]::FromArgb(15,42,36)
    $script:CalendarRowB=[Drawing.Color]::FromArgb(18,49,41)
  }
  $script:CalendarGold=$script:gold
  $script:CalendarInk=$script:ink
  $script:CalendarJade=$script:jade2
  $script:CalendarMuted=$script:muted
  $script:CalendarText=$script:text
}
$script:ThemeMode='Dark'
Set-ThemePalette $script:ThemeMode

function Set-Rounded($control,[int]$radius){
  if($control.Width-le1-or$control.Height-le1){return}
  $path=New-Object Drawing.Drawing2D.GraphicsPath;$diameter=$radius*2
  $rect=New-Object Drawing.Rectangle 0,0,($control.Width-1),($control.Height-1)
  $path.AddArc($rect.Left,$rect.Top,$diameter,$diameter,180,90)
  $path.AddArc($rect.Right-$diameter,$rect.Top,$diameter,$diameter,270,90)
  $path.AddArc($rect.Right-$diameter,$rect.Bottom-$diameter,$diameter,$diameter,0,90)
  $path.AddArc($rect.Left,$rect.Bottom-$diameter,$diameter,$diameter,90,90)
  $path.CloseFigure();$control.Region=New-Object Drawing.Region $path;$path.Dispose()
}
function Style-Button($button,$back,$fore=$text,[int]$size=9){
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$gold
  $button.BackColor=$back;$button.ForeColor=$fore;$button.Cursor='Hand'
  $button.Font=New-Object Drawing.Font('Segoe UI Semibold',$size)
  $button.Add_MouseEnter({if($this.Enabled){$this.BackColor=$jade3;$this.ForeColor=$goldSoft}})
  $button.Add_MouseLeave({if($this.Enabled){$this.BackColor=$this.Tag.Back;$this.ForeColor=$this.Tag.Fore}})
  $button.Tag=[pscustomobject]@{Back=$back;Fore=$fore}
}
function New-Label($value,$x,$y,$w,$h,$size,$color,$style='Regular'){
  $label=New-Object Windows.Forms.Label;$label.Text=$value;$label.SetBounds($x,$y,$w,$h)
  $label.ForeColor=$color;$label.BackColor=[Drawing.Color]::Transparent
  $label.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style)
  $label
}
function Convert-ThemeColor($color,$oldPalette,$newPalette){
  if($null-eq$color){return $color}
  foreach($name in @('Ink','Jade','Jade2','Jade3','Panel','PanelSoft','Gold','GoldSoft','Text','Muted','Cyan','Danger','RowA','RowB')){
    if($color.ToArgb()-eq$oldPalette[$name].ToArgb()){return $newPalette[$name]}
  }
  $color
}
function Get-ThemePaletteSnapshot{
  @{
    Ink=$script:ink;Jade=$script:jade;Jade2=$script:jade2;Jade3=$script:jade3
    Panel=$script:panel;PanelSoft=$script:panelSoft;Gold=$script:gold;GoldSoft=$script:goldSoft
    Text=$script:text;Muted=$script:muted;Cyan=$script:cyan;Danger=$script:danger
    RowA=$script:CalendarRowA;RowB=$script:CalendarRowB
  }
}
function Apply-LauncherTheme([string]$mode){
  $oldPalette=Get-ThemePaletteSnapshot
  Set-ThemePalette $mode
  $newPalette=Get-ThemePaletteSnapshot
  $queue=New-Object Collections.Queue;$queue.Enqueue($form)
  while($queue.Count){
    $control=$queue.Dequeue()
    $control.BackColor=Convert-ThemeColor $control.BackColor $oldPalette $newPalette
    $control.ForeColor=Convert-ThemeColor $control.ForeColor $oldPalette $newPalette
    if($control-is[Windows.Forms.Button]){
      $control.FlatAppearance.BorderColor=$script:gold
      if($control.Tag-and$control.Tag.PSObject.Properties['Back']){
        $control.Tag.Back=Convert-ThemeColor $control.Tag.Back $oldPalette $newPalette
        $control.Tag.Fore=Convert-ThemeColor $control.Tag.Fore $oldPalette $newPalette
      }
    }
    foreach($child in $control.Controls){$queue.Enqueue($child)}
    $control.Invalidate()
  }
  $eventList.BackColor=$script:CalendarRowA
  $calendarAccent.BackColor=$script:gold
  $script:ThemeMode=$mode
  try{[pscustomobject]@{Mode=$mode}|ConvertTo-Json|Set-Content -Encoding UTF8 -LiteralPath $ThemePath}catch{}
  Update-EventCalendar
  $form.Invalidate($true)
}
function Open-Link([string]$url){
  try{$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$url;$start.UseShellExecute=$true;[Diagnostics.Process]::Start($start)|Out-Null}
  catch{[Windows.Forms.MessageBox]::Show("Не вдалося відкрити посилання.`r`n$url",'CyberPW Assistant')|Out-Null}
}
function Start-Module([string]$path,[string]$name){
  if(-not(Test-Path -LiteralPath $path)){[Windows.Forms.MessageBox]::Show("Не знайдено $([IO.Path]::GetFileName($path)).",'CyberPW Assistant')|Out-Null;return}
  try{
    $starter=Join-Path $AppDir 'CyberPW Assistant.exe'
    Start-Process $starter -ArgumentList @(('"'+$path+'"')) -WorkingDirectory $AppDir
    $form.Close()
  }catch{[Windows.Forms.MessageBox]::Show("Не вдалося запустити $name.`r`n$($_.Exception.Message)",'CyberPW Assistant')|Out-Null}
}
function Get-LauncherImage([string]$file,[int]$width=0,[int]$height=0){
  if(-not$file-or-not(Test-Path -LiteralPath $file)){return $null};$source=[Drawing.Image]::FromFile($file)
  try{if($width-gt0-and$height-gt0){$copy=New-Object Drawing.Bitmap $width,$height;$graphics=[Drawing.Graphics]::FromImage($copy);try{$graphics.InterpolationMode='HighQualityBicubic';$graphics.DrawImage($source,0,0,$width,$height)}finally{$graphics.Dispose()};return $copy};return (New-Object Drawing.Bitmap $source)}finally{$source.Dispose()}
}
function New-NavButton($caption,$imageFile,$y,$action){
  $button=New-Object Windows.Forms.Button;$button.Text=$caption;$button.TextAlign='MiddleLeft';$button.ImageAlign='MiddleLeft';$button.TextImageRelation='ImageBeforeText';$button.SetBounds(18,$y,194,44);$button.Padding='10,0,8,0';Style-Button $button $jade2 $goldSoft 9;Set-Rounded $button 10
  $button.Image=Get-LauncherImage $imageFile 26 26;if($button.Image){$script:cardImages+=,$button.Image};$button.Add_Click($action);$button
}
function New-ModuleCard($title,$description,$statusText,$statusColor,$backgroundFile,$path,$moduleName){
  $card=New-Object Windows.Forms.Panel;$card.Size='190,150';$card.Dock='Fill';$card.Margin='6,0,6,0';$card.BackColor=$panelSoft
  $card.BackgroundImage=Get-LauncherImage $backgroundFile;if($card.BackgroundImage){$script:cardImages+=,$card.BackgroundImage;$card.BackgroundImageLayout='Stretch'}
  $card.Add_Paint({param($sender,$eventArgs);$rect=New-Object Drawing.Rectangle 0,0,$sender.Width,$sender.Height;$from=[Drawing.Color]::FromArgb(225,4,31,27);$to=[Drawing.Color]::FromArgb(145,7,62,51);$shade=New-Object Drawing.Drawing2D.LinearGradientBrush $rect,$from,$to,14;$eventArgs.Graphics.FillRectangle($shade,$rect);$shade.Dispose();$pen=New-Object Drawing.Pen $gold,1;$eventArgs.Graphics.DrawRectangle($pen,0,0,$sender.Width-1,$sender.Height-1);$pen.Dispose()})
  $heading=New-Label $title 10 5 170 24 9 $goldSoft 'Bold';$heading.TextAlign='MiddleCenter';$heading.Anchor='Top,Left,Right';$desc=New-Label $description 20 33 150 38 8 $text;$desc.TextAlign='TopCenter';$desc.Anchor='Top,Left,Right'
  $iconFile=Join-Path $IconAssetPath ([IO.Path]::GetFileName($backgroundFile));$cardIcon=New-Object Windows.Forms.PictureBox;$cardIcon.Size='86,86';$cardIcon.SizeMode='Zoom';$cardIcon.BackColor=[Drawing.Color]::Transparent;$cardIcon.Image=Get-LauncherImage $iconFile 86 86;if($cardIcon.Image){$script:cardImages+=,$cardIcon.Image};$card.Tag=[pscustomobject]@{Icon=$cardIcon};$card.Add_Resize({$picture=$this.Tag.Icon;$space=$this.ClientSize.Height-147;if($space-ge64){$size=[Math]::Min(86,$space-10);$picture.Size=New-Object Drawing.Size $size,$size;$picture.Left=[int](($this.ClientSize.Width-$size)/2);$picture.Top=72+[int](($space-$size)/2);$picture.Visible=$true}else{$picture.Visible=$false}})
  $dot=New-Label '●' 14 83 17 20 9 $statusColor 'Bold';$state=New-Label $statusText 32 83 146 22 8 $text;$state.Anchor='Bottom,Left,Right';$dot.Anchor='Bottom,Left'
  $open=New-Object Windows.Forms.Button;$open.Text='ВІДКРИТИ';$open.SetBounds(12,109,166,30);$open.Anchor='Bottom,Left,Right';$buttonBack=[Drawing.Color]::FromArgb(190,5,45,38);Style-Button $open $buttonBack $goldSoft 8;Set-Rounded $open 8;$open.Tag=[pscustomobject]@{Back=$buttonBack;Fore=$goldSoft;Path=$path;Name=$moduleName};$open.Add_Click({Start-Module $this.Tag.Path $this.Tag.Name})
  $card.Controls.AddRange(@($heading,$desc,$cardIcon,$dot,$state,$open));$card
}
$total=260;$done=0
try{
  $titleData=Get-Content -Raw -Encoding UTF8 -LiteralPath $TitlesPath|ConvertFrom-Json
  if($null-ne$titleData-and[int]$titleData.Count-gt0){$total=[int]$titleData.Count}
}catch{}
try{$stateData=Get-Content -Raw -Encoding UTF8 -LiteralPath $StatePath|ConvertFrom-Json;$done=@($stateData.done.PSObject.Properties|Where-Object Value -eq $true).Count}catch{}

$eventSchedule=@(
  [pscustomobject]@{Day=1;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=1;Name='Світовий бос Інгримунд (346 522)';Time='10 хв після АТН';Starts=@()},
  [pscustomobject]@{Day=1;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=1;Name='Атака тигрів небожителів';Time='21:00';Starts=@('21:00')},
  [pscustomobject]@{Day=2;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=2;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=2;Name='Світові боси';Time='20:00';Starts=@('20:00')},
  [pscustomobject]@{Day=2;Name='Хроно боси';Time='20:00';Starts=@('20:00')},
  [pscustomobject]@{Day=2;Name='Руїни в джунглях';Time='20:00';Starts=@('20:00')},
  [pscustomobject]@{Day=2;Name='Світовий бос Інгримунд (349 523)';Time='20:40';Starts=@('20:40')},
  [pscustomobject]@{Day=3;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=3;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=3;Name='Початок ставок';Time='19:00';Starts=@('19:00')},
  [pscustomobject]@{Day=3;Name='Місто Темних звірів';Time='21:00';Starts=@('21:00')},
  [pscustomobject]@{Day=4;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=4;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=4;Name='Закінчення ставок';Time='19:00';Starts=@('19:00')},
  [pscustomobject]@{Day=4;Name='Конкурс ремісників';Time='20:00';Starts=@('20:00')},
  [pscustomobject]@{Day=4;Name='Світові боси · Хроно боси';Time='20:00';Starts=@('20:00')},
  [pscustomobject]@{Day=4;Name='Світовий бос Ейнгард (107 470)';Time='21:40';Starts=@('21:40')},
  [pscustomobject]@{Day=5;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=5;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=5;Name='Битва Династій';Time='20:20–21:20';Starts=@('20:20')},
  [pscustomobject]@{Day=6;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=6;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=6;Name='Територіальні війни';Time='19:00–19:18 · 21:00–21:18';Starts=@('19:00','21:00')},
  [pscustomobject]@{Day=6;Name='Битва Орденів (Морай)';Time='19:00–22:00';Starts=@('19:00')},
  [pscustomobject]@{Day=7;Name='Скачки на острові змій';Time='12:20 · 21:20';Starts=@('12:20','21:20')},
  [pscustomobject]@{Day=7;Name='Територіальні війни';Time='18:00–18:18 · 19:00–19:18';Starts=@('18:00','19:00')},
  [pscustomobject]@{Day=7;Name='Плато Асурів';Time='19:00–19:30';Starts=@('19:00')},
  [pscustomobject]@{Day=7;Name='Битва Династій';Time='20:20–21:20';Starts=@('20:20')},
  [pscustomobject]@{Day=7;Name='Замок Царя Драконів';Time='21:30';Starts=@('21:30')}
)
$dayNames=@('Понеділок','Вівторок','Середа','Четвер',"П’ятниця",'Субота','Неділя')
$dayShort=@('ПН','ВТ','СР','ЧТ','ПТ','СБ','НД')

$form=New-Object ResizableBorderlessForm
$form.Text='CyberPW Assistant 1.07 Beta 2';$form.FormBorderStyle='None';$form.Size='1280,800';$form.MinimumSize='1080,720'
$form.StartPosition='CenterScreen';$form.BackColor=$ink;$form.ForeColor=$text;$form.Font=New-Object Drawing.Font('Segoe UI',9)
$form.BackgroundImage=Get-LauncherImage $MainBackgroundPath;if($form.BackgroundImage){$script:cardImages+=,$form.BackgroundImage;$form.BackgroundImageLayout='Stretch'}
$form.AutoScaleMode='Dpi';$form.AutoScroll=$true
$form.Add_Shown({Set-Rounded $form 16})
$form.Add_SizeChanged({
  if($form.WindowState-eq[Windows.Forms.FormWindowState]::Maximized){$form.Region=$null;if($maximize){$maximize.Text='❐'}}
  else{Set-Rounded $form 16;if($maximize){$maximize.Text='□'}}
})
$drag={if($_.Button-eq[Windows.Forms.MouseButtons]::Left){[LauncherNative]::ReleaseCapture()|Out-Null;[LauncherNative]::SendMessage($form.Handle,0xA1,2,0)|Out-Null}}
$form.Add_MouseDown($drag)
$form.Add_Paint({
  param($sender,$eventArgs)
  $rect=New-Object Drawing.Rectangle 0,0,$form.Width,$form.Height
  $brush=New-Object Drawing.Drawing2D.LinearGradientBrush $rect,([Drawing.Color]::FromArgb(210,$ink)),([Drawing.Color]::FromArgb(195,$jade2)),15
  $eventArgs.Graphics.FillRectangle($brush,$rect);$brush.Dispose()
  $pen=New-Object Drawing.Pen $gold,2;$eventArgs.Graphics.DrawRectangle($pen,1,1,$form.Width-3,$form.Height-3);$pen.Dispose()
})

$sidebar=New-Object Windows.Forms.Panel;$sidebar.SetBounds(2,2,230,796);$sidebar.Anchor='Top,Bottom,Left';$sidebar.BackColor=$jade
$sidebar.Add_MouseDown($drag)
$brandLogo=New-Object Windows.Forms.PictureBox;$brandLogo.SetBounds(26,20,178,92);$brandLogo.SizeMode='Zoom';$brandLogo.BackColor=[Drawing.Color]::Transparent
if(Test-Path $LogoPath){$logoSource=[Drawing.Image]::FromFile($LogoPath);$brandLogo.Image=New-Object Drawing.Bitmap $logoSource;$logoSource.Dispose()}
$brandLogo.Add_MouseDown($drag)
$brand=New-Label 'CyberPW Assistant' 14 113 202 30 15 $goldSoft 'Bold';$brand.TextAlign='MiddleCenter'
$version=New-Label '1.07 β2' 64 148 102 26 9 $goldSoft 'Bold';$version.TextAlign='MiddleCenter';$version.BackColor=$jade3;Set-Rounded $version 8

$navHome=New-NavButton 'ГОЛОВНА' (Join-Path $IconAssetPath 'home.jpg') 194 {$null}
$navTitles=New-NavButton 'TITULHELPER' (Join-Path $IconAssetPath 'titles.jpg') 246 {Start-Module $AssistantPath 'TitulHelper'}
$navMulti=New-NavButton 'MULTILAUNCHER' (Join-Path $IconAssetPath 'multilauncher.jpg') 298 {Start-Module $MultiLauncherPath 'MultiLauncher'}
$navChest=New-NavButton 'СИМУЛЯТОР' (Join-Path $IconAssetPath 'simulator.jpg') 350 {Start-Module $ChestSimulatorPath 'симулятор'}
$navFreeze=New-NavButton 'РОЗМОРОЗКА' (Join-Path $IconAssetPath 'unfreeze.jpg') 402 {Start-Module $UnfreezePath 'розморозку вікон'}
$navBosses=New-NavButton 'СВІТОВІ БОСИ' (Join-Path $IconAssetPath 'bosses.jpg') 454 {Start-Module $WorldBossesPath 'світових босів'}
$navMacros=New-NavButton 'МАКРОСИ' (Join-Path $IconAssetPath 'macros.jpg') 506 {Start-Module $MacroStudioPath 'Macro Studio'}
$navTerritories=New-NavButton 'КАРТА ТВ' (Join-Path $IconAssetPath 'territories.jpg') 558 {Start-Module $TerritoryMapPath 'карту ТВ'}
$navHome.BackColor=$jade3;$navHome.Tag.Back=$jade3

$support=New-Object Windows.Forms.Button;$support.Text='ПІДТРИМАТИ ПРОЄКТ';$support.SetBounds(18,615,194,42);Style-Button $support ([Drawing.Color]::FromArgb(105,70,13)) $goldSoft 8;Set-Rounded $support 10
$support.Anchor='Bottom,Left'
$support.Add_Click({Open-Link 'https://send.monobank.ua/jar/93N5FBB3zX'})
$site=New-Object Windows.Forms.Button;$site.Text='САЙТ CYBERPW';$site.SetBounds(18,665,194,36);Style-Button $site $jade2 $muted 8;Set-Rounded $site 9
$site.Anchor='Bottom,Left'
$site.Add_Click({Open-Link 'https://cyberpw.fun/'})
$author=New-Label "Кіт Михайло · DarkSide`r`nНеофіційний фанатський проєкт" 18 724 194 40 8 $muted;$author.TextAlign='MiddleCenter';$author.Anchor='Bottom,Left'
$sidebar.Controls.AddRange(@($brandLogo,$brand,$version,$navHome,$navTitles,$navMulti,$navChest,$navFreeze,$navBosses,$navMacros,$navTerritories,$support,$site,$author))

$top=New-Object Windows.Forms.Panel;$top.SetBounds(232,2,1046,64);$top.Anchor='Top,Left,Right';$top.BackColor=$ink;$top.Add_MouseDown($drag)
$onlineDot=New-Label '●' 24 20 20 24 10 $cyan 'Bold'
$online=New-Label 'CYBERPW · ІНСТРУМЕНТИ ГОТОВІ' 46 18 360 28 10 $text 'Bold'
$profile=New-Label "Титули: $done / $total" 668 19 158 25 9 $goldSoft 'Bold';$profile.TextAlign='MiddleRight';$profile.Anchor='Top,Right'
$minimize=New-Object Windows.Forms.Button;$minimize.Text='—';$minimize.SetBounds(832,14,42,34);$minimize.Anchor='Top,Right';Style-Button $minimize $jade $goldSoft 10;Set-Rounded $minimize 8
$minimize.Add_Click({$form.WindowState='Minimized'})
$maximize=New-Object Windows.Forms.Button;$maximize.Text='□';$maximize.SetBounds(882,14,42,34);$maximize.Anchor='Top,Right';Style-Button $maximize $jade $goldSoft 11;Set-Rounded $maximize 8
$maximize.Add_Click({
  if($form.WindowState-eq[Windows.Forms.FormWindowState]::Maximized){$form.WindowState='Normal'}
  else{$form.WindowState='Maximized'}
})
$close=New-Object Windows.Forms.Button;$close.Text='×';$close.SetBounds(932,14,42,34);$close.Anchor='Top,Right';Style-Button $close ([Drawing.Color]::FromArgb(70,23,22)) $goldSoft 13;Set-Rounded $close 8
$close.Add_Click({$form.Close()})
$top.Controls.AddRange(@($onlineDot,$online,$profile,$minimize,$maximize,$close))

$hero=New-Object Windows.Forms.Panel;$hero.SetBounds(252,84,1006,264);$hero.Anchor='Top,Left,Right';$hero.BackColor=$panel;$hero.BackgroundImage=Get-LauncherImage $MainBackgroundPath;if($hero.BackgroundImage){$script:cardImages+=,$hero.BackgroundImage;$hero.BackgroundImageLayout='Stretch'}
$hero.Add_Paint({
  param($sender,$eventArgs)
  $heroRect=New-Object Drawing.Rectangle 0,0,$sender.Width,$sender.Height
  $heroBrush=New-Object Drawing.Drawing2D.LinearGradientBrush $heroRect,([Drawing.Color]::FromArgb(235,$jade)),([Drawing.Color]::FromArgb(125,$jade3)),10
  $eventArgs.Graphics.FillRectangle($heroBrush,$heroRect);$heroBrush.Dispose()
  $heroPen=New-Object Drawing.Pen $gold,1;$eventArgs.Graphics.DrawRectangle($heroPen,0,0,$sender.Width-1,$sender.Height-1);$heroPen.Dispose()
})
$heroTitle=New-Label 'CyberPW Assistant' 34 26 480 50 27 $goldSoft 'Bold'
$heroSub=New-Label 'ІНСТРУМЕНТИ ТА ПОМІЧНИКИ ДЛЯ PERFECT WORLD' 37 80 510 26 10 $text 'Bold'
$heroText=New-Label "Сім модулів в одному лаунчері:`r`nтитули, персонажі, макроси, симуляція, фоновий рендер, боси й карта ТВ." 38 119 500 58 11 $muted
$heroStats=New-Label "TITULHELPER: $done / $total     ●  ГОТОВО     VERSION 1.07 BETA 2" 38 204 510 28 9 $cyan 'Bold'

$calendar=New-Object Windows.Forms.Panel;$calendar.SetBounds(562,11,424,242);$calendar.Anchor='Top,Right';$calendar.BackColor=[Drawing.Color]::FromArgb(7,31,27);Set-Rounded $calendar 14
$calendar.Add_Paint({param($sender,$eventArgs);$pen=New-Object Drawing.Pen $gold,2;$eventArgs.Graphics.DrawRectangle($pen,1,1,$sender.Width-3,$sender.Height-3);$pen.Dispose()})
$calendarAccent=New-Object Windows.Forms.Panel;$calendarAccent.SetBounds(14,12,5,23);$calendarAccent.BackColor=$gold
$calendarTitle=New-Label 'КАЛЕНДАР ІВЕНТІВ' 28 10 190 27 11 $goldSoft 'Bold'
$calendarDay=New-Label '' 210 10 180 23 9 $muted 'Bold';$calendarDay.TextAlign='MiddleRight'
$nextEvent=New-Label '' 14 40 396 28 9 $cyan 'Bold';$nextEvent.BackColor=[Drawing.Color]::FromArgb(8,54,45);$nextEvent.Padding='8,0,6,0';Set-Rounded $nextEvent 7
$dayBar=New-Object Windows.Forms.FlowLayoutPanel;$dayBar.SetBounds(17,74,390,34);$dayBar.WrapContents=$false;$dayBar.BackColor=[Drawing.Color]::Transparent;$dayBar.Margin=0;$dayBar.Padding=0
$eventList=New-Object Windows.Forms.ListBox;$eventList.SetBounds(17,112,390,113);$eventList.Anchor='Top,Left,Right'
$eventList.BackColor=$script:CalendarRowA;$eventList.ForeColor=$text;$eventList.BorderStyle='None';$eventList.Font=New-Object Drawing.Font('Segoe UI',8.5)
$eventList.IntegralHeight=$false;$eventList.SelectionMode='None';$eventList.ItemHeight=21;$eventList.DrawMode='OwnerDrawFixed'
$eventList.Add_DrawItem({
  param($sender,$eventArgs)
  if($eventArgs.Index-lt0){return}
  $background=if(($eventArgs.Index%2)-eq0){$script:CalendarRowA}else{$script:CalendarRowB}
  $eventArgs.Graphics.FillRectangle((New-Object Drawing.SolidBrush $background),$eventArgs.Bounds)
  $rowText=[string]$sender.Items[$eventArgs.Index]
  $separator=$rowText.IndexOf('|')
  if($separator-ge0){
    $timeText=$rowText.Substring(0,$separator)
    $nameText=$rowText.Substring($separator+1)
  }else{$timeText=$rowText;$nameText=''}
  $timeBrush=New-Object Drawing.SolidBrush $script:CalendarGold
  $nameBrush=New-Object Drawing.SolidBrush $script:CalendarText
  $timeRect=New-Object Drawing.RectangleF ($eventArgs.Bounds.X+8),($eventArgs.Bounds.Y+2),103,($eventArgs.Bounds.Height-2)
  $nameRect=New-Object Drawing.RectangleF ($eventArgs.Bounds.X+113),($eventArgs.Bounds.Y+2),($eventArgs.Bounds.Width-118),($eventArgs.Bounds.Height-2)
  $eventArgs.Graphics.DrawString($timeText,$sender.Font,$timeBrush,$timeRect)
  if($nameText){$eventArgs.Graphics.DrawString($nameText,$sender.Font,$nameBrush,$nameRect)}
  $timeBrush.Dispose();$nameBrush.Dispose()
})
$script:calendarButtons=@()
for($dayIndex=1;$dayIndex-le7;$dayIndex++){
  $dayButton=New-Object Windows.Forms.Button;$dayButton.Text=$dayShort[$dayIndex-1];$dayButton.Size='48,30';$dayButton.Margin='2,0,2,0'
  Style-Button $dayButton $jade2 $muted 8;Set-Rounded $dayButton 7
  $dayButton.Tag|Add-Member -NotePropertyName Day -NotePropertyValue $dayIndex
  $dayButton.Add_Click({$script:selectedEventDay=[int]$this.Tag.Day;Update-EventCalendar})
  [void]$dayBar.Controls.Add($dayButton);$script:calendarButtons+=,$dayButton
}
$calendar.Controls.AddRange(@($calendarAccent,$calendarTitle,$calendarDay,$nextEvent,$dayBar,$eventList))
$hero.Controls.AddRange(@($heroTitle,$heroSub,$heroText,$heroStats,$calendar))

function Update-EventCalendar{
  $now=Get-Date
  if(-not$script:selectedEventDay){$script:selectedEventDay=[int]$now.DayOfWeek;if($script:selectedEventDay-eq0){$script:selectedEventDay=7}}
  $calendarDay.Text=$dayNames[$script:selectedEventDay-1]
  $eventList.Items.Clear()
  foreach($event in @($eventSchedule|Where-Object Day -eq $script:selectedEventDay)){
    [void]$eventList.Items.Add("$($event.Time)|$($event.Name)")
  }
  foreach($button in $script:calendarButtons){
    if([int]$button.Tag.Day-eq$script:selectedEventDay){
      $button.BackColor=$script:CalendarGold;$button.ForeColor=$script:CalendarInk
      $button.Tag.Back=$script:CalendarGold;$button.Tag.Fore=$script:CalendarInk
    }else{
      $button.BackColor=$script:CalendarJade;$button.ForeColor=$script:CalendarMuted
      $button.Tag.Back=$script:CalendarJade;$button.Tag.Fore=$script:CalendarMuted
    }
  }
  $next=$null
  for($offset=0;$offset-lt8-and-not$next;$offset++){
    $date=$now.Date.AddDays($offset);$weekday=[int]$date.DayOfWeek;if($weekday-eq0){$weekday=7}
    foreach($event in @($eventSchedule|Where-Object Day -eq $weekday)){
      foreach($start in @($event.Starts)){
        $parts=$start.Split(':');$moment=$date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
        if($moment-gt$now-and($null-eq$next-or$moment-lt$next.Moment)){$next=[pscustomobject]@{Moment=$moment;Name=$event.Name}}
      }
    }
  }
  if($next){
    $remaining=$next.Moment-$now
    if($remaining.TotalHours-ge24){$left="$([int]$remaining.TotalDays) дн $($remaining.Hours) год"}
    elseif($remaining.TotalHours-ge1){$left="$([int]$remaining.TotalHours) год $($remaining.Minutes) хв"}
    else{$left="$([Math]::Max(1,$remaining.Minutes)) хв"}
    $nextEvent.Text="НАСТУПНЕ: $($next.Name) · через $left"
  }
}
$script:selectedEventDay=0;Update-EventCalendar
$eventTimer=New-Object Windows.Forms.Timer;$eventTimer.Interval=30000;$eventTimer.Add_Tick({try{Update-EventCalendar}catch{}});$eventTimer.Start()

$card1=New-ModuleCard 'TITULHELPER' 'Титули, синхронізація та мітки' 'ГОТОВО' $cyan (Join-Path $SummerAssetPath 'titles.jpg') $AssistantPath 'TitulHelper'
$card2=New-ModuleCard 'MULTILAUNCHER' 'Профілі та запуск кількох клієнтів' 'ГОТОВО' $cyan (Join-Path $SummerAssetPath 'multilauncher.jpg') $MultiLauncherPath 'MultiLauncher'
$card3=New-ModuleCard 'СИМУЛЯТОР' 'Скриня Тора і статистика дропу' 'BETA' $gold (Join-Path $SummerAssetPath 'simulator.jpg') $ChestSimulatorPath 'симулятор'
$card4=New-ModuleCard 'РОЗМОРОЗКА' 'Фоновий рендер вибраних вікон' 'ДОСТУПНО' $cyan (Join-Path $SummerAssetPath 'unfreeze.jpg') $UnfreezePath 'розморозку'
$card5=New-ModuleCard 'СВІТОВІ БОСИ' 'Координати, хроно та розклад' '24 БОСИ' $gold (Join-Path $SummerAssetPath 'bosses.jpg') $WorldBossesPath 'світових босів'
$card6=New-ModuleCard 'КАРТА ТВ' '51 територія, клани та розклад битв' 'НОВЕ' $gold (Join-Path $SummerAssetPath 'territories.jpg') $TerritoryMapPath 'карту ТВ'
$card7=New-ModuleCard 'MACRO STUDIO' 'Графічні сценарії клавіатури, миші та пікселів' 'BETA' $gold (Join-Path $SummerAssetPath 'macros.jpg') $MacroStudioPath 'Macro Studio'
$moduleGrid=New-Object Windows.Forms.TableLayoutPanel;$moduleGrid.SetBounds(246,372,1018,312)
$moduleGrid.Anchor='Top,Bottom,Left,Right';$moduleGrid.BackColor=[Drawing.Color]::Transparent
$moduleGrid.ColumnCount=4;$moduleGrid.RowCount=2;$moduleGrid.Padding='0,0,0,0'
for($index=0;$index-lt4;$index++){$style=New-Object Windows.Forms.ColumnStyle 'Percent',25;[void]$moduleGrid.ColumnStyles.Add($style)}
$moduleGrid.RowStyles.Add((New-Object Windows.Forms.RowStyle 'Percent',50))|Out-Null
$moduleGrid.RowStyles.Add((New-Object Windows.Forms.RowStyle 'Percent',50))|Out-Null
$moduleGrid.Controls.Add($card1,0,0);$moduleGrid.Controls.Add($card2,1,0);$moduleGrid.Controls.Add($card3,2,0);$moduleGrid.Controls.Add($card7,3,0)
$moduleGrid.Controls.Add($card4,0,1);$moduleGrid.Controls.Add($card5,1,1);$moduleGrid.Controls.Add($card6,2,1)

$footer=New-Label 'CYBERPW ASSISTANT  •  WINDOWS 7/10/11  •  PORTABLE  •  OPEN SOURCE' 252 728 1006 28 8 $muted 'Bold'
$footer.Anchor='Bottom,Left,Right'
$footer.TextAlign='MiddleCenter'
$form.Controls.AddRange(@($sidebar,$top,$hero,$moduleGrid,$footer))
$communityBar=Add-CyberPWCommunityBar $form
$form.Add_FormClosed({if($brandLogo.Image){$brandLogo.Image.Dispose()};foreach($image in @($script:cardImages)){if($image){$image.Dispose()}}})
Apply-CyberPWVisualPolish $form;[void]$form.ShowDialog()
