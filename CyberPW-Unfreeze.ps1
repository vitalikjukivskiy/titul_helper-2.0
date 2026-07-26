$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'CyberPW-Common.ps1')
Add-Type @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class CyberPWWindowInput {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT {
        public uint type;
        public INPUTUNION data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION {
        [FieldOffset(0)] public KEYBDINPUT keyboard;
        [FieldOffset(0)] public MOUSEINPUT mouse;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT {
        public ushort virtualKey;
        public ushort scanCode;
        public uint flags;
        public uint time;
        public UIntPtr extraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint flags;
        public uint time;
        public UIntPtr extraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, INPUT[] inputs, int inputSize);

    public static void Activate(IntPtr handle) {
        ShowWindowAsync(handle, 9);
        if (!SetForegroundWindow(handle))
            throw new Win32Exception(Marshal.GetLastWin32Error());
    }

    public static void OpenConsole() {
        keybd_event(0x10, 0, 0, UIntPtr.Zero);
        keybd_event(0xC0, 0, 0, UIntPtr.Zero);
        keybd_event(0xC0, 0, 2, UIntPtr.Zero);
        keybd_event(0x10, 0, 2, UIntPtr.Zero);
    }

    public static void SendUnicodeText(string text) {
        foreach (char character in text) {
            INPUT[] inputs = new INPUT[2];
            inputs[0].type = 1;
            inputs[0].data.keyboard.scanCode = character;
            inputs[0].data.keyboard.flags = 0x0004;
            inputs[1].type = 1;
            inputs[1].data.keyboard.scanCode = character;
            inputs[1].data.keyboard.flags = 0x0004 | 0x0002;
            if (SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT))) != 2)
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    public static void PressEnter() {
        keybd_event(0x0D, 0, 0, UIntPtr.Zero);
        keybd_event(0x0D, 0, 2, UIntPtr.Zero);
    }
}
'@

$theme=Get-CyberPWTheme
$jade=$theme.Base
$jade2=$theme.Button
$panel=$theme.Panel
$gold=$theme.Gold
$goldSoft=$theme.GoldSoft
$textColor=$theme.Text
$muted=$theme.Muted
$cyan=$theme.AccentBright
$danger=$theme.Danger

function Style-Button($button,$back,$fore=$textColor){
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$gold
  $button.BackColor=$back;$button.ForeColor=$fore;$button.Cursor='Hand'
  $button.Font=New-Object Drawing.Font('Segoe UI Semibold',9)
}
function New-Label($value,$x,$y,$w,$h,$size,$color,$style='Regular'){
  $label=New-Object Windows.Forms.Label;$label.Text=$value;$label.SetBounds($x,$y,$w,$h)
  $label.ForeColor=$color;$label.BackColor=[Drawing.Color]::Transparent
  $label.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style)
  $label
}
function Get-GameWindows {
  @(
    Get-Process -Name ElementClient -ErrorAction SilentlyContinue |
      Where-Object {$_.MainWindowHandle-ne[IntPtr]::Zero} |
      Sort-Object Id |
      ForEach-Object {
        $title=$_.MainWindowTitle
        if([string]::IsNullOrWhiteSpace($title)){$title='ElementClient'}
        [pscustomobject]@{
          ProcessId=$_.Id
          Handle=$_.MainWindowHandle
          Title=$title
          Display="$title  ·  PID $($_.Id)"
        }
      }
  )
}
function Refresh-Windows {
  $checkedIds=@()
  for($index=0;$index-lt$windowList.Items.Count;$index++){
    if($windowList.GetItemChecked($index)){$checkedIds+=[int]$windowList.Items[$index].ProcessId}
  }
  $windowList.Items.Clear()
  foreach($window in @(Get-GameWindows)){
    $index=$windowList.Items.Add($window)
    if($checkedIds -contains [int]$window.ProcessId){$windowList.SetItemChecked($index,$true)}
  }
  $count=$windowList.Items.Count
  $summary.Text="Знайдено вікон: $count"
  if($count){$status.Text='Позначте потрібні вікна галочками.';$status.ForeColor=$muted}
  else{$status.Text='ElementClient не знайдено. Запустіть гру через MultiLauncher.';$status.ForeColor=$danger}
}
function Set-AllChecked([bool]$value){
  for($index=0;$index-lt$windowList.Items.Count;$index++){$windowList.SetItemChecked($index,$value)}
}
function Unfreeze-Selected {
  $selected=@()
  for($index=0;$index-lt$windowList.Items.Count;$index++){
    if($windowList.GetItemChecked($index)){$selected+=,$windowList.Items[$index]}
  }
  if(-not $selected.Count){
    [Windows.Forms.MessageBox]::Show('Позначте хоча б одне вікно.','Розморозка вікон')|Out-Null
    return
  }
  $unfreeze.Enabled=$false;$refresh.Enabled=$false
  $success=0;$failed=@()
  try{
    foreach($window in $selected){
      try{
        $process=Get-Process -Id $window.ProcessId -ErrorAction Stop
        if($process.MainWindowHandle-eq[IntPtr]::Zero){throw 'Вікно вже закрито'}
        [CyberPWWindowInput]::Activate($process.MainWindowHandle);Start-Sleep -Milliseconds 300
        [CyberPWWindowInput]::OpenConsole();Start-Sleep -Milliseconds 220
        [CyberPWWindowInput]::SendUnicodeText('d_rendernofocus 1')
        [CyberPWWindowInput]::PressEnter();Start-Sleep -Milliseconds 180
        $success++
      }catch{$failed+="$($window.Display): $($_.Exception.Message)"}
      [Windows.Forms.Application]::DoEvents()
    }
  }finally{$unfreeze.Enabled=$true;$refresh.Enabled=$true}
  $status.Text="Розморожено: $success з $($selected.Count)"
  $status.ForeColor=if($failed.Count){$danger}else{$cyan}
  if($failed.Count){[Windows.Forms.MessageBox]::Show(($failed-join"`r`n"),'Не всі вікна розморожено')|Out-Null}
}

