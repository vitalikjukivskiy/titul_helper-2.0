Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CyberPWTitleMemory {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int processId);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] buffer, UIntPtr size, out UIntPtr read);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
}
"@

function Read-CyberPWClientValue($handle,[UInt64]$address,[int]$size){
  $buffer=New-Object byte[] $size
  $read=[UIntPtr]::Zero
  $pointer=New-Object IntPtr ([Int64]$address)
  if(-not[CyberPWTitleMemory]::ReadProcessMemory($handle,$pointer,$buffer,(New-Object UIntPtr ([UInt64]$size)),[ref]$read)-or$read.ToUInt64()-ne[UInt64]$size){
    $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Не вдалося прочитати дані клієнта (код Windows: $code)."
  }
  if($size-eq 8){return [BitConverter]::ToUInt64($buffer,0)}
  if($size-eq 2){return [BitConverter]::ToUInt16($buffer,0)}
  throw 'Непідтримуваний розмір читання.'
}

function ConvertFrom-CyberPWHexOffset([string]$value){
  if([string]::IsNullOrWhiteSpace($value)-or$value-notmatch'^0x[0-9A-Fa-f]+$'){throw "Некоректний offset у профілі клієнта: $value"}
  [Convert]::ToUInt64($value.Substring(2),16)
}
function Get-CyberPWMemoryProfile([string]$clientPath){
  $profilesPath=Join-Path $PSScriptRoot 'memory-offsets.json'
  if(-not(Test-Path -LiteralPath $profilesPath -PathType Leaf)){throw 'Не знайдено memory-offsets.json. Повторно розпакуйте CyberPW Assistant.'}
  try{$config=Get-Content -LiteralPath $profilesPath -Raw -Encoding UTF8|ConvertFrom-Json}catch{throw "Не вдалося прочитати memory-offsets.json: $($_.Exception.Message)"}
  if([int]$config.schemaVersion-ne1){throw 'Непідтримувана версія memory-offsets.json.'}
  $file=Get-Item -LiteralPath $clientPath
  $sameSize=@($config.profiles|Where-Object{[Int64]$_.fileSize-eq$file.Length})
  if($sameSize.Count-eq0){throw 'Ця версія ElementClient ще не підтримується (інший розмір файлу). Оновіть TitulHelper.'}
  $hash=(Get-FileHash -LiteralPath $clientPath -Algorithm SHA256).Hash
  $profile=@($sameSize|Where-Object{([string]$_.sha256).ToUpperInvariant()-eq$hash})|Select-Object -First 1
  if(-not$profile){throw 'Ця версія ElementClient ще не підтримується (контрольна сума не збігається). Оновіть TitulHelper.'}
  if([int]$profile.pointerSize-ne8){throw 'Профіль клієнта має непідтримуваний розмір вказівника.'}
  $profile
}
function Resolve-CyberPWPointerChain($handle,[UInt64]$moduleBase,$profile){
  $address=$moduleBase+(ConvertFrom-CyberPWHexOffset ([string]$profile.rootOffset))
  $pointer=Read-CyberPWClientValue $handle $address ([int]$profile.pointerSize)
  if($pointer-eq0){throw 'Персонаж ще не завантажений.'}
  foreach($offsetText in @($profile.characterPointerChain)){
    $pointer=Read-CyberPWClientValue $handle ($pointer+(ConvertFrom-CyberPWHexOffset ([string]$offsetText))) ([int]$profile.pointerSize)
    if($pointer-eq0){throw "Ланцюжок структури персонажа ще не готовий (offset $offsetText)."}
  }
  [UInt64]$pointer
}
function Get-CyberPWClientPath($process){
  $path=$null
  try{$path=[string]$process.MainModule.FileName}catch{}
  if([string]::IsNullOrWhiteSpace($path)){
    try{
      $info=Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction Stop
      $path=[string]$info.ExecutablePath
    }catch{}
  }
  if([string]::IsNullOrWhiteSpace($path)){
    try{
      $info=Get-WmiObject -Class Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction Stop
      $path=[string]$info.ExecutablePath
    }catch{}
  }
  if([string]::IsNullOrWhiteSpace($path)-or-not(Test-Path -LiteralPath $path -PathType Leaf)){
    throw 'Не вдалося визначити шлях до ElementClient.exe. Запустіть CyberPW Assistant з такими самими правами, що й гра (якщо гра запущена від адміністратора — помічник теж).'
  }
  return $path
}
function Get-CyberPWClientCandidates {
  @(Get-Process -Name $script:Config.Process -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne[IntPtr]::Zero}|Sort-Object StartTime)
}
function Select-CyberPWClientProcess($candidates){
  $items=@($candidates)
  if($items.Count-eq0){return $null}
  if($items.Count-eq1){return $items[0]}
  $dialog=New-Object Windows.Forms.Form
  $dialog.Text='TitulHelper — вибір персонажа';$dialog.ClientSize='560,340';$dialog.StartPosition='CenterParent';$dialog.FormBorderStyle='FixedDialog';$dialog.MaximizeBox=$false;$dialog.MinimizeBox=$false;$dialog.ShowInTaskbar=$false
  $theme=Get-CyberPWTheme;$dialog.BackColor=$theme.Base;$dialog.ForeColor=$theme.Text;$dialog.Font=New-Object Drawing.Font('Segoe UI',10)
  $title=New-Object Windows.Forms.Label;$title.Text="ВІДКРИТО КІЛЬКА КЛІЄНТІВ`r`nОберіть вікно персонажа для синхронізації титулів.";$title.SetBounds(22,18,515,50);$title.ForeColor=$theme.GoldSoft;$title.Font=New-Object Drawing.Font('Segoe UI Semibold',11)
  $listBox=New-Object Windows.Forms.ListBox;$listBox.SetBounds(22,78,515,170);$listBox.BackColor=$theme.Field;$listBox.ForeColor=$theme.Text;$listBox.BorderStyle='FixedSingle';$listBox.DisplayMember='Label'
  $number=0
  foreach($process in $items){
    $number++;$windowTitle=[string]$process.MainWindowTitle;if([string]::IsNullOrWhiteSpace($windowTitle)){$windowTitle='ElementClient'}
    $started=try{$process.StartTime.ToString('HH:mm:ss')}catch{'—'}
    $location='';try{$rect=New-Object NativePw+RECT;if([NativePw]::GetWindowRect($process.MainWindowHandle,[ref]$rect)){$location=" · екран $($rect.Left),$($rect.Top)"}}catch{}
    [void]$listBox.Items.Add([pscustomobject]@{Label="Вікно $number · $windowTitle · PID $($process.Id) · $started$location";Process=$process})
  }
  $listBox.SelectedIndex=0
  $show=New-Object Windows.Forms.Button;$show.Text='ПОКАЗАТИ ВІКНО';$show.SetBounds(22,270,165,42);$show.FlatStyle='Flat';$show.BackColor=$theme.Button;$show.ForeColor=$theme.GoldSoft;$show.FlatAppearance.BorderColor=$theme.Gold
  $choose=New-Object Windows.Forms.Button;$choose.Text='ВИБРАТИ';$choose.SetBounds(282,270,120,42);$choose.DialogResult=[Windows.Forms.DialogResult]::OK;$choose.FlatStyle='Flat';$choose.BackColor=$theme.Accent;$choose.ForeColor=$theme.Text
  $cancel=New-Object Windows.Forms.Button;$cancel.Text='СКАСУВАТИ';$cancel.SetBounds(412,270,125,42);$cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel;$cancel.FlatStyle='Flat';$cancel.BackColor=$theme.Button;$cancel.ForeColor=$theme.Text
  $show.Add_Click({if($listBox.SelectedItem){$selected=$listBox.SelectedItem.Process;[NativePw]::ShowWindowAsync($selected.MainWindowHandle,9)|Out-Null;[NativePw]::SetForegroundWindow($selected.MainWindowHandle)|Out-Null}})
  $listBox.Add_DoubleClick({if($listBox.SelectedItem){$dialog.DialogResult=[Windows.Forms.DialogResult]::OK;$dialog.Close()}})
  $dialog.AcceptButton=$choose;$dialog.CancelButton=$cancel;$dialog.Controls.AddRange(@($title,$listBox,$show,$choose,$cancel))
  $result=if($form-and-not$form.IsDisposed){$dialog.ShowDialog($form)}else{$dialog.ShowDialog()}
  try{if($result-eq[Windows.Forms.DialogResult]::OK-and$listBox.SelectedItem){return $listBox.SelectedItem.Process};return $null}finally{$dialog.Dispose()}
}

