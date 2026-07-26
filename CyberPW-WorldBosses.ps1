$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BossNative {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int command);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, int data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public static void Click(int x, int y) {
    SetCursorPos(x,y);
    mouse_event(2,0,0,0,UIntPtr.Zero);
    mouse_event(4,0,0,0,UIntPtr.Zero);
  }
}
'@

$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'CyberPW-Common.ps1')
$StatePath=Join-Path $AppDir 'state.json'
$script:Config=[ordered]@{OpenOffsetX=0;OpenOffsetY=0;CoordOffsetX=0;CoordOffsetY=0;DelayMs=650}
$script:Windows=@()

$worldBosses=@(
  [pscustomobject]@{Name='Альфа';Zone='Основний світ';X=162;Y=427},
  [pscustomobject]@{Name='Аптійський щит';Zone='Основний світ';X=151;Y=339},
  [pscustomobject]@{Name='Наглядач безодні';Zone='Основний світ';X=288;Y=963},
  [pscustomobject]@{Name='Дух поселення';Zone='Основний світ';X=159;Y=975},
  [pscustomobject]@{Name='Енгерранд';Zone='Основний світ';X=235;Y=867},
  [pscustomobject]@{Name='Крилатий воїн';Zone='Основний світ';X=439;Y=752},
  [pscustomobject]@{Name='Примарний вершник';Zone='Основний світ';X=171;Y=787},
  [pscustomobject]@{Name='Обеан';Zone='Основний світ';X=553;Y=437},
  [pscustomobject]@{Name='Мисливець за душами';Zone='Основний світ';X=657;Y=434},
  [pscustomobject]@{Name='Шабля демона';Zone='Основний світ';X=438;Y=471},
  [pscustomobject]@{Name='Шилонос';Zone='Основний світ';X=251;Y=754},
  [pscustomobject]@{Name='Сколопендра-вбивця';Zone='Основний світ';X=638;Y=867},
  [pscustomobject]@{Name='Сталевий меч демона';Zone='Основний світ';X=487;Y=570},
  [pscustomobject]@{Name='Тінь померлого';Zone='Основний світ';X=659;Y=523},
  [pscustomobject]@{Name='Загадка';Zone='Основний світ';X=314;Y=955},
  [pscustomobject]@{Name='Золотий король';Zone='Основний світ';X=652;Y=389}
)
$chronoBosses=@(
  [pscustomobject]@{Name='Патрач';Zone='Хроно 1';X=366;Y=472},
  [pscustomobject]@{Name='Майстер-воїн із сокирою';Zone='Хроно 1';X=345;Y=457},
  [pscustomobject]@{Name='Звір грому';Zone='Хроно 2';X=333;Y=596},
  [pscustomobject]@{Name='Обпалений король скелетів';Zone='Хроно 2';X=364;Y=610},
  [pscustomobject]@{Name='Воїн Геї';Zone='Хроно 3';X=477;Y=623},
  [pscustomobject]@{Name='Отруєний король скелетів';Zone='Хроно 3';X=421;Y=570},
  [pscustomobject]@{Name='Пекельний гончак';Zone='Хроно 4';X=462;Y=519},
  [pscustomobject]@{Name='Вартовий морозу';Zone='Хроно 4';X=477;Y=475}
)
$dropText=@'
З усіх хроно-босів випадають однакові предмети:

Камінь безсмертних, коробка 10 шт. — 16%
Скарб минулого — 12%
Золоте яйце — 10%
Біла яшма 10 рівня — 6%
Зелена яшма 10 рівня — 6%
Чорна яшма 10 рівня — 6%
Червона яшма 10 рівня — 6%
Жовта яшма 10 рівня — 6%
Рубіновий камінь 10 рівня — 4,5%
Сапфіровий камінь 10 рівня — 4,5%
Смарагдовий камінь 10 рівня — 4,5%
Бурштиновий камінь 10 рівня — 4,5%
Топазовий камінь 10 рівня — 4,5%
Камінь сліпучого світла — 2,5%
Камінь безмежності — 2,5%
Камінь морської лазурі — 2,5%
Червоне око — 2%

