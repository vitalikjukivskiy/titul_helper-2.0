$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$script:IsWindows7=([Environment]::OSVersion.Version.Major-eq6-and[Environment]::OSVersion.Version.Minor-eq1)
$script:OcrSupported=$false
if(-not$script:IsWindows7){
  try{Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop;$script:OcrSupported=$true}catch{}
}

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
$DataPath = Join-Path $AppDir 'titles.json'
$StatePath = Join-Path $AppDir 'state.json'
$ConfirmedStatePath = Join-Path $AppDir 'state-confirmed.json'
$OcrRulesPath = Join-Path $AppDir 'ocr-rules.json'
$ScanReportPath = Join-Path $AppDir 'scan-report.json'
$script:Titles = @()
$script:Done = @{}
$script:OcrRules = @{}
$script:OcrContextRules = @()
$script:LastLineResults = @()
$script:Filtered = @()
$script:UpdatingSelection = $false
$script:CoordWindowOpen = $false
$script:Config = [ordered]@{ Process='ElementClient'; OpenOffsetX=0; OpenOffsetY=0; CoordOffsetX=0; CoordOffsetY=0; TitleLeftOffset=0; TitleTopOffset=0; TitleRightOffset=0; TitleBottomOffset=0; TabLeftOffset=0; TabTopOffset=0; TabRightOffset=0; TabBottomOffset=0; DelayMs=650 }

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
function Load-OcrRules {
  $script:OcrRules=@{}
  $script:OcrContextRules=@()
  if(-not(Test-Path $OcrRulesPath)){return}
  try{
    $rules=Get-Content $OcrRulesPath -Raw -Encoding UTF8|ConvertFrom-Json
    foreach($rule in @($rules)){
      $key=Normalize-Words ([string]$rule.ocr)
      if($key-and$rule.target){
        $previousKey=Normalize-Words ([string]$rule.previousOcr)
        $nextKey=Normalize-Words ([string]$rule.nextOcr)
        if($previousKey-or$nextKey){
          $script:OcrContextRules+=,[pscustomobject]@{Key=$key;PreviousKey=$previousKey;NextKey=$nextKey;Target=[string]$rule.target}
        }else{$script:OcrRules[$key]=[string]$rule.target}
      }
    }
  }catch{throw "Не вдалося прочитати ocr-rules.json: $($_.Exception.Message)"}
}
function Save-ScanReport($report){
  @($report)|ConvertTo-Json -Depth 6|Set-Content $ScanReportPath -Encoding UTF8
}
function Normalize-Title($o, $i) {
  $name = [string]$o.name; if (-not $name) { $name = [string]$o.title }
  $x = $o.x; $y = $o.y
  if ((-not $x) -and $o.coordinates) { $m=[regex]::Match([string]$o.coordinates,'(-?\d+)\D+(-?\d+)'); if($m.Success){$x=$m.Groups[1].Value;$y=$m.Groups[2].Value} }
  if (-not $name -or $null -eq $x -or $null -eq $y) { return $null }
  $id=[string]$o.id; if(-not $id){$id="title-$i-$name"}
  [pscustomobject]@{ id=$id; name=$name.Trim(); x=[int]$x; y=[int]$y; note=[string]$o.note }
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
function Refresh-List {
  $selectedId=$null
  if($list.SelectedIndex-ge 0-and$script:Filtered-and$list.SelectedIndex-lt$script:Filtered.Count){$selectedId=$script:Filtered[$list.SelectedIndex].id}
  $q=$search.Text.Trim(); $list.Items.Clear()
  $script:Filtered=@($script:Titles | Where-Object { -not $q -or $_.name -like "*$q*" })
  foreach($t in $script:Filtered){ [void]$list.Items.Add($t.name) }
  if($selectedId){
    for($i=0;$i-lt$script:Filtered.Count;$i++){if($script:Filtered[$i].id-eq$selectedId){$list.SelectedIndex=$i;break}}
  }
  $doneCount=@($script:Titles|Where-Object{$script:Done[$_.id]}).Count
  $progress.Text="Отримано: $doneCount / $($script:Titles.Count)"
}
function Selected-Title { if($list.SelectedIndex -lt 0){return $null}; return $script:Filtered[$list.SelectedIndex] }
function Update-Selected {
  $t=Selected-Title; if(-not $t){$coord.Text='—';$note.Text='';return}
  $coord.Text="$($t.x) $($t.y)"; $note.Text=$t.note
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

function Capture-TitleCorner($kind) {
  $form.WindowState='Minimized'; Start-Sleep -Seconds 3
  $p=New-Object NativePw+POINT; [NativePw]::GetCursorPos([ref]$p)|Out-Null
  $game=Get-GameProcess
  if(-not$game){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show('CyberPW не запущено.')|Out-Null;return}
  $rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($game.MainWindowHandle,[ref]$rect)|Out-Null
  if($p.X-lt$rect.Left-or$p.X-ge$rect.Right-or$p.Y-lt$rect.Top-or$p.Y-ge$rect.Bottom){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show('Курсор був поза вікном CyberPW. Повторіть калібрування.')|Out-Null;return}
  if($kind-eq 'TopLeft'){$script:Config.TitleLeftOffset=$p.X-$rect.Left;$script:Config.TitleTopOffset=$p.Y-$rect.Top}else{$script:Config.TitleRightOffset=$p.X-$rect.Left;$script:Config.TitleBottomOffset=$p.Y-$rect.Top}
  Save-State;$screen=[Windows.Forms.Screen]::FromHandle($game.MainWindowHandle);$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Збережено відносно CyberPW на $($screen.DeviceName): $($p.X-$rect.Left), $($p.Y-$rect.Top)")|Out-Null
}
function Capture-TabCorner($kind) {
  $form.WindowState='Minimized'; Start-Sleep -Seconds 3
  $p=New-Object NativePw+POINT; [NativePw]::GetCursorPos([ref]$p)|Out-Null
  $game=Get-GameProcess
  if(-not$game){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show('CyberPW не запущено.')|Out-Null;return}
  $rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($game.MainWindowHandle,[ref]$rect)|Out-Null
  if($p.X-lt$rect.Left-or$p.X-ge$rect.Right-or$p.Y-lt$rect.Top-or$p.Y-ge$rect.Bottom){$form.WindowState='Normal';[Windows.Forms.MessageBox]::Show("Курсор був поза вікном CyberPW. Повторіть калібрування.")|Out-Null;return}
  if($kind-eq 'TopLeft'){$script:Config.TabLeftOffset=$p.X-$rect.Left;$script:Config.TabTopOffset=$p.Y-$rect.Top}else{$script:Config.TabRightOffset=$p.X-$rect.Left;$script:Config.TabBottomOffset=$p.Y-$rect.Top}
  Save-State;$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show("Область вкладок збережено: $($p.X-$rect.Left), $($p.Y-$rect.Top)")|Out-Null
}
function Await-WinRt($operation,[Type]$resultType){
  $m=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name-eq 'AsTask'-and $_.IsGenericMethod-and $_.GetParameters().Count-eq 1}|Select-Object -First 1
  $task=$m.MakeGenericMethod($resultType).Invoke($null,@($operation));$task.Wait();$task.Result
}
function Get-CyrillicOcrEngine {
  $null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
  $null=[Windows.Globalization.Language,Windows.Globalization,ContentType=WindowsRuntime]
  # На деяких Windows встановлений ru-RU має State=Installed, але не з'являється
  # у AvailableRecognizerLanguages. Пробуємо створити движок напряму.
  foreach($tag in @('ru-RU','uk-UA')){
    try{
      $language=[Windows.Globalization.Language]::new([string]$tag)
      $engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
      if($null-ne$engine){return $engine}
    }catch{}
  }
  foreach($language in @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages)){
    if($language.LanguageTag-in @('ru-RU','uk-UA')){
      $engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
      if($null-ne$engine){return $engine}
    }
  }
  return $null
}
function Install-UkrainianOcr {
  if(-not$script:OcrSupported){
    [Windows.Forms.MessageBox]::Show('Системний Windows OCR доступний лише у Windows 10/11. У Windows 7 TitulHelper працює без автоматичного OCR-сканування. Пошук, ручні позначки, калібрування та встановлення координат залишаються доступними.','OCR недоступний')|Out-Null
    return $false
  }
  $answer=[Windows.Forms.MessageBox]::Show("На цьому ПК відсутнє розпізнавання українського тексту.`r`n`r`nВстановити офіційний компонент Windows «Український OCR» зараз? Windows покаже запит адміністратора і завантажить мовний компонент.",'Потрібен український OCR',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
  if($answer-ne[Windows.Forms.DialogResult]::Yes){return $false}
  try{
    $command="Add-WindowsCapability -Online -Name 'Language.OCR~~~uk-UA~0.0.1.0' | Out-Null"
    $installer=Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command',$command)
    if($installer.ExitCode-ne 0){throw "Код завершення Windows: $($installer.ExitCode)"}
    [Windows.Forms.MessageBox]::Show("Український OCR встановлено. Якщо автоскан не стартує одразу — перезапустіть Cyber.pw Asistant і натисніть автоскан ще раз.")|Out-Null
    return $true
  }catch{
    [Windows.Forms.MessageBox]::Show("Windows не змогла встановити OCR автоматично.`r`n`r`n$($_.Exception.Message)`r`n`r`nПеревірте інтернет і повторіть запуск від імені адміністратора.")|Out-Null
    return $false
  }
}
function Read-OcrResult($path){
  $null=[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
  $null=[Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime]
  $null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
  $null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
  $engine=Get-CyrillicOcrEngine
  if($null-eq$engine){
    throw 'Кириличний OCR не вдалося запустити. Перевірте, що Language.OCR для ru-RU має State: Installed, вийдіть із Windows і зайдіть знову, а потім повторіть.'
  }
  $file=Await-WinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
  $stream=Await-WinRt ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder=Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap=Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  Await-WinRt ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
}
function Read-Ocr($path){(Read-OcrResult $path).Text}
function Read-OcrLines($path){
  $result=Read-OcrResult $path
  @($result.Lines|ForEach-Object{[string]$_.Text})
}
function Read-OcrLineInfo($path){
  $result=Read-OcrResult $path
  $image=[Drawing.Bitmap]::FromFile($path)
  try{
    @($result.Lines|ForEach-Object{
      $words=@($_.Words)
      $left=if($words.Count){[double]$words[0].BoundingRect.X}else{0}
      $top=if($words.Count){[double]$words[0].BoundingRect.Y}else{0}
      $trailingInk=$false
      if($words.Count){
        $last=$words[$words.Count-1].BoundingRect
        $startX=[Math]::Max(0,[int][Math]::Ceiling($last.X+$last.Width+2))
        $startY=[Math]::Max(0,[int][Math]::Floor($last.Y-2))
        $endY=[Math]::Min($image.Height-1,[int][Math]::Ceiling($last.Y+$last.Height+2))
        $ink=0
        $endX=[Math]::Min($image.Width-1,[int]($image.Width*.85))
        for($py=$startY;$py-le$endY-and-not$trailingInk;$py++){
          for($px=$startX;$px-le$endX;$px++){
            $pixel=$image.GetPixel($px,$py)
            if($pixel.R-lt80-and$pixel.G-lt80-and$pixel.B-lt80){$ink++;if($ink-ge3){$trailingInk=$true;break}}
          }
        }
      }
      [pscustomobject]@{Text=[string]$_.Text;Left=$left;Top=$top;HasTrailingInk=$trailingInk}
    })
  }finally{$image.Dispose()}
}
function Read-OcrLineInfoWithFallback($path){
  $primary=@(Read-OcrLineInfo $path)
  $image=[Drawing.Bitmap]::FromFile($path)
  try{
    $active=@()
    for($y=0;$y-lt$image.Height;$y++){
      $ink=0
      for($x=0;$x-lt$image.Width;$x++){
        $p=$image.GetPixel($x,$y)
        if($p.R-lt80-and$p.G-lt80-and$p.B-lt80){$ink++}
      }
      if($ink-ge3){$active+=$y}
    }
    $bands=@()
    if($active.Count){
      $start=$active[0];$previous=$start
      foreach($y in @($active|Select-Object -Skip 1)){
        if($y-$previous-gt2){$bands+=,[pscustomobject]@{Start=$start;End=$previous};$start=$y}
        $previous=$y
      }
      $bands+=,[pscustomobject]@{Start=$start;End=$previous}
    }
    $result=@($primary)
    $rowNumber=0
    foreach($band in $bands){
      $height=[int]$band.End-[int]$band.Start+1
      if($height-lt6-or$height-gt20){continue}
      $hasPrimary=@($primary|Where-Object{$_.Top-ge([int]$band.Start-5)-and$_.Top-le([int]$band.End+5)}).Count-gt0
      if($hasPrimary){continue}
      $rowNumber++
      $sourceX=[Math]::Max(0,[int]($image.Width*.18))
      $sourceRight=[Math]::Min($image.Width,[int]($image.Width*.84))
      $sourceY=[Math]::Max(0,[int]$band.Start-4)
      $sourceBottom=[Math]::Min($image.Height,[int]$band.End+5)
      $sourceWidth=$sourceRight-$sourceX;$sourceHeight=$sourceBottom-$sourceY
      if($sourceWidth-le20-or$sourceHeight-le5){continue}
      $row=[Drawing.Bitmap]::new($sourceWidth+40,$sourceHeight+36)
      $graphics=[Drawing.Graphics]::FromImage($row)
      try{
        $graphics.Clear([Drawing.Color]::White)
        $graphics.DrawImage($image,[Drawing.Rectangle]::new(20,18,$sourceWidth,$sourceHeight),[Drawing.Rectangle]::new($sourceX,$sourceY,$sourceWidth,$sourceHeight),[Drawing.GraphicsUnit]::Pixel)
        $rowPath=Join-Path $env:TEMP "cyberpw-title-row-$rowNumber.png"
        $row.Save($rowPath,[Drawing.Imaging.ImageFormat]::Png)
      }finally{$graphics.Dispose();$row.Dispose()}
      $rowLines=@(Read-OcrLineInfo $rowPath)
      foreach($line in $rowLines){
        if(-not([string]$line.Text).Trim()){continue}
        $result+=,[pscustomobject]@{Text=[string]$line.Text;Left=([double]$line.Left+$sourceX-20);Top=([double]$band.Start);HasTrailingInk=[bool]$line.HasTrailingInk}
      }
    }
    # Третій гарантований прохід. У списку завжди рівно п'ять фіксованих
    # позицій. Якщо визначення чорних смуг або Windows OCR повністю пропустило
    # одну позицію, вирізаємо її незалежно та читаємо у подвійному масштабі.
    for($slot=0;$slot-lt5;$slot++){
      $slotTop=[int][Math]::Floor($slot*$image.Height/5)
      $slotBottom=[int][Math]::Floor(($slot+1)*$image.Height/5)-1
      $hasResult=@($result|Where-Object{$_.Top-ge($slotTop-3)-and$_.Top-le($slotBottom+3)}).Count-gt0
      if($hasResult){continue}
      $sourceX=[Math]::Max(0,[int]($image.Width*.08))
      $sourceRight=[Math]::Min($image.Width,[int]($image.Width*.90))
      $sourceY=[Math]::Max(0,$slotTop)
      $sourceWidth=$sourceRight-$sourceX;$sourceHeight=$slotBottom-$sourceY+1
      if($sourceWidth-le20-or$sourceHeight-le10){continue}
      $fixedRow=[Drawing.Bitmap]::new($sourceWidth*2+40,$sourceHeight*2+36)
      $fixedGraphics=[Drawing.Graphics]::FromImage($fixedRow)
      try{
        $fixedGraphics.Clear([Drawing.Color]::White)
        $fixedGraphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $fixedGraphics.DrawImage($image,[Drawing.Rectangle]::new(20,18,$sourceWidth*2,$sourceHeight*2),[Drawing.Rectangle]::new($sourceX,$sourceY,$sourceWidth,$sourceHeight),[Drawing.GraphicsUnit]::Pixel)
        $fixedPath=Join-Path $env:TEMP "cyberpw-title-fixed-row-$slot.png"
        $fixedRow.Save($fixedPath,[Drawing.Imaging.ImageFormat]::Png)
      }finally{$fixedGraphics.Dispose();$fixedRow.Dispose()}
      $fixedLines=@(Read-OcrLineInfo $fixedPath|Where-Object{([string]$_.Text).Trim()}|Sort-Object Left)
      if($fixedLines.Count){
        $line=$fixedLines[0]
        $result+=,[pscustomobject]@{Text=[string]$line.Text;Left=([double]$line.Left/2+$sourceX-10);Top=[double]($slotTop+2);HasTrailingInk=[bool]$line.HasTrailingInk}
      }
    }
    @($result|Sort-Object Top,Left)
  }finally{$image.Dispose()}
}
function Normalize-Words($s){
  # ru-RU OCR часто замінює українські і/ї/є/ґ найближчими російськими літерами.
  $v=([string]$s).ToLowerInvariant()
  $v=$v.Replace('і','и').Replace('ї','и').Replace('є','е').Replace('ґ','г').Replace('ё','е')
  # Типові підміни ru-RU OCR на ігровому шрифті: «Зірка» → «3iPka».
  $v=$v.Replace('3','з').Replace('i','и').Replace('j','и')
  # ru-RU OCR читає українське «Ці» в «Цікавий» як одну літеру «Ш».
  $v=$v.Replace('шк','цик')
  $v=$v.Replace('a','а').Replace('b','в').Replace('c','с').Replace('e','е').Replace('h','н')
  $v=$v.Replace('k','к').Replace('m','м').Replace('o','о').Replace('p','р').Replace('t','т')
  $v=$v.Replace('x','х').Replace('y','у')
  $v=($v-replace '[^а-яa-z0-9]','')
  $v.Replace('цввий','цикавий')
}
function Capture-OcrArea($left,$top,$right,$bottom,$name){
  $width=[int]$right-[int]$left;$height=[int]$bottom-[int]$top
  if($width-le 0-or$height-le 0){throw "Некоректний розмір OCR-області: $width x $height"}
  $bmp=[Drawing.Bitmap]::new([int]$width,[int]$height)
  $g=[Drawing.Graphics]::FromImage($bmp)
  try{$g.CopyFromScreen([int]$left,[int]$top,0,0,$bmp.Size);$tmp=Join-Path $env:TEMP $name;$bmp.Save($tmp,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$bmp.Dispose()}
  $tmp
}
function Convert-ToTitleTextOcrImage($sourcePath,$name){
  # У вікні «Виберіть титул для відображення» вже показані наявні титули.
  # Зелений означає лише поточний вибір, тому зберігаємо і світло-сірий,
  # і зелений текст, прибираючи темний фон.
  $source=[Drawing.Bitmap]::FromFile($sourcePath)
  $result=[Drawing.Bitmap]::new($source.Width,$source.Height,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $graphics=[Drawing.Graphics]::FromImage($result)
  try{
    $graphics.Clear([Drawing.Color]::White)
    for($y=0;$y-lt$source.Height;$y++){
      for($x=0;$x-lt$source.Width;$x++){
        $pixel=$source.GetPixel($x,$y)
        $isLight=($pixel.R-ge 85-and$pixel.G-ge 85-and$pixel.B-ge 70-and[Math]::Abs([int]$pixel.R-[int]$pixel.G)-lt 55)
        $isGreen=($pixel.G-ge 90-and([int]$pixel.G-[int]$pixel.R)-ge 28-and([int]$pixel.G-[int]$pixel.B)-ge 28)
        $isBlue=($pixel.B-ge 105-and([int]$pixel.B-[int]$pixel.R)-ge 28)
        $isRed=($pixel.R-ge 145-and$pixel.G-lt 105-and([int]$pixel.R-[int]$pixel.G)-ge 38)
        $isPurple=($pixel.R-ge 95-and$pixel.B-ge 95-and([int]$pixel.R-[int]$pixel.G)-ge 22-and([int]$pixel.B-[int]$pixel.G)-ge 18)
        $isCyan=($pixel.G-ge 95-and$pixel.B-ge 95-and([int]$pixel.G-[int]$pixel.R)-ge 22)
        if($isLight-or$isGreen-or$isBlue-or$isRed-or$isPurple-or$isCyan){
          $result.SetPixel($x,$y,[Drawing.Color]::Black)
        }
      }
    }
    $tmp=Join-Path $env:TEMP $name
    $result.Save($tmp,[Drawing.Imaging.ImageFormat]::Png)
  }finally{$graphics.Dispose();$result.Dispose();$source.Dispose()}
  $tmp
}
function Get-TextSimilarity($left,$right){
  $a=[string]$left;$b=[string]$right
  if($a-eq$b){return 1.0}
  if(-not$a-or-not$b){return 0.0}
  $previous=New-Object int[] ($b.Length+1)
  $current=New-Object int[] ($b.Length+1)
  for($j=0;$j-le$b.Length;$j++){$previous[$j]=$j}
  for($i=1;$i-le$a.Length;$i++){
    $current[0]=$i
    for($j=1;$j-le$b.Length;$j++){
      $cost=if($a[$i-1]-eq$b[$j-1]){0}else{1}
      $current[$j]=[Math]::Min([Math]::Min($current[$j-1]+1,$previous[$j]+1),$previous[$j-1]+$cost)
    }
    $swap=$previous;$previous=$current;$current=$swap
  }
  1.0-([double]$previous[$b.Length]/[Math]::Max($a.Length,$b.Length))
}
function Mark-TitlesFromLines($lines){
  $found=0;$byName=@{};$matchedByIndex=@{};$pending=@{}
  foreach($t in $script:Titles){
    $nameKey=Normalize-Words $t.name
    if($nameKey.Length-ge 3){
      if(-not$byName.ContainsKey($nameKey)){$byName[$nameKey]=@()}
      $byName[$nameKey]=@($byName[$nameKey])+@($t)
    }
  }
  $lineItems=@($lines)
  $positioned=@($lineItems|Where-Object{$_.PSObject.Properties['Left']})
  $minLeft=if($positioned.Count){[double](($positioned|Measure-Object Left -Minimum).Minimum)}else{0}
  $lineIndex=-1
  foreach($line in $lineItems){
    $lineIndex++
    $lineText=if($line.PSObject.Properties['Text']){[string]$line.Text}else{[string]$line}
    $lineLeft=if($line.PSObject.Properties['Left']){[double]$line.Left}else{$minLeft}
    $hasTrailingInk=if($line.PSObject.Properties['HasTrailingInk']){[bool]$line.HasTrailingInk}else{$true}
    $lineKey=Normalize-Words $lineText
    if(-not$lineKey-or$lineKey.Length-lt 3){continue}
    $previousLineKey=if($lineIndex-gt 0){
      $previousLine=$lineItems[$lineIndex-1]
      Normalize-Words $(if($previousLine.PSObject.Properties['Text']){[string]$previousLine.Text}else{[string]$previousLine})
    }else{''}
    $nextLineKey=if($lineIndex+1-lt$lineItems.Count){
      $nextLine=$lineItems[$lineIndex+1]
      Normalize-Words $(if($nextLine.PSObject.Properties['Text']){[string]$nextLine.Text}else{[string]$nextLine})
    }else{''}
    # Якщо є лише одне розпізнане слово і воно починається значно правіше за
    # інші рядки, OCR, імовірно, загубив початок («Путівна зірка» -> «Зірка»).
    $looksTruncated=(($lineText.Trim()-notmatch '\s')-and($lineLeft-$minLeft)-ge 22)
    $longerPrefixMatches=@($byName.Keys|Where-Object{$_.Length-gt$lineKey.Length-and$_.StartsWith($lineKey)-and@($byName[$_]).Count-eq 1})
    $ambiguousShortExact=(($lineText.Trim()-notmatch '\s')-and$hasTrailingInk-and$byName.ContainsKey($lineKey)-and@($byName[$lineKey]).Count-eq 1-and$longerPrefixMatches.Count-gt 0)
    $contextRule=@($script:OcrContextRules|Where-Object{
      $_.Key-eq$lineKey-and
      (-not$_.PreviousKey-or$previousLineKey-eq$_.PreviousKey)-and
      (-not$_.NextKey-or$nextLineKey-eq$_.NextKey)
    }|Select-Object -First 1)
    $targetName=if($contextRule.Count){[string]$contextRule[0].Target}elseif($script:OcrRules.ContainsKey($lineKey)){[string]$script:OcrRules[$lineKey]}else{$null}
    if($targetName){
      $ruleTargets=@($script:Titles|Where-Object{$_.name-eq$targetName})
      if($ruleTargets.Count-ge 1){
        # У клієнті існують різні внутрішні ID з однаковою видимою назвою
        # (наприклад, два «Сміливці»). Підтверджене персональне правило має
        # відмітити всі однойменні записи, інакше один завжди лишається білим.
        foreach($ruleTarget in $ruleTargets){
          if(-not$script:Done[$ruleTarget.id]){$found++}
          $script:Done[$ruleTarget.id]=$true
        }
        $t=$ruleTargets[0];$matchedByIndex[$lineIndex]=$t
        continue
      }
    }
    # Точний збіг завжди важливіший за довші назви, що містять його.
    # Наприклад, «Мудрець» не можна відкидати лише через наявність у базі
    # «Небесний мудрець» та «Мудрець з Міста Драконів».
    if(-not$looksTruncated-and-not$ambiguousShortExact-and$byName.ContainsKey($lineKey)-and@($byName[$lineKey]).Count-eq 1){
      $t=@($byName[$lineKey])[0]
      if(-not$script:Done[$t.id]){$found++};$script:Done[$t.id]=$true
      $matchedByIndex[$lineIndex]=$t
      continue
    }
    # Для трилітерних назв на кшталт «Кат» дозволений лише точний збіг вище.
    if($lineKey.Length-lt 4){continue}
    if($ambiguousShortExact){
      $pending[$lineIndex]=[pscustomobject]@{Key=$lineKey;Text=$lineText}
      continue
    }
    # Клієнт обрізає довгі назви по правому краю списку. Якщо видимий початок
    # має рівно одне продовження, воно безпечне: «Мисливець за» однозначно
    # означає «Мисливець за привидами». Кілька «Зірка Міста ...» не вгадуємо.
    if(-not$looksTruncated){
      $prefixMatches=@($byName.Keys|Where-Object{$_.Length-gt$lineKey.Length-and$_.StartsWith($lineKey)-and@($byName[$_]).Count-eq 1})
      if($prefixMatches.Count-eq 1){
        $t=@($byName[$prefixMatches[0]])[0]
        if(-not$script:Done[$t.id]){$found++};$script:Done[$t.id]=$true
        $matchedByIndex[$lineIndex]=$t
        continue
      }
    }
    # Одне слово плюс видимий текст праворуч — це початок, а не закінчення
    # назви. Не перетворюємо «Герой» на «Небесний герой», «Охоронець» на
    # «Правоохоронець» або «Лицар» на «Мандрівний лицар».
    if(-not$looksTruncated-and($lineText.Trim()-notmatch '\s')-and$hasTrailingInk){
      $pending[$lineIndex]=[pscustomobject]@{Key=$lineKey;Text=$lineText}
      continue
    }
    # Надійним частковим збігом є лише випадок, коли назва з бази містить
    # побачений OCR-фрагмент. Зворотний випадок не беремо: «привиднол» містить
    # «привид», але насправді це OCR-помилка в повній назві «Привид ночі».
    $containing=@($byName.Keys|Where-Object{$_.Length-ge 5-and$_.Contains($lineKey)})
    if($looksTruncated){$containing=@($containing|Where-Object{$_-ne$lineKey})}
    # Якщо OCR обрізав «Шукач драконів» до «Шукач», не вгадуємо між
    # короткою і довгою назвою. Так само не вгадуємо два «Сміливці».
    if($containing.Count-eq 1-and@($byName[$containing[0]]).Count-eq 1){
      $t=@($byName[$containing[0]])[0]
      if(-not$script:Done[$t.id]){$found++};$script:Done[$t.id]=$true
      $matchedByIndex[$lineIndex]=$t
      continue
    }elseif($containing.Count-gt 1){
      # Windows ru-RU OCR іноді губить перше слово: «Яскраві руки» -> «руки».
      # Серед назв із тим самим закінченням беремо коротшу лише тоді, коли вона
      # помітно коротша за наступну. Це знаходить «Яскраві руки», але не робить
      # випадковий вибір між майже однаковими назвами.
      $suffix=@($containing|Where-Object{$_.EndsWith($lineKey)-and@($byName[$_]).Count-eq 1}|Sort-Object Length)
      if($suffix.Count-ge 1-and$suffix[0].Length-le($lineKey.Length+10)-and($suffix.Count-eq 1-or($suffix[1].Length-$suffix[0].Length)-ge 4)){
        $t=@($byName[$suffix[0]])[0]
        if(-not$script:Done[$t.id]){$found++};$script:Done[$t.id]=$true
        $matchedByIndex[$lineIndex]=$t
      }
      if(-not$matchedByIndex.ContainsKey($lineIndex)){$pending[$lineIndex]=[pscustomobject]@{Key=$lineKey;Text=$lineText}}
      continue
    }
    # ru-RU OCR плутає українські літери та апострофи. Дозволяємо невелику
    # відстань редагування, але тільки за чіткої переваги одного кандидата.
    $ranked=@()
    foreach($nameKey in $byName.Keys){
      if(@($byName[$nameKey]).Count-ne 1){continue}
      if([Math]::Abs($nameKey.Length-$lineKey.Length)-gt[Math]::Max(4,[int]($nameKey.Length*.35))){continue}
      $ranked+=,[pscustomobject]@{Key=$nameKey;Score=(Get-TextSimilarity $lineKey $nameKey)}
    }
    $ranked=@($ranked|Sort-Object Score -Descending)
    if($ranked.Count-and$ranked[0].Score-ge .74-and($ranked.Count-eq 1-or($ranked[0].Score-$ranked[1].Score)-ge .08)){
      $t=@($byName[$ranked[0].Key])[0]
      if(-not$script:Done[$t.id]){$found++};$script:Done[$t.id]=$true
      $matchedByIndex[$lineIndex]=$t
      continue
    }
    $pending[$lineIndex]=[pscustomobject]@{Key=$lineKey;Text=$lineText}
  }
  # Другий прохід для назв, від яких OCR залишив лише спільний префікс.
  # Використовуємо тільки безпосереднього сусіда з clientTitleId +/-1 і лише
  # коли це дає рівно одного кандидата. Так «Сама» перед titleId 1677 стає
  # «Сама винахідливість» (1678), але без сусіда жоден із трьох варіантів
  # «Сама ...» не буде вгаданий.
  for($pass=0;$pass-lt 3;$pass++){
    $resolvedAny=$false
    foreach($idx in @($pending.Keys|Sort-Object)){
      $key=[string]$pending[$idx].Key
      $candidateKeys=@($byName.Keys|Where-Object{$_.Length-ge$key.Length-and$_.StartsWith($key)-and@($byName[$_]).Count-eq 1})
      $candidates=@($candidateKeys|ForEach-Object{@($byName[$_])[0]})
      if(-not$candidates.Count){continue}
      $valid=@()
      foreach($candidate in $candidates){
        $cid=[int]$candidate.clientTitleId;$fits=$false
        if($matchedByIndex.ContainsKey([int]$idx-1)-and$cid-eq([int]$matchedByIndex[[int]$idx-1].clientTitleId-1)){$fits=$true}
        if($matchedByIndex.ContainsKey([int]$idx+1)-and$cid-eq([int]$matchedByIndex[[int]$idx+1].clientTitleId+1)){$fits=$true}
        if($fits){$valid+=,$candidate}
      }
      $valid=@($valid|Sort-Object id -Unique)
      if($valid.Count-eq 1){
        $t=$valid[0]
        if(-not$script:Done[$t.id]){$found++};$script:Done[$t.id]=$true
        $matchedByIndex[[int]$idx]=$t;$pending.Remove($idx);$resolvedAny=$true
      }
    }
    if(-not$resolvedAny){break}
  }
  $script:LastLineResults=@()
  for($i=0;$i-lt$lineItems.Count;$i++){
    $item=$lineItems[$i]
    $text=if($item.PSObject.Properties['Text']){[string]$item.Text}else{[string]$item}
    $key=Normalize-Words $text
    $matched=if($matchedByIndex.ContainsKey($i)){[string]$matchedByIndex[$i].name}else{$null}
    $candidates=@()
    if(-not$matched-and$key){
      $rank=@()
      foreach($title in $script:Titles){
        $titleKey=Normalize-Words $title.name
        $rank+=,[pscustomobject]@{Name=[string]$title.name;Score=(Get-TextSimilarity $key $titleKey)}
      }
      $candidates=@($rank|Sort-Object Score -Descending|Select-Object -First 3|ForEach-Object{"$($_.Name) [$([Math]::Round($_.Score,2))]"})
    }
    $script:LastLineResults+=,[pscustomobject]@{Ocr=$text;Normalized=$key;Matched=$matched;Status=if($matched){'MATCHED'}else{'UNMATCHED'};Candidates=$candidates}
  }
  Save-State
  $found
}
function Send-WheelSteps($x,$y,$delta,$steps){
  [NativePw]::SetCursorPos([int]$x,[int]$y)|Out-Null
  for($i=0;$i-lt$steps;$i++){[NativePw]::Wheel([int]$delta);Start-Sleep -Milliseconds 35}
}
function Scan-Titles {
  try{
    $form.WindowState='Minimized';if(-not(Focus-Game)){$form.WindowState='Normal';return};Start-Sleep -Milliseconds 250
    $game=Get-GameProcess;$rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($game.MainWindowHandle,[ref]$rect)|Out-Null
    $w=$rect.Right-$rect.Left;$h=$rect.Bottom-$rect.Top
    $lo=[int]$script:Config.TitleLeftOffset;$to=[int]$script:Config.TitleTopOffset;$ro=[int]$script:Config.TitleRightOffset;$bo=[int]$script:Config.TitleBottomOffset
    if($lo-le 0-or$to-le 0-or$ro-le$lo-or$bo-le$to-or$ro-gt$w-or$bo-gt$h){throw 'OCR-область не налаштована для поточного вікна CyberPW. Повторно відкалібруйте обидва кути правого списку.'}
    $left=[int]$rect.Left+$lo;$top=[int]$rect.Top+$to;$right=[int]$rect.Left+$ro;$bottom=[int]$rect.Top+$bo
    $tmp=Capture-OcrArea $left $top $right $bottom 'cyberpw-title-scan.png'
    $cleanTmp=Convert-ToTitleTextOcrImage $tmp 'cyberpw-title-scan-clean.png'
    $titleLines=Read-OcrLines $cleanTmp;$found=if(@($titleLines).Count) { Mark-TitlesFromLines $titleLines } else { 0 }
    $form.WindowState='Normal';$form.Activate();Refresh-List;$list.Invalidate()
    [Windows.Forms.MessageBox]::Show("Знайдено нових титулів у цій вкладці: $found`r`n`r`nЯкщо справа є прокрутка — прокрутіть список і скануйте ще раз. Потім виберіть наступну вкладку зліва та повторіть.")|Out-Null
  }catch{$form.WindowState='Normal';$form.Activate();[Windows.Forms.MessageBox]::Show($_.Exception.Message)|Out-Null}
}
function Scan-AllOwnedTitles {
  if(-not$script:OcrSupported){
    $form.WindowState='Normal';$form.Activate()
    [Windows.Forms.MessageBox]::Show('Автоматичний OCR-скан недоступний у Windows 7. Використовуйте пошук, ручні зелені позначки та встановлення міток — ці функції підтримуються.','Режим Windows 7')|Out-Null
    return
  }
  try{
    $form.WindowState='Minimized'
    if(-not(Focus-Game)){$form.WindowState='Normal';return}
    $game=Get-GameProcess;$rect=New-Object NativePw+RECT;[NativePw]::GetWindowRect($game.MainWindowHandle,[ref]$rect)|Out-Null
    $windowWidth=[int]$rect.Right-[int]$rect.Left;$windowHeight=[int]$rect.Bottom-[int]$rect.Top
    $titleLo=[int]$script:Config.TitleLeftOffset;$titleTo=[int]$script:Config.TitleTopOffset;$titleRo=[int]$script:Config.TitleRightOffset;$titleBo=[int]$script:Config.TitleBottomOffset
    if($titleLo-le 0-or$titleTo-le 0-or$titleRo-le$titleLo-or$titleBo-le$titleTo-or$titleRo-gt$windowWidth-or$titleBo-gt$windowHeight){throw 'Відкрийте вікно «Виберіть титул для відображення» та відкалібруйте два кути області з довгим списком назв.'}
    $titleLeft=[int]$rect.Left+$titleLo;$titleTop=[int]$rect.Top+$titleTo;$titleRight=[int]$rect.Left+$titleRo;$titleBottom=[int]$rect.Top+$titleBo
    # Тримаємо курсор біля смуги прокрутки: над назвами гра показує tooltip,
    # який заважає OCR. DirectX-клієнт надійніше приймає багато стандартних
    # імпульсів +/-120, ніж один великий delta.
    $scrollX=[int]($titleRight-10);$scrollY=[int](($titleTop+$titleBottom)/2)
    # Завжди починаємо з абсолютного верху. 80 імпульсів було недостатньо
    # після довгого попереднього скану, через що наступний прохід стартував
    # із середини. 400 має великий безпечний запас для всього списку.
    Send-WheelSteps $scrollX $scrollY 120 400;Start-Sleep -Milliseconds 650
    $seenPages=@{};$totalFound=0;$pages=0;$sameCount=0;$scanInitialized=$false;$scanReport=@()
    # Зберігаємо сирий і очищений кадр кожної унікальної сторінки. Це дає
    # змогу перевірити невпізнані титули візуально, а не вгадувати за OCR.
    $scanSessionDir=Join-Path $AppDir (Join-Path 'scan-pages' (Get-Date -Format 'yyyyMMdd-HHmmss'))
    [IO.Directory]::CreateDirectory($scanSessionDir)|Out-Null
    for($page=0;$page-lt 400;$page++){
      $titleImage=Capture-OcrArea $titleLeft $titleTop $titleRight $titleBottom 'cyberpw-owned-titles.png'
      # Повний кадр потрібен для визначення сторінки/кінця прокрутки.
      # У цьому списку всі показані назви вже отримані; колір не має значення.
      $titleText=Read-Ocr $titleImage;$pageKey=Normalize-Words $titleText
      if(-not$pageKey){throw 'OCR не побачив назв. Перевірте, що область охоплює лише список праворуч, а текст у грі видимий.'}
      # Отримані титули не зникають у персонажа. OCR різних проходів може
      # прочитати той самий кольоровий рядок по-різному, тому новий скан лише
      # додає підтверджені титули й ніколи не стирає вже знайдені.
      if(-not$scanInitialized){$scanInitialized=$true}
      if($seenPages.ContainsKey($pageKey)){$sameCount++}else{
        $seenPages[$pageKey]=$true;$sameCount=0;$pages++
        $cleanImage=Convert-ToTitleTextOcrImage $titleImage 'cyberpw-owned-titles-clean.png'
        Copy-Item -LiteralPath $titleImage -Destination (Join-Path $scanSessionDir ('page-{0:D3}-raw.png'-f$pages)) -Force
        Copy-Item -LiteralPath $cleanImage -Destination (Join-Path $scanSessionDir ('page-{0:D3}-clean.png'-f$pages)) -Force
        $ownedLines=Read-OcrLineInfoWithFallback $cleanImage
        if(@($ownedLines).Count){
          $totalFound+=(Mark-TitlesFromLines $ownedLines)
          foreach($row in @($script:LastLineResults)){
            $scanReport+=,[pscustomobject]@{Page=$pages;Ocr=$row.Ocr;Normalized=$row.Normalized;Status=$row.Status;Matched=$row.Matched;Candidates=$row.Candidates}
          }
          Save-ScanReport $scanReport
        }
      }
      # Вісім однакових кадрів після звичайних кроків колеса означають,
      # що список справді стоїть у кінці, а не пропустив один імпульс.
      if($sameCount-ge 8){break}
      # Три кроки дають значно більше перекриття між кадрами. Кольоровий або
      # тонкий рядок тепер потрапляє в OCR-зону кілька разів на різній висоті.
      Send-WheelSteps $scrollX $scrollY -120 3;Start-Sleep -Milliseconds 340
    }
    # Наступний запуск має знову починатися з першого титулу.
    Send-WheelSteps $scrollX $scrollY 120 400;Start-Sleep -Milliseconds 350
    Save-State;Save-ScanReport $scanReport;$form.WindowState='Normal';$form.Activate();Refresh-List;$list.Invalidate()
    $unmatched=@($scanReport|Where-Object Status -eq 'UNMATCHED').Count
    [Windows.Forms.MessageBox]::Show("Автосканування завершено.`r`nСторінок списку оброблено: $pages`r`nРозпізнано отриманих титулів: $totalFound`r`nНерозпізнаних рядків: $unmatched`r`n`r`nДетальний журнал: scan-report.json`r`nКадри сторінок: $scanSessionDir")|Out-Null
  }catch{
    # Навіть після помилки намагаємося повернути список угору, якщо область
    # сканування вже була успішно обчислена.
    try{if($scrollX-and$scrollY){Focus-Game|Out-Null;Send-WheelSteps $scrollX $scrollY 120 400}}catch{}
    try{Save-State;if($scanReport){Save-ScanReport $scanReport}}catch{}
    $form.WindowState='Normal';$form.Activate();Refresh-List;$list.Invalidate()
    [Windows.Forms.MessageBox]::Show("Автосканування зупинено, але вже знайдене збережено.`r`n`r`n$($_.Exception.Message)")|Out-Null
  }
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

$form=New-Object Windows.Forms.Form; $form.Text='CyberPW — Titles Assistant · OCR R11'; $form.Size='960,830'; $form.MinimumSize='820,660'; $form.StartPosition='CenterScreen'; $form.BackColor=$jadeDark; $form.ForeColor='White'; $form.Font=New-Object Drawing.Font('Segoe UI',10);$form.MaximizeBox=$true;$form.AutoScaleMode='Dpi';$form.AutoScroll=$true
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
  try{$e.Graphics.FillRectangle($bgBrush,$e.Bounds);$e.Graphics.DrawString([string]$t.name,$e.Font,$brush,[single]($e.Bounds.X+7),[single]($e.Bounds.Y+2))}finally{$brush.Dispose();$bgBrush.Dispose()}
  $e.DrawFocusRectangle()
})
$progress=New-Object Windows.Forms.Label; $progress.SetBounds(20,646,390,28);$progress.ForeColor=$goldSoft
$titleLbl=New-Object Windows.Forms.Label; $titleLbl.Text='ПОТОЧНА МІТКА'; $titleLbl.ForeColor=$goldSoft;$titleLbl.SetBounds(450,151,220,25)
$coord=New-Object Windows.Forms.Label; $coord.Text='—'; $coord.Font=New-Object Drawing.Font('Segoe UI',24,[Drawing.FontStyle]::Bold); $coord.ForeColor=$gold; $coord.SetBounds(450,176,350,48)
$note=New-Object Windows.Forms.Label; $note.SetBounds(450,226,455,52);$note.ForeColor=$textSoft
$doneBox=New-Object Windows.Forms.CheckBox; $doneBox.Text='Титул уже отримано'; $doneBox.SetBounds(450,276,190,30);$doneBox.ForeColor=$textSoft
$coordOpenBox=New-Object Windows.Forms.CheckBox; $coordOpenBox.Text='Панель координат відкрита'; $coordOpenBox.SetBounds(665,276,240,30);$coordOpenBox.ForeColor=$textSoft
$inject=New-Object Windows.Forms.Button; $inject.Text='ПОСТАВИТИ МІТКУ В CYBERPW'; $inject.SetBounds(450,312,455,50);Style-Button $inject $jade
$settingsLbl=New-Object Windows.Forms.Label;$settingsLbl.Text='ОДНОРАЗОВЕ НАЛАШТУВАННЯ';$settingsLbl.ForeColor=$goldSoft;$settingsLbl.SetBounds(450,378,300,24)
$cal0=New-Object Windows.Forms.Button; $cal0.Text="1 · Кнопка відкриття координат (3 с)"; $cal0.SetBounds(450,405,455,34);Style-Button $cal0 $jadePanel $textSoft
$calCoord=New-Object Windows.Forms.Button; $calCoord.Text="2 · Поле введення координат (3 с)"; $calCoord.SetBounds(450,445,455,34);Style-Button $calCoord $jadePanel $textSoft
$cal1=New-Object Windows.Forms.Button; $cal1.Text='3 · Верхній лівий кут списку титулів (3 с)'; $cal1.SetBounds(450,485,455,34);Style-Button $cal1 $jadePanel $textSoft
$cal2=New-Object Windows.Forms.Button; $cal2.Text='4 · Нижній правий кут списку титулів (3 с)'; $cal2.SetBounds(450,525,455,34);Style-Button $cal2 $jadePanel $textSoft
$scan=New-Object Windows.Forms.Button; $scan.Text='АВТОСКАН УСІХ НАЯВНИХ ТИТУЛІВ'; $scan.SetBounds(450,572,455,46);Style-Button $scan ([Drawing.Color]::FromArgb(105,77,18)) $goldSoft
if(-not$script:OcrSupported){$scan.Text='АВТОСКАН НЕДОСТУПНИЙ У WINDOWS 7';$scan.BackColor=$jadeDark}
$resetDone=New-Object Windows.Forms.Button; $resetDone.Text='Скинути результати сканування'; $resetDone.SetBounds(450,626,455,30);Style-Button $resetDone $jadeDark $textSoft
$credit=New-Object Windows.Forms.Label;$credit.Text='Створив Кіт Михайло для сервера Cyber.pw · клан DarkSide';$credit.ForeColor=$textSoft;$credit.SetBounds(20,684,620,23)
$serverLink=New-Object Windows.Forms.LinkLabel;$serverLink.Text='Сайт CyberPW';$serverLink.LinkColor=$gold;$serverLink.ActiveLinkColor=$goldSoft;$serverLink.VisitedLinkColor=$gold;$serverLink.SetBounds(20,712,120,23);$serverLink.Cursor='Hand'
$refLink=New-Object Windows.Forms.LinkLabel;$refLink.Text='Реєстрація з бонусом';$refLink.LinkColor=$gold;$refLink.ActiveLinkColor=$goldSoft;$refLink.VisitedLinkColor=$gold;$refLink.SetBounds(165,712,180,23);$refLink.Cursor='Hand'
$youtube=New-Object Windows.Forms.LinkLabel;$youtube.Text='YouTube · Vitalik_Juk';$youtube.LinkColor=$gold;$youtube.ActiveLinkColor=$goldSoft;$youtube.VisitedLinkColor=$gold;$youtube.SetBounds(735,712,190,23);$youtube.TextAlign='MiddleRight';$youtube.Cursor='Hand'
$form.Controls.AddRange(@($logo,$brand,$brandSub,$divider,$searchLbl,$search,$list,$progress,$titleLbl,$coord,$note,$doneBox,$coordOpenBox,$inject,$settingsLbl,$cal0,$calCoord,$cal1,$cal2,$scan,$resetDone,$credit,$serverLink,$refLink,$youtube))
$search.Add_TextChanged({Refresh-List}); $list.Add_SelectedIndexChanged({Update-Selected})
$doneBox.Add_CheckedChanged({if($script:UpdatingSelection){return};$t=Selected-Title;if($t){$script:Done[$t.id]=$doneBox.Checked;Save-State;$list.Invalidate();Refresh-List}})
$coordOpenBox.Add_CheckedChanged({$script:CoordWindowOpen=$coordOpenBox.Checked})
$resetDone.Add_Click({if([Windows.Forms.MessageBox]::Show('Скинути всі зелені позначки й почати правильний OCR-скан заново?','Підтвердження',[Windows.Forms.MessageBoxButtons]::YesNo)-eq[Windows.Forms.DialogResult]::Yes){$script:Done=@{};Save-State;Refresh-List;$list.Invalidate()}})
$inject.Add_Click({Inject-Title}); $cal0.Add_Click({Capture-OpenPoint}); $calCoord.Add_Click({Capture-CoordPoint}); $scan.Add_Click({Scan-AllOwnedTitles}); $cal1.Add_Click({Capture-TitleCorner 'TopLeft'}); $cal2.Add_Click({Capture-TitleCorner 'BottomRight'})
$serverLink.Add_LinkClicked({try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='https://cyberpw.fun/';$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}catch{[Windows.Forms.MessageBox]::Show('Не вдалося відкрити сайт CyberPW.')|Out-Null}})
$refLink.Add_LinkClicked({try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='https://cabinet.cyberpw.fun/register.php?ref=4550';$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}catch{[Windows.Forms.MessageBox]::Show('Не вдалося відкрити реєстрацію.')|Out-Null}})
$youtube.Add_LinkClicked({try{$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='https://www.youtube.com/@Vitalik_Juk';$psi.UseShellExecute=$true;[Diagnostics.Process]::Start($psi)|Out-Null}catch{[Windows.Forms.MessageBox]::Show('Не вдалося відкрити YouTube.')|Out-Null}})
$form.Add_FormClosed({
  if($logo.Image){$logo.Image.Dispose()}
  try{$script:InstanceMutex.ReleaseMutex()}catch{}
  $script:InstanceMutex.Dispose()
})
Load-State; try{Load-Titles;Load-OcrRules}catch{[Windows.Forms.MessageBox]::Show("Не вдалося прочитати дані: $($_.Exception.Message)")|Out-Null};Save-State;Refresh-List
if($env:CYBERPW_AUTOSCAN-eq'1'){
  # Службовий режим для контрольного проходу без небезпечних екранних кліків.
  $autoScanTimer=New-Object Windows.Forms.Timer;$autoScanTimer.Interval=900
  $autoScanTimer.Add_Tick({$autoScanTimer.Stop();Scan-AllOwnedTitles})
  $autoScanTimer.Start()
}
[void](Add-CyberPWCommunityBar $form)
[void](Add-CyberPWThemeToggle $form $MyInvocation.MyCommand.Path)
[void]$form.ShowDialog()