function Get-CyberPWOwnedTitleIds([Nullable[int]]$ProcessId=$null) {
  $clients=@(Get-CyberPWClientCandidates)
  if($clients.Count-eq0){throw 'ElementClient не знайдено. Запустіть гру та зайдіть персонажем.'}
  if($null-ne$ProcessId){$process=@($clients|Where-Object{$_.Id-eq[int]$ProcessId})|Select-Object -First 1;if(-not$process){throw "ElementClient PID $ProcessId не знайдено."}}
  else{$process=Select-CyberPWClientProcess $clients;if(-not$process){throw [OperationCanceledException]::new('Вибір вікна скасовано.')}}
  $clientPath=Get-CyberPWClientPath $process
  $profile=Get-CyberPWMemoryProfile $clientPath
  $handle=[CyberPWTitleMemory]::OpenProcess(0x1010,$false,$process.Id)
  if($handle-eq[IntPtr]::Zero){
    $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Windows не дозволила читання ElementClient (код: $code)."
  }
  try{
    $moduleBase=[UInt64]$process.MainModule.BaseAddress.ToInt64()
    $context=Resolve-CyberPWPointerChain $handle $moduleBase $profile
    $begin=Read-CyberPWClientValue $handle ($context+(ConvertFrom-CyberPWHexOffset ([string]$profile.titles.beginOffset))) ([int]$profile.pointerSize)
    $end=Read-CyberPWClientValue $handle ($context+(ConvertFrom-CyberPWHexOffset ([string]$profile.titles.endOffset))) ([int]$profile.pointerSize)
    $stride=[int]$profile.titles.entryStride
    if($stride-lt1-or$end-lt$begin-or(($end-$begin)%$stride)-ne0){throw 'Клієнт повернув пошкоджену структуру титулів.'}
    $count=[int](($end-$begin)/$stride)
    if($count-lt0-or$count-gt[int]$profile.titles.maxCount){throw "Некоректна кількість титулів: $count."}
    $ids=New-Object 'System.Collections.Generic.HashSet[int]'
    for($i=0;$i-lt$count;$i++){
      $titleId=[int](Read-CyberPWClientValue $handle ($begin+[UInt64]($i*$stride)) ([int]$profile.titles.idSize))
      if($titleId-gt 0){[void]$ids.Add($titleId)}
    }
    [pscustomobject]@{ProcessId=$process.Id;Profile=[string]$profile.name;Ids=$ids;RawCount=$count}
  }finally{[void][CyberPWTitleMemory]::CloseHandle($handle)}
}