Час появи:
Вівторок — 18:00
Четвер — 21:00
Неділя — 15:00
'@

$theme=Get-CyberPWTheme
$jade=$theme.Base;$jade2=$theme.Button;$panel=$theme.Panel;$gold=$theme.Gold
$goldSoft=$theme.GoldSoft;$textColor=$theme.Text;$muted=$theme.Muted;$cyan=$theme.AccentBright;$danger=$theme.Danger

function Style-Button($button,$back,$fore=$textColor){
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$gold
  $button.BackColor=$back;$button.ForeColor=$fore;$button.Cursor='Hand';$button.Font=New-Object Drawing.Font('Segoe UI Semibold',9)
}
function New-Label($value,$x,$y,$w,$h,$size,$color,$style='Regular'){
  $label=New-Object Windows.Forms.Label;$label.Text=$value;$label.SetBounds($x,$y,$w,$h);$label.ForeColor=$color
  $label.BackColor=[Drawing.Color]::Transparent;$label.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style);$label
}
function Load-Calibration {
  if(-not(Test-Path $StatePath)){return}
  try{
    $state=Get-Content -Raw -Encoding UTF8 -LiteralPath $StatePath|ConvertFrom-Json
    foreach($property in $state.config.PSObject.Properties){
      if($script:Config.Contains($property.Name)){$script:Config[$property.Name]=[int]$property.Value}
    }
  }catch{}
}
function New-BossList($items){
  $list=New-Object Windows.Forms.ListView;$list.View='Details';$list.FullRowSelect=$true;$list.GridLines=$true
  $list.BackColor=$panel;$list.ForeColor=$textColor;$list.BorderStyle='FixedSingle'
  [void]$list.Columns.Add('Бос',430);[void]$list.Columns.Add('Локація',145);[void]$list.Columns.Add('Координати',120)
  foreach($boss in $items){
    $row=New-Object Windows.Forms.ListViewItem $boss.Name
    [void]$row.SubItems.Add($boss.Zone);[void]$row.SubItems.Add("$($boss.X) $($boss.Y)");$row.Tag=$boss
    [void]$list.Items.Add($row)
  }
  $list
}
function Refresh-GameWindows {
  $previous=$null;if($gameBox.SelectedItem){$previous=[int]$gameBox.SelectedItem.ProcessId}
  $gameBox.Items.Clear();$script:Windows=@()
  foreach($process in @(Get-Process -Name ElementClient -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne[IntPtr]::Zero}|Sort-Object Id)){
    $title=$process.MainWindowTitle;if([string]::IsNullOrWhiteSpace($title)){$title='ElementClient'}
    $item=[pscustomobject]@{ProcessId=$process.Id;Display="$title · PID $($process.Id)"}
    $script:Windows+=,$item;[void]$gameBox.Items.Add($item)
  }
  for($index=0;$index-lt$gameBox.Items.Count;$index++){if([int]$gameBox.Items[$index].ProcessId-eq$previous){$gameBox.SelectedIndex=$index;break}}
  if($gameBox.SelectedIndex-lt0-and$gameBox.Items.Count){$gameBox.SelectedIndex=0}
  $windowCount.Text="Вікон: $($gameBox.Items.Count)"
}
function Get-SelectedBoss {
  $list=if($tabs.SelectedTab-eq$worldPage){$worldList}elseif($tabs.SelectedTab-eq$chronoPage){$chronoList}else{$null}
  if($null-eq$list-or$list.SelectedItems.Count-ne1){return $null}
  $list.SelectedItems[0].Tag
}
function Get-GameProcess {
  if(-not$gameBox.SelectedItem){return $null}
  Get-Process -Id ([int]$gameBox.SelectedItem.ProcessId) -ErrorAction SilentlyContinue
}
function Focus-Game {
  $process=Get-GameProcess
  if($null-eq$process-or$process.MainWindowHandle-eq[IntPtr]::Zero){[Windows.Forms.MessageBox]::Show('Вибране вікно гри недоступне. Оновіть список.')|Out-Null;return $null}
  [BossNative]::ShowWindowAsync($process.MainWindowHandle,9)|Out-Null;[BossNative]::SetForegroundWindow($process.MainWindowHandle)|Out-Null
  Start-Sleep -Milliseconds 250
  $rect=New-Object BossNative+RECT
  if([BossNative]::GetWindowRect($process.MainWindowHandle,[ref]$rect)){[BossNative]::Click([int](($rect.Left+$rect.Right)/2),[int]($rect.Top+15))}
  Start-Sleep -Milliseconds 300
  $process
}
function Get-RelativePoint($process,[int]$offsetX,[int]$offsetY){
  $rect=New-Object BossNative+RECT
  if(-not[BossNative]::GetWindowRect($process.MainWindowHandle,[ref]$rect)){return $null}
  $width=$rect.Right-$rect.Left;$height=$rect.Bottom-$rect.Top
  if($offsetX-le0-or$offsetY-le0-or$offsetX-ge$width-or$offsetY-ge$height){return $null}
  [Drawing.Point]::new($rect.Left+$offsetX,$rect.Top+$offsetY)
}
function Open-CoordinatePanel {
  $form.WindowState='Minimized';$process=Focus-Game
  if($null-eq$process){$form.WindowState='Normal';return}
  $point=Get-RelativePoint $process $script:Config.OpenOffsetX $script:Config.OpenOffsetY
  if($null-eq$point){$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Спочатку виконайте прив’язку координат у TitulHelper.")|Out-Null;return}
  [BossNative]::Click($point.X,$point.Y);Start-Sleep -Milliseconds $script:Config.DelayMs;$panelOpen.Checked=$true
}
function Inject-Boss {
  $boss=Get-SelectedBoss
  if($null-eq$boss){[Windows.Forms.MessageBox]::Show('Виберіть боса у списку.')|Out-Null;return}
  $form.WindowState='Minimized';$process=Focus-Game
  if($null-eq$process){$form.WindowState='Normal';return}
  $coordPoint=Get-RelativePoint $process $script:Config.CoordOffsetX $script:Config.CoordOffsetY
  if($null-eq$coordPoint){$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Поле координат не прив’язане. Відкрийте TitulHelper і виконайте калібрування кнопок №1 та №2.")|Out-Null;return}
  if(-not$panelOpen.Checked){
    $openPoint=Get-RelativePoint $process $script:Config.OpenOffsetX $script:Config.OpenOffsetY
    if($null-eq$openPoint){$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Кнопка координат не прив’язана у TitulHelper.")|Out-Null;return}
    [BossNative]::Click($openPoint.X,$openPoint.Y);Start-Sleep -Milliseconds $script:Config.DelayMs;$panelOpen.Checked=$true
  }
  [BossNative]::Click($coordPoint.X,$coordPoint.Y);Start-Sleep -Milliseconds 180
  [Windows.Forms.SendKeys]::SendWait('{END}');Start-Sleep -Milliseconds 60
  [Windows.Forms.SendKeys]::SendWait('{BACKSPACE 12}');Start-Sleep -Milliseconds 100
  [Windows.Forms.SendKeys]::SendWait("$($boss.X) $($boss.Y)");Start-Sleep -Milliseconds 120
  [Windows.Forms.SendKeys]::SendWait('{ENTER}');Start-Sleep -Milliseconds $script:Config.DelayMs
  [Windows.Forms.SendKeys]::SendWait([string]$boss.Name);Start-Sleep -Milliseconds 120
  [Windows.Forms.SendKeys]::SendWait('{ENTER}')
}

Load-Calibration
$form=New-Object Windows.Forms.Form;$form.Text='Cyber.pw Asistant — Світові боси'
$form.Size='930,760';$form.MinimumSize='820,690';$form.StartPosition='CenterScreen';$form.BackColor=$jade;$form.ForeColor=$textColor
$form.AutoScaleMode='Dpi';$form.AutoScroll=$true;$form.MaximizeBox=$true
$header=New-Label 'СВІТОВІ БОСИ' 26 16 420 42 23 $goldSoft 'Bold'
$sub=New-Label 'Координати, хроно-розклад і встановлення міток у CyberPW' 29 58 650 25 10 $muted
$gameLabel=New-Label 'ВІКНО ГРИ' 28 96 130 22 9 $goldSoft 'Bold'
$gameBox=New-Object Windows.Forms.ComboBox;$gameBox.SetBounds(28,120,560,30);$gameBox.DropDownStyle='DropDownList';$gameBox.DisplayMember='Display';$gameBox.BackColor=$panel;$gameBox.ForeColor=$textColor
$refresh=New-Object Windows.Forms.Button;$refresh.Text='↻ ОНОВИТИ';$refresh.SetBounds(600,118,130,34);Style-Button $refresh $jade2
$refresh.Anchor='Top,Right'
$windowCount=New-Label 'Вікон: 0' 744 123 130 24 9 $cyan 'Bold';$windowCount.Anchor='Top,Right'

$tabs=New-Object Windows.Forms.TabControl;$tabs.SetBounds(24,168,870,390);$tabs.Anchor='Top,Bottom,Left,Right'
$worldPage=New-Object Windows.Forms.TabPage;$worldPage.Text='Світові боси';$worldPage.BackColor=$jade2
$chronoPage=New-Object Windows.Forms.TabPage;$chronoPage.Text='Хроно-боси';$chronoPage.BackColor=$jade2
$dropPage=New-Object Windows.Forms.TabPage;$dropPage.Text='Дроп і розклад';$dropPage.BackColor=$jade2
$worldList=New-BossList $worldBosses;$worldList.Dock='Fill'
$chronoList=New-BossList $chronoBosses;$chronoList.Dock='Fill'
$dropBox=New-Object Windows.Forms.RichTextBox;$dropBox.Dock='Fill';$dropBox.ReadOnly=$true;$dropBox.Text=$dropText
$dropBox.BackColor=$panel;$dropBox.ForeColor=$textColor;$dropBox.Font=New-Object Drawing.Font('Segoe UI',10);$dropBox.BorderStyle='None'
$worldPage.Controls.Add($worldList);$chronoPage.Controls.Add($chronoList);$dropPage.Controls.Add($dropBox)
[void]$tabs.TabPages.AddRange(@($worldPage,$chronoPage,$dropPage))

$panelOpen=New-Object Windows.Forms.CheckBox;$panelOpen.Text='Панель координат уже відкрита';$panelOpen.SetBounds(28,574,280,28)
$panelOpen.Anchor='Bottom,Left';$panelOpen.ForeColor=$textColor;$panelOpen.BackColor=[Drawing.Color]::Transparent
$openPanel=New-Object Windows.Forms.Button;$openPanel.Text='ВІДКРИТИ ПАНЕЛЬ КООРДИНАТ';$openPanel.SetBounds(28,610,280,42);$openPanel.Anchor='Bottom,Left';Style-Button $openPanel $jade2
$inject=New-Object Windows.Forms.Button;$inject.Text='📍 ПОСТАВИТИ МІТКУ';$inject.SetBounds(620,600,274,52);$inject.Anchor='Bottom,Right';Style-Button $inject ([Drawing.Color]::FromArgb(18,126,98))
$calibrationState=if($script:Config.OpenOffsetX-gt0-and$script:Config.CoordOffsetX-gt0){'Калібрування TitulHelper знайдено.'}else{'Потрібне калібрування кнопок №1 і №2 у TitulHelper.'}
$status=New-Label $calibrationState 325 614 280 35 8 $(if($script:Config.OpenOffsetX-gt0-and$script:Config.CoordOffsetX-gt0){$cyan}else{$danger})
$status.Anchor='Bottom,Left,Right'

$refresh.Add_Click({Refresh-GameWindows})
$openPanel.Add_Click({Open-CoordinatePanel})
$inject.Add_Click({Inject-Boss})
$worldList.Add_DoubleClick({Inject-Boss});$chronoList.Add_DoubleClick({Inject-Boss})
$form.Controls.AddRange(@($header,$sub,$gameLabel,$gameBox,$refresh,$windowCount,$tabs,$panelOpen,$openPanel,$inject,$status))
Refresh-GameWindows
[void](Add-CyberPWCommunityBar $form)
[void](Add-CyberPWThemeToggle $form $MyInvocation.MyCommand.Path)
Apply-CyberPWVisualPolish $form;[void]$form.ShowDialog()