$form=New-Object Windows.Forms.Form
$form.Text='Cyber.pw Asistant — Розморозка вікон'
$form.Size='820,650';$form.MinimumSize='700,560';$form.StartPosition='CenterScreen'
$form.BackColor=$jade;$form.ForeColor=$textColor;$form.Font=New-Object Drawing.Font('Segoe UI',9)
$form.AutoScaleMode='Dpi';$form.AutoScroll=$true;$form.MaximizeBox=$true

$header=New-Label 'РОЗМОРОЗКА ВІКОН' 28 18 620 40 22 $goldSoft 'Bold'
$description=New-Label 'Окремо виберіть клієнти, які мають продовжувати рендер у фоні.' 31 60 730 28 10 $muted
$summary=New-Label 'Знайдено вікон: 0' 31 102 260 25 10 $textColor 'Bold'
$refresh=New-Object Windows.Forms.Button;$refresh.Text='↻ ОНОВИТИ СПИСОК';$refresh.SetBounds(578,94,190,36);Style-Button $refresh $jade2
$refresh.Anchor='Top,Right'

$windowList=New-Object Windows.Forms.CheckedListBox
$windowList.SetBounds(30,142,738,292);$windowList.Anchor='Top,Bottom,Left,Right'
$windowList.BackColor=$panel;$windowList.ForeColor=$textColor;$windowList.BorderStyle='FixedSingle'
$windowList.CheckOnClick=$true;$windowList.Font=New-Object Drawing.Font('Segoe UI',11)
$windowList.DisplayMember='Display'

$selectAll=New-Object Windows.Forms.Button;$selectAll.Text='ПОЗНАЧИТИ ВСІ';$selectAll.SetBounds(30,450,170,36);$selectAll.Anchor='Bottom,Left';Style-Button $selectAll $jade2
$clearAll=New-Object Windows.Forms.Button;$clearAll.Text='ЗНЯТИ ВСІ';$clearAll.SetBounds(210,450,150,36);$clearAll.Anchor='Bottom,Left';Style-Button $clearAll $jade2
$unfreeze=New-Object Windows.Forms.Button;$unfreeze.Text='❄ РОЗМОРОЗИТИ ВИБРАНІ';$unfreeze.SetBounds(500,446,268,44);$unfreeze.Anchor='Bottom,Right';Style-Button $unfreeze ([Drawing.Color]::FromArgb(18,126,98))

$status=New-Label 'Оновлення списку...' 31 505 735 26 9 $muted;$status.Anchor='Bottom,Left,Right'
$hint=New-Label 'Під час операції вибрані вікна по черзі виходять на передній план. Клієнт має бути запущений із console:1.' 31 536 735 28 8 $muted
$hint.Anchor='Bottom,Left,Right'

$refresh.Add_Click({Refresh-Windows})
$selectAll.Add_Click({Set-AllChecked $true})
$clearAll.Add_Click({Set-AllChecked $false})
$unfreeze.Add_Click({Unfreeze-Selected})
$form.Controls.AddRange(@($header,$description,$summary,$refresh,$windowList,$selectAll,$clearAll,$unfreeze,$status,$hint))

Refresh-Windows
[void](Add-CyberPWCommunityBar $form)
[void](Add-CyberPWThemeToggle $form $MyInvocation.MyCommand.Path)
Apply-CyberPWVisualPolish $form;[void]$form.ShowDialog()