function Sync-CyberPWOwnedTitles {
  try{
    $sync.Enabled=$false
    $result=Get-CyberPWOwnedTitleIds
    $knownIds=New-Object 'System.Collections.Generic.HashSet[int]'
    foreach($title in $script:Titles){if($title.clientTitleId-gt 0){[void]$knownIds.Add([int]$title.clientTitleId)}}
    $matchedIds=0
    foreach($id in $result.Ids){if($knownIds.Contains([int]$id)){$matchedIds++}}
    # Новий персонаж може мати 0–4 титули або лише серверні ID, яких немає у довіднику.
    # Структуру захищають точний хеш клієнта, фіксовані вказівники та перевірені межі вектора.
    if($result.RawCount-lt 0-or$result.RawCount-gt 4096){throw "Некоректна кількість титулів: $($result.RawCount)."}
    $matched=0
    foreach($title in $script:Titles){
      if($title.clientTitleId-gt 0){
        $owned=$result.Ids.Contains([int]$title.clientTitleId)
        $script:Done[$title.id]=$owned
        if($owned){$matched++}
      }
    }
    Save-State;Refresh-List;$list.Invalidate();Update-Selected
    [Windows.Forms.MessageBox]::Show("Синхронізацію завершено.`r`n`r`nЗнайдено у базі: $matched`r`nID у клієнті: $($result.RawCount)`r`nElementClient PID: $($result.ProcessId)",'TitulHelper — готово',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)|Out-Null
  }catch{
    if($_.Exception -is [OperationCanceledException]){return}
    [Windows.Forms.MessageBox]::Show("Не вдалося синхронізувати титули.`r`n`r`n$($_.Exception.Message)`r`n`r`nПереконайтеся, що персонаж уже зайшов у світ.",'TitulHelper',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Warning)|Out-Null
  }finally{$sync.Enabled=$true}
}
