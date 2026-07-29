$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# Один процес володіє state.json. Без mutex стара паралельна копія могла
# перезаписати нові зелені позначки своїм застарілим станом під час закриття.
$createdNew=$false
$script:InstanceMutex=[Threading.Mutex]::new($true,'Local\CyberPW-Titles-Assistant-SingleInstance',[ref]$createdNew)
if(-not$createdNew){
  [Windows.Forms.MessageBox]::Show('Cyber.pw Asistant уже запущено. Закрийте старе вікно перед запуском нової версії.')|Out-Null
  $script:InstanceMutex.Dispose();exit
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativePw {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, int data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  public struct POINT { public int X; public int Y; }
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public static void Click(int x, int y) { SetCursorPos(x,y); mouse_event(2,0,0,0,UIntPtr.Zero); mouse_event(4,0,0,0,UIntPtr.Zero); }
  public static void Wheel(int delta) { mouse_event(0x0800,0,0,delta,UIntPtr.Zero); }
}
'@

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'CyberPW-Common.ps1')
. (Join-Path $AppDir 'CyberPW-ClientTitleSync.ps1')
$DataPath = Join-Path $AppDir 'titles.json'
$StatePath = Join-Path $AppDir 'state.json'
$ConfirmedStatePath = Join-Path $AppDir 'state-confirmed.json'
$script:Titles = @()
$script:Done = @{}
$script:Filtered = @()
$script:UpdatingSelection = $false
$script:CoordWindowOpen = $false
$script:Config = [ordered]@{ Process='ElementClient'; OpenOffsetX=0; OpenOffsetY=0; CoordOffsetX=0; CoordOffsetY=0; DelayMs=650 }

function Load-State {
  if (Test-Path $StatePath) {
    try {
      $s = Get-Content $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($p in $s.done.PSObject.Properties) { $script:Done[$p.Name] = [bool]$p.Value }
      foreach ($p in $s.config.PSObject.Properties) { if ($script:Config.Contains($p.Name)) { $script:Config[$p.Name] = $p.Value } }
    } catch { }
  }
  # Резервна копія містить лише стан цієї ж локальної програми. Об'єднуємо
  # підтверджені true, щоб застарілий процес не міг прибрати зелені титули.
  if(Test-Path $ConfirmedStatePath){
    try{
      $backup=Get-Content $ConfirmedStatePath -Raw -Encoding UTF8|ConvertFrom-Json
      foreach($p in $backup.done.PSObject.Properties){if([bool]$p.Value){$script:Done[$p.Name]=$true}}
    }catch{}
  }
  # Старі версії зберігали абсолютну точку екрана. Після зміни монітора вона небезпечна.
  if($script:Config.DelayMs-lt 500){$script:Config.DelayMs=550}
}
function Save-State {
  $doneObj = [ordered]@{}; foreach ($k in $script:Done.Keys) { $doneObj[$k] = $script:Done[$k] }
  $json=@{ done=$doneObj; config=$script:Config }|ConvertTo-Json -Depth 6
  $json|Set-Content $StatePath -Encoding UTF8
  $json|Set-Content $ConfirmedStatePath -Encoding UTF8
}


