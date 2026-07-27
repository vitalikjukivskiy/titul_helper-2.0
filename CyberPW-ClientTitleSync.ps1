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
function Get-CyberPWOwnedTitleIds {
  $clients=@(Get-Process -Name $script:Config.Process -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowHandle-ne[IntPtr]::Zero}|Sort-Object StartTime)
  if($clients.Count-eq 0){throw 'ElementClient не знайдено. Запустіть гру та зайдіть персонажем.'}
  $process=$clients[-1]
  $supportedHash='ADF8444231C9B86BAB64359FA3E4980D4E9BF2A759E3314180771CEE30ED3D49'
  $clientPath=Get-CyberPWClientPath $process
  $clientFile=Get-Item -LiteralPath $clientPath
  if($clientFile.Length-ne 16274944){
    throw "Ця версія ElementClient ще не підтримується (інший розмір файлу). Оновіть TitulHelper."
  }
  $clientHash=(Get-FileHash -LiteralPath $clientPath -Algorithm SHA256).Hash
  if($clientHash-ne$supportedHash){
    throw "Ця версія ElementClient ще не підтримується (контрольна сума не збігається). Оновіть TitulHelper."
  }
  $handle=[CyberPWTitleMemory]::OpenProcess(0x1010,$false,$process.Id)
  if($handle-eq[IntPtr]::Zero){
    $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Windows не дозволила читання ElementClient (код: $code)."
  }
  try{
    $moduleBase=[UInt64]$process.MainModule.BaseAddress.ToInt64()
    $root=Read-CyberPWClientValue $handle ($moduleBase+0xF0CD08) 8
    if($root-eq 0){throw 'Персонаж ще не завантажений.'}
    $layer=Read-CyberPWClientValue $handle ($root+0x38) 8
    if($layer-eq 0){throw 'Контекст гри ще не готовий.'}
    $context=Read-CyberPWClientValue $handle ($layer+0x68) 8
    if($context-eq 0){throw 'Контекст персонажа ще не готовий.'}
    $begin=Read-CyberPWClientValue $handle ($context+0x2CB8) 8
    $end=Read-CyberPWClientValue $handle ($context+0x2CC0) 8
    if($end-lt$begin-or(($end-$begin)%8)-ne 0){throw 'Клієнт повернув пошкоджену структуру титулів.'}
    $count=[int](($end-$begin)/8)
    if($count-lt 0-or$count-gt 4096){throw "Некоректна кількість титулів: $count."}
    $ids=New-Object 'System.Collections.Generic.HashSet[int]'
    for($i=0;$i-lt$count;$i++){
      $titleId=[int](Read-CyberPWClientValue $handle ($begin+[UInt64]($i*8)) 2)
      if($titleId-gt 0){[void]$ids.Add($titleId)}
    }
    [pscustomobject]@{ProcessId=$process.Id;Ids=$ids;RawCount=$count}
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
    if($result.RawCount-lt 1-or$matchedIds-lt 5-or($matchedIds/[double]$result.RawCount)-lt 0.25){
      throw "Перевірка структури не пройдена: лише $matchedIds із $($result.RawCount) ID відомі програмі. Прогрес не змінено."
    }
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
    [Windows.Forms.MessageBox]::Show("Не вдалося синхронізувати титули.`r`n`r`n$($_.Exception.Message)`r`n`r`nПереконайтеся, що персонаж уже зайшов у світ.",'TitulHelper',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Warning)|Out-Null
  }finally{$sync.Enabled=$true}
}