function Normalize-Title($o, $i) {
  $name = [string]$o.name; if (-not $name) { $name = [string]$o.title }
  $x = $o.x; $y = $o.y
  if ((-not $x) -and $o.coordinates) { $m=[regex]::Match([string]$o.coordinates,'(-?\d+)\D+(-?\d+)'); if($m.Success){$x=$m.Groups[1].Value;$y=$m.Groups[2].Value} }
  if (-not $name -or $null -eq $x -or $null -eq $y) { return $null }
  $id=[string]$o.id; if(-not $id){$id="title-$i-$name"}
  $clientTitleId=0
  if($null-ne$o.clientTitleId){[void][int]::TryParse([string]$o.clientTitleId,[ref]$clientTitleId)}
  [pscustomobject]@{ id=$id; name=$name.Trim(); x=[int]$x; y=[int]$y; note=[string]$o.note; clientTitleId=$clientTitleId; chain=[string]$o.chain; task=[string]$o.task }
}
function Load-Titles($path=$DataPath) {
  $ext=[IO.Path]::GetExtension($path).ToLowerInvariant(); $raw=@()
  if($ext -eq '.json'){
    $parsed=Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if($parsed -is [System.Array]){$raw=$parsed}else{$raw=@($parsed)}
  }
  elseif($ext -eq '.csv'){ $raw=@(Import-Csv $path) }
  elseif($ext -match '\.html?$'){
    $text=Get-Content $path -Raw -Encoding UTF8
    foreach($m in [regex]::Matches($text,'data-(?:title|name)=["'']([^"'']+)["''][^>]*data-x=["''](-?\d+)["''][^>]*data-y=["''](-?\d+)["'']','IgnoreCase')){ $raw += [pscustomobject]@{name=$m.Groups[1].Value;x=$m.Groups[2].Value;y=$m.Groups[3].Value} }
    if($raw.Count -eq 0){ throw 'HTML має містити data-title, data-x і data-y. Експортуйте JSON/CSV або додайте ці атрибути.' }
  } else { throw 'Підтримуються JSON, CSV та HTML.' }
  $out=@(); $i=0; foreach($o in $raw){$i++;$n=Normalize-Title $o $i;if($n){$out+=$n}}
  if($out.Count -eq 0){throw 'Не знайдено записів із назвою та координатами x/y.'}; $script:Titles=$out
}
function Get-TitleDisplayName($title){
  $sameName=@($script:Titles|Where-Object{$_.name-eq$title.name}).Count
  if($sameName-le 1){return [string]$title.name}
  $chain=([string]$title.chain)-replace '^Ланцюжок\s+\d+\s*:\s*',''
  if($chain){return "$($title.name) · $chain"}
  if($title.task){return "$($title.name) · $($title.task)"}
  return "$($title.name) · ID $($title.clientTitleId)"
}
function Refresh-List {
  $selectedId=$null
  if($list.SelectedIndex-ge 0-and$script:Filtered-and$list.SelectedIndex-lt$script:Filtered.Count){$selectedId=$script:Filtered[$list.SelectedIndex].id}
  $q=$search.Text.Trim(); $list.Items.Clear()
  $script:Filtered=@($script:Titles | Where-Object { -not $q -or $_.name -like "*$q*" })
  foreach($t in $script:Filtered){ [void]$list.Items.Add((Get-TitleDisplayName $t)) }
  if($selectedId){
    for($i=0;$i-lt$script:Filtered.Count;$i++){if($script:Filtered[$i].id-eq$selectedId){$list.SelectedIndex=$i;break}}
  }
  $doneCount=@($script:Titles|Where-Object{$script:Done[$_.id]}).Count
  $progress.Text="Отримано: $doneCount / $($script:Titles.Count)"
}
function Selected-Title { if($list.SelectedIndex -lt 0){return $null}; return $script:Filtered[$list.SelectedIndex] }
function Update-Selected {
  $t=Selected-Title; if(-not $t){$coord.Text='—';$note.Text='';$inject.Enabled=$false;return}
  $hasCoordinates=([int]$t.x-ne0-or[int]$t.y-ne0);$coord.Text=if($hasCoordinates){"$($t.x) $($t.y)"}else{'БЕЗ КООРДИНАТ'};$note.Text=$t.note;$inject.Enabled=$hasCoordinates
  $script:UpdatingSelection=$true
  try{$doneBox.Checked=[bool]$script:Done[$t.id]}finally{$script:UpdatingSelection=$false}
}
function Capture-OpenPoint {
  $form.WindowState='Minimized'; Start-Sleep -Seconds 3
  $p=New-Object NativePw+POINT; [NativePw]::GetCursorPos([ref]$p)|Out-Null
  $game=Get-GameProcess
  if(-not$game){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show('CyberPW не запущено.')|Out-Null;return}
  $rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($game.MainWindowHandle,[ref]$rect)|Out-Null
  if($p.X-lt$rect.Left-or$p.X-ge$rect.Right-or$p.Y-lt$rect.Top-or$p.Y-ge$rect.Bottom){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show("Курсор був поза вікном CyberPW. Повторіть прив’язку.")|Out-Null;return}
  $script:Config.OpenOffsetX=$p.X-$rect.Left;$script:Config.OpenOffsetY=$p.Y-$rect.Top
  $screen=[Windows.Forms.Screen]::FromHandle($game.MainWindowHandle)
  $message="Збережено відносно CyberPW на $($screen.DeviceName): $($script:Config.OpenOffsetX), $($script:Config.OpenOffsetY)"
  Save-State;$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show($message)|Out-Null
}
function Capture-CoordPoint {
  $form.WindowState='Minimized'; Start-Sleep -Seconds 3
  $p=New-Object NativePw+POINT; [NativePw]::GetCursorPos([ref]$p)|Out-Null
  $game=Get-GameProcess
  if(-not$game){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show('CyberPW не запущено.')|Out-Null;return}
  $rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($game.MainWindowHandle,[ref]$rect)|Out-Null
  if($p.X-lt$rect.Left-or$p.X-ge$rect.Right-or$p.Y-lt$rect.Top-or$p.Y-ge$rect.Bottom){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show("Курсор був поза вікном CyberPW. Повторіть прив’язку.")|Out-Null;return}
  $script:Config.CoordOffsetX=$p.X-$rect.Left;$script:Config.CoordOffsetY=$p.Y-$rect.Top
  Save-State;$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Поле координат збережено: $($script:Config.CoordOffsetX), $($script:Config.CoordOffsetY)")|Out-Null
}
function Get-GameProcess {
  $candidates=@(Get-Process -Name $script:Config.Process -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne 0})
  if($candidates.Count-eq 0){return $null}
  $preferred=@($candidates|Where-Object{$_.MainWindowTitle-eq 'CyberPW'})
  if($preferred.Count-gt 0){$candidates=$preferred}
  $ranked=foreach($candidate in $candidates){
    $rect=New-Object NativePw+RECT
    if([NativePw]::GetWindowRect($candidate.MainWindowHandle,[ref]$rect)){
      [pscustomobject]@{Process=$candidate;Area=[math]::Max(0,($rect.Right-$rect.Left)*($rect.Bottom-$rect.Top))}
    }
  }
  ($ranked|Sort-Object Area -Descending|Select-Object -First 1).Process
}
function Focus-Game {
  $p=Get-GameProcess
  if(-not $p){[Windows.Forms.MessageBox]::Show("Процес $($script:Config.Process) не запущено.")|Out-Null;return $false}
  [NativePw]::ShowWindowAsync($p.MainWindowHandle,9)|Out-Null
  [NativePw]::SetForegroundWindow($p.MainWindowHandle)|Out-Null
  Start-Sleep -Milliseconds 250
  $rect=New-Object NativePw+RECT
  if([NativePw]::GetWindowRect($p.MainWindowHandle,[ref]$rect)){
    # Один безпечний клік по заголовку потрібен DirectX-клієнту, щоб почати приймати клавіші.
    [NativePw]::Click([int](($rect.Left+$rect.Right)/2),[int]($rect.Top+15))
  }
  Start-Sleep -Milliseconds 350
  return $true
}
function Get-OpenPoint {
  $p=Get-GameProcess
  if(-not$p){return $null}
  $rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($p.MainWindowHandle,[ref]$rect)|Out-Null
  $w=$rect.Right-$rect.Left;$h=$rect.Bottom-$rect.Top
  if($script:Config.OpenOffsetX-gt 0-and$script:Config.OpenOffsetY-gt 0-and$script:Config.OpenOffsetX-lt$w-and$script:Config.OpenOffsetY-lt$h){
    $x=$rect.Left+[int]$script:Config.OpenOffsetX;$y=$rect.Top+[int]$script:Config.OpenOffsetY
    if($x-ge$rect.Left-and$x-lt$rect.Right-and$y-ge$rect.Top-and$y-lt$rect.Bottom){return [Drawing.Point]::new($x,$y)}
  }
  return $null
}
function Get-CoordPoint {
  $p=Get-GameProcess
  if(-not$p){return $null}
  $rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($p.MainWindowHandle,[ref]$rect)|Out-Null
  $w=$rect.Right-$rect.Left;$h=$rect.Bottom-$rect.Top
  if($script:Config.CoordOffsetX-gt 0-and$script:Config.CoordOffsetY-gt 0-and$script:Config.CoordOffsetX-lt$w-and$script:Config.CoordOffsetY-lt$h){
    return [Drawing.Point]::new($rect.Left+[int]$script:Config.CoordOffsetX,$rect.Top+[int]$script:Config.CoordOffsetY)
  }
  return $null
}
function Open-CoordinateWindow {
  $form.WindowState='Minimized'
  if(-not (Focus-Game)){$form.WindowState='Normal';return}
  $point=Get-OpenPoint;if($null-eq$point){$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Прив’язка кнопки застаріла. Повторіть її для поточного розміру й монітора CyberPW.")|Out-Null;return}
  [NativePw]::Click($point.X,$point.Y)
  Start-Sleep -Milliseconds $script:Config.DelayMs
  $script:CoordWindowOpen=$true;$coordOpenBox.Checked=$true
}
function Inject-Title {
  $t=Selected-Title; if(-not $t){[Windows.Forms.MessageBox]::Show('Спочатку виберіть титул.')|Out-Null;return}
  if([int]$t.x-eq0-and[int]$t.y-eq0){[Windows.Forms.MessageBox]::Show('Це системний титул без координатної точки запуску.')|Out-Null;return}
  $form.WindowState='Minimized'
  if(-not (Focus-Game)){$form.WindowState='Normal';return}
  $coordPoint=Get-CoordPoint;if($null-eq$coordPoint){$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Спочатку прив’яжіть поле введення координат. Відкрийте його в CyberPW, натисніть кнопку №2 і за 3 секунди наведіть курсор у середину поля.")|Out-Null;return}
  if(-not $coordOpenBox.Checked){
    $point=Get-OpenPoint;if($null-eq$point){$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Прив’язка кнопки застаріла. Повторіть її для поточного розміру й монітора CyberPW.")|Out-Null;return}
    [NativePw]::Click($point.X,$point.Y)
    Start-Sleep -Milliseconds $script:Config.DelayMs
    $script:CoordWindowOpen=$true;$coordOpenBox.Checked=$true
  }
  # Відео показало, що після відкриття тут лишаються поточні координати персонажа.
  # Явно фокусуємо поле і повністю замінюємо його вміст.
  [NativePw]::Click($coordPoint.X,$coordPoint.Y)
  Start-Sleep -Milliseconds 180
  # DirectX-поле не завжди обробляє Ctrl+A. End + 12 Backspace надійно
  # прибирає автоматичні 7 символів на кшталт "118 860" перед кожною міткою.
  [Windows.Forms.SendKeys]::SendWait('{END}');Start-Sleep -Milliseconds 60
  [Windows.Forms.SendKeys]::SendWait('{BACKSPACE 12}');Start-Sleep -Milliseconds 100
  [Windows.Forms.SendKeys]::SendWait("$($t.x) $($t.y)");Start-Sleep -Milliseconds 120;[Windows.Forms.SendKeys]::SendWait('{ENTER}')
  Start-Sleep -Milliseconds $script:Config.DelayMs
  [Windows.Forms.SendKeys]::SendWait([string]$t.name);Start-Sleep -Milliseconds 120;[Windows.Forms.SendKeys]::SendWait('{ENTER}')
}




















$theme=Get-CyberPWTheme
$jadeDark=$theme.Base
$jadePanel=$theme.Field
$jade=$theme.Accent
$jadeBright=$theme.AccentBright
$gold=$theme.Gold
$goldSoft=$theme.GoldSoft
$textSoft=$theme.Muted
function Style-Button($button,$back,$fore=$goldSoft){$button.BackColor=$back;$button.ForeColor=$fore;$button.FlatStyle='Flat';$button.FlatAppearance.BorderColor=$gold;$button.FlatAppearance.BorderSize=1;$button.Cursor='Hand'}
function Show-CoordinateSetupWizard {
  $wizard=New-Object Windows.Forms.Form
  $wizard.Text='TitulHelper — налаштування координат';$wizard.ClientSize='720,510';$wizard.MinimumSize='720,510';$wizard.MaximumSize='720,510';$wizard.StartPosition='CenterParent';$wizard.FormBorderStyle='FixedDialog';$wizard.MaximizeBox=$false;$wizard.MinimizeBox=$false;$wizard.ShowInTaskbar=$false;$wizard.BackColor=$jadeDark;$wizard.ForeColor='White';$wizard.Font=New-Object Drawing.Font('Segoe UI',10)
  $heading=New-Object Windows.Forms.Label;$heading.Text='НАЛАШТУВАННЯ У ДВА КРОКИ';$heading.SetBounds(24,18,670,32);$heading.Font=New-Object Drawing.Font('Segoe UI Semibold',16,[Drawing.FontStyle]::Bold);$heading.ForeColor=$goldSoft
  $intro=New-Object Windows.Forms.Label;$intro.Text='Натисніть кнопку кроку — майстер сховається на 3 секунди. За цей час наведіть курсор точно на показане місце у грі.';$intro.SetBounds(24,55,670,46);$intro.ForeColor=$textSoft
  function Add-GuideImage($parent,[string]$file,[int]$x,[int]$y,[int]$w,[int]$h){$box=New-Object Windows.Forms.PictureBox;$box.SetBounds($x,$y,$w,$h);$box.SizeMode='Zoom';$box.BackColor=[Drawing.Color]::FromArgb(3,22,19);$box.BorderStyle='FixedSingle';$path=Join-Path $AppDir ('ui-assets\help\'+$file);if(Test-Path -LiteralPath $path){$source=[Drawing.Image]::FromFile($path);try{$box.Image=New-Object Drawing.Bitmap($source)}finally{$source.Dispose()}};$parent.Controls.Add($box);$box}
  $step1=New-Object Windows.Forms.GroupBox;$step1.Text='КРОК 1 · КНОПКА ВІДКРИТТЯ';$step1.SetBounds(24,112,320,300);$step1.ForeColor=$goldSoft
  $step1Text=New-Object Windows.Forms.Label;$step1Text.Text="Наведіть курсор на маленьку круглу стрілку праворуч у вікні гри.`r`nНе натискайте — просто тримайте курсор.";$step1Text.SetBounds(16,28,286,62);$step1Text.ForeColor='White'
  $image1=Add-GuideImage $step1 'coordinate-toggle.png' 16 96 286 120
  $step1Button=New-Object Windows.Forms.Button;$step1Button.Text='1 · ЗАПАМЯТАТИ КНОПКУ';$step1Button.SetBounds(16,238,286,44);Style-Button $step1Button $jade
  $step1.Controls.AddRange(@($step1Text,$step1Button))
  $step2=New-Object Windows.Forms.GroupBox;$step2.Text='КРОК 2 · ПОЛЕ КООРДИНАТ';$step2.SetBounds(376,112,320,300);$step2.ForeColor=$goldSoft
  $step2Text=New-Object Windows.Forms.Label;$step2Text.Text="Спочатку відкрийте панель координат у грі.`r`nПотім наведіть курсор усередину чорного поля з цифрами.";$step2Text.SetBounds(16,28,286,62);$step2Text.ForeColor='White'
  $image2=Add-GuideImage $step2 'coordinate-field.png' 16 96 286 120
  $step2Button=New-Object Windows.Forms.Button;$step2Button.Text='2 · ЗАПАМЯТАТИ ПОЛЕ';$step2Button.SetBounds(16,238,286,44);Style-Button $step2Button $jade
  $step2.Controls.AddRange(@($step2Text,$step2Button))
  $status=New-Object Windows.Forms.Label;$status.SetBounds(24,425,500,48);$status.ForeColor=$jadeBright
  $close=New-Object Windows.Forms.Button;$close.Text='ГОТОВО';$close.SetBounds(560,430,136,42);Style-Button $close $jadePanel
  $refreshStatus={
    $openReady=([int]$script:Config.OpenOffsetX-gt0-and[int]$script:Config.OpenOffsetY-gt0);$fieldReady=([int]$script:Config.CoordOffsetX-gt0-and[int]$script:Config.CoordOffsetY-gt0)
    $status.Text="Кнопка: $(if($openReady){'ГОТОВО ✓'}else{'НЕ НАЛАШТОВАНО'})     Поле: $(if($fieldReady){'ГОТОВО ✓'}else{'НЕ НАЛАШТОВАНО'})"
  }
  $step1Button.Add_Click({$wizard.Hide();try{Capture-OpenPoint}finally{$wizard.Show();$wizard.Activate();&$refreshStatus}})
  $step2Button.Add_Click({$wizard.Hide();try{Capture-CoordPoint}finally{$wizard.Show();$wizard.Activate();&$refreshStatus}})
  $close.Add_Click({$wizard.Close()});$wizard.Controls.AddRange(@($heading,$intro,$step1,$step2,$status,$close));&$refreshStatus
  $wizard.Add_FormClosed({if($image1.Image){$image1.Image.Dispose()};if($image2.Image){$image2.Image.Dispose()}})
  [void]$wizard.ShowDialog($form)
}

$form=New-Object Windows.Forms.Form; $form.Text='CyberPW — Titles Assistant'; $form.Size='960,890'; $form.MinimumSize='820,720'; $form.StartPosition='CenterScreen'; $form.BackColor=$jadeDark; $form.ForeColor='White'; $form.Font=New-Object Drawing.Font('Segoe UI',10);$form.MaximizeBox=$true;$form.AutoScaleMode='Dpi';$form.AutoScroll=$true
$form.Text='Cyber.pw Asistant — TitulHelper'
$logo=New-Object Windows.Forms.PictureBox;$logo.SetBounds(18,8,365,125);$logo.SizeMode='Zoom';$logo.BackColor=$jadeDark
$logoPath=Join-Path $AppDir 'cyberpw-logo.png';if(Test-Path $logoPath){
  # Клонуємо зображення в пам'ять, щоб запущена програма не блокувала файл.
  $logoSource=[Drawing.Image]::FromFile($logoPath)
  try{$logo.Image=New-Object Drawing.Bitmap($logoSource)}finally{$logoSource.Dispose()}
}
$brand=New-Object Windows.Forms.Label;$brand.Text='TITLES ASSISTANT';$brand.Font=New-Object Drawing.Font('Segoe UI Semibold',22,[Drawing.FontStyle]::Bold);$brand.ForeColor=$gold;$brand.SetBounds(420,28,480,44)
$brandSub=New-Object Windows.Forms.Label;$brandSub.Text='Офіційний помічник титулів для Cyber.pw';$brandSub.ForeColor=$textSoft;$brandSub.SetBounds(423,77,430,28)
$divider=New-Object Windows.Forms.Panel;$divider.BackColor=$gold;$divider.SetBounds(18,135,905,2)
$searchLbl=New-Object Windows.Forms.Label;$searchLbl.Text='ПОШУК ТИТУЛУ';$searchLbl.ForeColor=$goldSoft;$searchLbl.SetBounds(20,151,250,24)
$search=New-Object Windows.Forms.TextBox; $search.SetBounds(20,176,390,32);$search.BackColor=$jadePanel;$search.ForeColor='White';$search.BorderStyle='FixedSingle'
$list=New-Object Windows.Forms.ListBox; $list.SetBounds(20,218,390,420); $list.BackColor=$jadePanel; $list.ForeColor='White'; $list.DrawMode='OwnerDrawFixed';$list.BorderStyle='FixedSingle';$list.ItemHeight=22
$list.Add_DrawItem({
  param($s,$e)
  if($e.Index-lt 0){return}
  $t=$script:Filtered[$e.Index];$selected=(($e.State-band[Windows.Forms.DrawItemState]::Selected)-ne 0)
  $bgBrush=New-Object Drawing.SolidBrush($(if($selected){$jade}else{$jadePanel}))
  $c=if($script:Done[$t.id]){$jadeBright}else{$textSoft};$brush=New-Object Drawing.SolidBrush($c)
  try{$e.Graphics.FillRectangle($bgBrush,$e.Bounds);$e.Graphics.DrawString([string](Get-TitleDisplayName $t),$e.Font,$brush,[single]($e.Bounds.X+7),[single]($e.Bounds.Y+2))}finally{$brush.Dispose();$bgBrush.Dispose()}
  $e.DrawFocusRectangle()
})
$progress=New-Object Windows.Forms.Label; $progress.SetBounds(20,646,390,28);$progress.ForeColor=$goldSoft
$titleLbl=New-Object Windows.Forms.Label; $titleLbl.Text='ПОТОЧНА МІТКА'; $titleLbl.ForeColor=$goldSoft;$titleLbl.SetBounds(450,151,220,25)
$coord=New-Object Windows.Forms.Label; $coord.Text='—'; $coord.Font=New-Object Drawing.Font('Segoe UI',24,[Drawing.FontStyle]::Bold); $coord.ForeColor=$gold; $coord.SetBounds(450,176,350,48)
$note=New-Object Windows.Forms.Label; $note.SetBounds(450,226,455,52);$note.ForeColor=$textSoft
$doneBox=New-Object Windows.Forms.CheckBox; $doneBox.Text='Титул уже отримано'; $doneBox.SetBounds(450,276,190,30);$doneBox.ForeColor=$textSoft
$coordOpenBox=New-Object Windows.Forms.CheckBox; $coordOpenBox.Text='Панель координат відкрита'; $coordOpenBox.SetBounds(665,276,240,30);$coordOpenBox.ForeColor=$textSoft
$inject=New-Object Windows.Forms.Button; $inject.Text='ПОСТАВИТИ МІТКУ В CYBERPW'; $inject.SetBounds(450,312,455,50);Style-Button $inject $jade
$settingsLbl=New-Object Windows.Forms.Label;$settingsLbl.Text='ШВИДКЕ НАЛАШТУВАННЯ';$settingsLbl.ForeColor=$goldSoft;$settingsLbl.SetBounds(450,378,300,24)
$setup=New-Object Windows.Forms.Button;$setup.Text='⚙ НАЛАШТУВАТИ КООРДИНАТИ';$setup.SetBounds(450,405,455,48);Style-Button $setup $jadePanel $goldSoft
$sync=New-Object Windows.Forms.Button;$sync.Text='⚡ СИНХРОНІЗУВАТИ З КЛІЄНТОМ';$sync.SetBounds(450,470,455,50);Style-Button $sync $jade $goldSoft
$resetDone=New-Object Windows.Forms.Button; $resetDone.Text='Скинути збережений прогрес'; $resetDone.SetBounds(450,535,455,34);Style-Button $resetDone $jadeDark $textSoft
$credit=New-Object Windows.Forms.Label;$credit.Text='Створив Кіт Михайло для сервера Cyber.pw · клан DarkSide';$credit.ForeColor=$textSoft;$credit.SetBounds(20,730,620,23)
$serverLink=New-Object Windows.Forms.LinkLabel;$serverLink.Text='Сайт CyberPW';$serverLink.LinkColor=$gold;$serverLink.ActiveLinkColor=$goldSoft;$serverLink.VisitedLinkColor=$gold;$serverLink.SetBounds(20,758,120,23);$serverLink.Cursor='Hand'
$refLink=New-Object Windows.Forms.LinkLabel;$refLink.Text='Реєстрація з бонусом';$refLink.LinkColor=$gold;$refLink.ActiveLinkColor=$goldSoft;$refLink.VisitedLinkColor=$gold;$refLink.SetBounds(165,758,180,23);$refLink.Cursor='Hand'
$youtube=New-Object Windows.Forms.LinkLabel;$youtube.Text='YouTube · Vitalik_Juk';$youtube.LinkColor=$gold;$youtube.ActiveLinkColor=$goldSoft;$youtube.VisitedLinkColor=$gold;$youtube.SetBounds(735,758,190,23);$youtube.TextAlign='MiddleRight';$youtube.Cursor='Hand'
$form.Controls.AddRange(@($logo,$brand,$brandSub,$divider,$searchLbl,$search,$list,$progress,$titleLbl,$coord,$note,$doneBox,$coordOpenBox,$inject,$settingsLbl,$setup,$sync,$resetDone,$credit,$serverLink,$refLink,$youtube))
$search.Add_TextChanged({Refresh-List}); $list.Add_SelectedIndexChanged({Update-Selected})
$doneBox.Add_CheckedChanged({if($script:UpdatingSelection){return};$t=Selected-Title;if($t){$script:Done[$t.id]=$doneBox.Checked;Save-State;$list.Invalidate();Refresh-List}})
$coordOpenBox.Add_CheckedChanged({$script:CoordWindowOpen=$coordOpenBox.Checked})
$resetDone.Add_Click({if([Windows.Forms.MessageBox]::Show('Скинути всі зелені позначки й очистити збережений прогрес?','Підтвердження',[Windows.Forms.MessageBoxButtons]::YesNo)-eq[Windows.Forms.DialogResult]::Yes){$script:Done=@{};Save-State;Refresh-List;$list.Invalidate()}})
$inject.Add_Click({Inject-Title});$setup.Add_Click({Show-CoordinateSetupWizard});$sync.Add_Click({Sync-CyberPWOwnedTitles})
$serverLink.Add_LinkClicked({try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='https://cyberpw.fun/';$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}catch{[Windows.Forms.MessageBox]::Show('Не вдалося відкрити сайт CyberPW.')|Out-Null}})
$refLink.Add_LinkClicked({try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='https://cabinet.cyberpw.fun/register.php?ref=4550';$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}catch{[Windows.Forms.MessageBox]::Show('Не вдалося відкрити реєстрацію.')|Out-Null}})
$youtube.Add_LinkClicked({try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='https://www.youtube.com/@Vitalik_Juk';$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}catch{[Windows.Forms.MessageBox]::Show('Не вдалося відкрити YouTube.')|Out-Null}})
$form.Add_FormClosed({
  if($logo.Image){$logo.Image.Dispose()}
  try{$script:InstanceMutex.ReleaseMutex()}catch{}
  $script:InstanceMutex.Dispose()
})
Load-State; try{Load-Titles}catch{[Windows.Forms.MessageBox]::Show("Не вдалося прочитати дані: $($_.Exception.Message)")|Out-Null};Save-State;Refresh-List
[void](Add-CyberPWCommunityBar $form)
[void](Add-CyberPWThemeToggle $form $MyInvocation.MyCommand.Path)
[void]$form.ShowDialog()
