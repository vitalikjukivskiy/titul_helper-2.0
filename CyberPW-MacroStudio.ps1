$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class MNative {
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int c);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
 [DllImport("user32.dll")] public static extern void keybd_event(byte vk,byte scan,uint flags,UIntPtr extra);
 [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] public static extern uint GetPixel(IntPtr dc,int x,int y);
}
'@
$dir=Split-Path -Parent $MyInvocation.MyCommand.Path;. (Join-Path $dir 'CyberPW-Common.ps1');$macroDir=Join-Path $dir 'macros';if(-not(Test-Path $macroDir)){New-Item -ItemType Directory $macroDir|Out-Null}
$base=[Drawing.Color]::FromArgb(5,31,27);$panel=[Drawing.Color]::FromArgb(14,43,38);$field=[Drawing.Color]::FromArgb(9,55,47)
$gold=[Drawing.Color]::FromArgb(222,177,54);$gold2=[Drawing.Color]::FromArgb(255,225,143);$text=[Drawing.Color]::FromArgb(239,245,241)
$muted=[Drawing.Color]::FromArgb(160,186,176);$good=[Drawing.Color]::FromArgb(42,176,132);$bad=[Drawing.Color]::FromArgb(218,82,72)
function Button($t,$x,$y,$w,$h){$b=New-Object Windows.Forms.Button;$b.Text=$t;$b.SetBounds($x,$y,$w,$h);$b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=$gold;$b.BackColor=$field;$b.ForeColor=$gold2;$b.Cursor='Hand';$b}
function Add-Row($c,$a,$d){$i=$grid.Rows.Add($c,$a,$d);$grid.ClearSelection();$grid.Rows[$i].Selected=$true}
function Set-Status($t,$c){$status.Text=$t;$status.ForeColor=$c}
function Pick-Key{
 $d=New-Object Windows.Forms.Form;$d.Text='Оберіть клавішу';$d.ClientSize='825,380';$d.StartPosition='CenterParent';$d.BackColor=$base;$d.Tag=$null
 $rows=@(@('Escape','F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12'),@('D1','D2','D3','D4','D5','D6','D7','D8','D9','D0','Back','Tab'),@('Q','W','E','R','T','Y','U','I','O','P','Return'),@('A','S','D','F','G','H','J','K','L','Space'),@('Z','X','C','V','B','N','M','Left','Up','Down','Right'),@('LControlKey','LShiftKey','LMenu','RMenu','RShiftKey','RControlKey'))
 $names=@{Escape='Esc';Back='⌫';Return='Enter';Space='ПРОБІЛ';Left='←';Up='↑';Down='↓';Right='→';LControlKey='Ctrl';RControlKey='Ctrl';LShiftKey='Shift';RShiftKey='Shift';LMenu='Alt';RMenu='Alt'}
 for($r=0;$r-lt$rows.Count;$r++){$x=15;foreach($k in $rows[$r]){$w=55;if($k-in @('Back','Return','LControlKey','RControlKey','LShiftKey','RShiftKey')){$w=75};if($k-eq'Space'){$w=220};$caption=if($names[$k]){$names[$k]}else{$k-replace'^D(?=\d)',''};$b=Button $caption $x (18+$r*58) $w 44;$b.Tag=$k;$b.Add_Click({$d.Tag=$this.Tag;$d.DialogResult='OK';$d.Close()});$d.Controls.Add($b);$x+=$w+6}}
 Apply-CyberPWVisualPolish $d;if($d.ShowDialog($form)-eq'OK'){[string]$d.Tag}
}
function Read-Pixel($x,$y){$dc=[MNative]::GetDC([IntPtr]::Zero);try{$v=[MNative]::GetPixel($dc,$x,$y);$r=$v-band255;$g=($v-shr8)-band255;$b=($v-shr16)-band255;[pscustomobject]@{R=$r;G=$g;B=$b;Hex=('#{0:X2}{1:X2}{2:X2}'-f$r,$g,$b)}}finally{[void][MNative]::ReleaseDC([IntPtr]::Zero,$dc)}}
function Capture-Pixel{[Windows.Forms.MessageBox]::Show('Після натискання OK у вас буде 3 секунди, щоб навести курсор на потрібний піксель.','Захоплення кольору')|Out-Null;Start-Sleep -Seconds 3;$p=[Windows.Forms.Cursor]::Position;$c=Read-Pixel $p.X $p.Y;Add-Row 'WAITCOLOR' "$($p.X) $($p.Y) $($c.Hex) 10 10000" 'Чекати появи кольору'}function Compile{
 $out=New-Object Collections.ArrayList;$stack=New-Object Collections.Stack
 foreach($r in $grid.Rows){$c=[string]$r.Cells[0].Value;$a=[string]$r.Cells[1].Value;$line=$r.Index+1
  switch($c){
   'WAIT'{$n=0;if(-not[int]::TryParse($a,[ref]$n)-or$n-lt10-or$n-gt60000){throw "Рядок ${line}: пауза 10–60000 мс"};[void]$out.Add([pscustomobject]@{C=$c;A=$a})}
   {$_-in @('KEY','KEYDOWN','KEYUP')} {if(-not$a){throw "Рядок ${line}: виберіть клавішу"};[void]$out.Add([pscustomobject]@{C=$c;A=$a})}
   'TEXT'{[void]$out.Add([pscustomobject]@{C=$c;A=$a})}
   'MOVE'{if($a-notmatch'^\s*\d+\s+\d+\s*$'){throw "Рядок ${line}: формат координат X Y"};[void]$out.Add([pscustomobject]@{C=$c;A=$a})}
   'CLICK'{if($a-notin @('LEFT','RIGHT','MIDDLE')){throw "Рядок ${line}: невідома кнопка миші"};[void]$out.Add([pscustomobject]@{C=$c;A=$a})}
   'WAITCOLOR'{if($a-notmatch'^\s*\d+\s+\d+\s+#[0-9A-Fa-f]{6}\s+\d+\s+\d+\s*$'){throw "Рядок ${line}: формат X Y #RRGGBB допуск тайм-аут"};$q=$a-split' ';if([int]$q[3]-gt255-or[int]$q[4]-lt100){throw "Рядок ${line}: допуск 0–255, тайм-аут від 100 мс"};[void]$out.Add([pscustomobject]@{C=$c;A=$a})}
   'REPEAT'{$n=0;if(-not[int]::TryParse($a,[ref]$n)-or$n-lt1-or$n-gt1000){throw "Рядок ${line}: повтор 1–1000"};$stack.Push([pscustomobject]@{S=$out.Count;N=$n;L=$line})}
   'END'{if(-not$stack.Count){throw "Рядок ${line}: END без REPEAT"};$b=$stack.Pop();$body=@($out.GetRange($b.S,$out.Count-$b.S));for($i=1;$i-lt$b.N;$i++){foreach($s in $body){[void]$out.Add($s)}}}
  };if($out.Count-gt10000){throw 'Максимум 10000 команд'}
 };if($stack.Count){throw "REPEAT у рядку $($stack.Peek().L) не закрито"};@($out)
}
function Get-KeyCode([string]$key){[int][Windows.Forms.Keys]::$key}
function Key-Event([string]$key,[bool]$up=$false){$vk=[byte](Get-KeyCode $key);$flags=if($up){2}else{0};[MNative]::keybd_event($vk,0,$flags,[UIntPtr]::Zero)}
function Stop-Run($why='ЗУПИНЕНО'){foreach($k in @($script:held)){Key-Event $k $true};$script:held.Clear();$script:running=$false;Set-Status $why $bad}
function Set-StartHotkey{$value=$hotkey.Text.Trim().ToUpperInvariant();if($value-match'^\d$'){$value='D'+$value};if(-not $value){throw 'Введіть клавішу запуску, наприклад F10, G або 5'};if($value-eq'F12'){throw 'F12 зарезервовано для аварійної зупинки'};if(-not [Enum]::IsDefined([Windows.Forms.Keys],$value)){throw "Невідома клавіша запуску: $($hotkey.Text)"};$script:startKey=$value;$script:startWasDown=$false;$hotkey.Text=$value-replace'^D(?=\d)',''}
function Start-Run{if($script:running){return};try{Set-StartHotkey;$script:steps=@(Compile);if(-not $script:steps.Count){throw 'Додайте хоча б одну дію'};$p=@(Get-Process -Name $target.Text.Trim() -ErrorAction SilentlyContinue|Where-Object MainWindowHandle -ne 0|Select-Object -First 1);if(-not $p){throw "Не знайдено вікно $($target.Text)"};if($focus.Checked){[MNative]::ShowWindowAsync($p[0].MainWindowHandle,9)|Out-Null;[MNative]::SetForegroundWindow($p[0].MainWindowHandle)|Out-Null};$script:index=0;$script:next=[DateTime]::Now.AddMilliseconds(500);$script:running=$true;Set-Status "СТАРТ ЧЕРЕЗ 0.5 С · КЛАВІША: $($hotkey.Text)" $gold2}catch{Set-Status $_.Exception.Message $bad}}

$form=New-Object Windows.Forms.Form;$form.Text='CyberPW Macro Studio · Visual 0.4';$form.ClientSize='1180,750';$form.MinimumSize='1000,670';$form.StartPosition='CenterScreen';$form.BackColor=$base;$form.ForeColor=$text;$form.Font=New-Object Drawing.Font('Segoe UI',9)
$title=New-Object Windows.Forms.Label;$title.Text='MACRO STUDIO';$title.SetBounds(24,15,330,42);$title.ForeColor=$gold2;$title.Font=New-Object Drawing.Font('Segoe UI',21,[Drawing.FontStyle]::Bold)
$sub=New-Object Windows.Forms.Label;$sub.Text='Графічний конструктор · обирайте клавіші та мишку кнопками';$sub.SetBounds(26,58,650,24);$sub.ForeColor=$muted
$name=New-Object Windows.Forms.TextBox;$name.SetBounds(25,115,290,30);$name.Text='Новий макрос';$name.BackColor=$field;$name.ForeColor=$text
$target=New-Object Windows.Forms.TextBox;$target.SetBounds(335,115,220,30);$target.Text='ElementClient';$target.BackColor=$field;$target.ForeColor=$text
$focus=New-Object Windows.Forms.CheckBox;$focus.Text='Активувати вікно перед запуском';$focus.SetBounds(580,114,280,30);$focus.Checked=$true;$focus.ForeColor=$text
$grid=New-Object Windows.Forms.DataGridView;$grid.SetBounds(25,170,760,380);$grid.Anchor='Top,Bottom,Left,Right';$grid.BackgroundColor=$field;$grid.GridColor=[Drawing.Color]::FromArgb(30,86,72);$grid.RowHeadersVisible=$false;$grid.AllowUserToAddRows=$false;$grid.AllowUserToResizeRows=$false;$grid.SelectionMode='FullRowSelect';$grid.MultiSelect=$false;$grid.RowTemplate.Height=35;$grid.EnableHeadersVisualStyles=$false;$grid.ColumnHeadersDefaultCellStyle.BackColor=$panel;$grid.ColumnHeadersDefaultCellStyle.ForeColor=$gold2;$grid.DefaultCellStyle.BackColor=$field;$grid.DefaultCellStyle.ForeColor=$text;$grid.DefaultCellStyle.SelectionBackColor=[Drawing.Color]::FromArgb(20,126,99)
[void]$grid.Columns.Add('C','КОМАНДА');[void]$grid.Columns.Add('A','ЗНАЧЕННЯ');[void]$grid.Columns.Add('D','ОПИС');$grid.Columns[0].Width=125;$grid.Columns[1].Width=220;$grid.Columns[2].AutoSizeMode='Fill';$grid.Columns[0].ReadOnly=$true;$grid.Columns[2].ReadOnly=$true
$key=Button 'КЛАВІША' 25 585 125 42;$hold=Button '⇩ ЗАТИСНУТИ' 160 585 125 42;$release=Button '⇧ ВІДПУСТИТИ' 295 585 135 42;$wait=Button '◷ ПАУЗА' 440 585 105 42;$write=Button 'T ТЕКСТ' 555 585 105 42;$click=Button 'КЛІК МИШІ' 670 585 115 42
$move=Button '⌖ КУРСОР' 25 638 125 42;$repeat=Button '↻ ПОВТОР' 160 638 125 42;$end=Button '↳ КІНЕЦЬ' 295 638 135 42;$up=Button '▲' 440 638 55 42;$down=Button '▼' 505 638 55 42;$delete=Button 'ВИДАЛИТИ' 570 638 105 42;$pixel=Button 'ПІКСЕЛЬ' 685 638 100 42
$side=New-Object Windows.Forms.Panel;$side.SetBounds(810,170,345,380);$side.BackColor=$panel;$side.Anchor='Top,Right'
$help=New-Object Windows.Forms.Label;$help.Text="ЯК ЦЕ ПРАЦЮЄ`r`n`r`n1. Додайте дію знизу.`r`n2. Оберіть клавішу на клавіатурі.`r`n3. Значення редагуються в таблиці.`r`n4. Стрілками змініть порядок.`r`n5. Введіть клавішу старту й запускайте.`r`n`r`nF12 — аварійна зупинка.";$help.SetBounds(20,20,305,190);$help.ForeColor=$text;$help.Font=New-Object Drawing.Font('Segoe UI',10)
$new=Button 'НОВИЙ' 18 220 95 36;$open=Button 'ВІДКРИТИ' 123 220 100 36;$save=Button 'ЗБЕРЕГТИ' 233 220 95 36;$check=Button 'ПЕРЕВІРИТИ' 18 275 140 42;$run=Button '▶ ЗАПУСТИТИ' 168 275 160 42;$hotkeyLabel=New-Object Windows.Forms.Label;$hotkeyLabel.Text='КЛАВІША:';$hotkeyLabel.SetBounds(18,337,72,24);$hotkeyLabel.ForeColor=$muted;$hotkey=New-Object Windows.Forms.TextBox;$hotkey.SetBounds(94,330,56,30);$hotkey.Text='F10';$hotkey.TextAlign='Center';$hotkey.CharacterCasing='Upper';$hotkey.BackColor=$field;$hotkey.ForeColor=$text;$stop=Button '■ СТОП · F12' 168 327 160 42;$stop.BackColor=[Drawing.Color]::FromArgb(90,30,28);$side.Controls.AddRange(@($help,$new,$open,$save,$check,$run,$hotkeyLabel,$hotkey,$stop))
$status=New-Object Windows.Forms.Label;$status.Text='ГОТОВО';$status.SetBounds(810,580,345,100);$status.ForeColor=$good;$status.Font=New-Object Drawing.Font('Segoe UI Semibold',10)

$key.Add_Click({$k=Pick-Key;if($k){Add-Row 'KEY' $k 'Натиснути клавішу'}});$hold.Add_Click({$k=Pick-Key;if($k){Add-Row 'KEYDOWN' $k 'Затиснути клавішу'}});$release.Add_Click({$k=Pick-Key;if($k){Add-Row 'KEYUP' $k 'Відпустити клавішу'}})
$wait.Add_Click({Add-Row 'WAIT' '250' 'Пауза, мс'});$write.Add_Click({Add-Row 'TEXT' 'Ваш текст' 'Ввести текст'});$move.Add_Click({Add-Row 'MOVE' '500 300' 'Координати курсора'});$repeat.Add_Click({Add-Row 'REPEAT' '3' 'Початок повтору'});$end.Add_Click({Add-Row 'END' '' 'Кінець повтору'})
$pixel.Add_Click({Capture-Pixel});$click.Add_Click({$m=New-Object Windows.Forms.ContextMenuStrip;foreach($v in @(@('LEFT','Ліва кнопка'),@('RIGHT','Права кнопка'),@('MIDDLE','Коліщатко'))){$i=New-Object Windows.Forms.ToolStripMenuItem;$i.Text=$v[1];$i.Tag=$v[0];$i.Add_Click({Add-Row 'CLICK' $this.Tag 'Клік миші'});[void]$m.Items.Add($i)};$m.Show($click,0,$click.Height)})
$delete.Add_Click({if($grid.CurrentRow){$grid.Rows.Remove($grid.CurrentRow)}});$up.Add_Click({if($grid.CurrentRow-and$grid.CurrentRow.Index-gt0){$i=$grid.CurrentRow.Index;$v=@($grid.Rows[$i].Cells|% Value);$grid.Rows.RemoveAt($i);$grid.Rows.Insert($i-1,$v);$grid.Rows[$i-1].Selected=$true}});$down.Add_Click({if($grid.CurrentRow-and$grid.CurrentRow.Index-lt$grid.Rows.Count-1){$i=$grid.CurrentRow.Index;$v=@($grid.Rows[$i].Cells|% Value);$grid.Rows.RemoveAt($i);$grid.Rows.Insert($i+1,$v);$grid.Rows[$i+1].Selected=$true}})
$check.Add_Click({try{$s=Compile;Set-Status "СЦЕНАРІЙ КОРЕКТНИЙ`r`nКоманд: $($s.Count)" $good}catch{Set-Status $_.Exception.Message $bad}});$hotkey.Add_Leave({try{Set-StartHotkey;Set-Status "КЛАВІША СТАРТУ: $($hotkey.Text)" $good}catch{Set-Status $_.Exception.Message $bad}});$new.Add_Click({if(-not$script:running){$name.Text='Новий макрос';$script:startKey='F10';$script:startWasDown=$false;$hotkey.Text='F10';$grid.Rows.Clear();Set-Status 'НОВИЙ СЦЕНАРІЙ' $good}})
$save.Add_Click({try{Set-StartHotkey;[void](Compile);$safe=$name.Text.Trim()-replace'[\\/:*?"<>|]','_';if(-not$safe){$safe='Новий макрос'};$rows=@();foreach($r in $grid.Rows){$rows+=[ordered]@{command=$r.Cells[0].Value;argument=$r.Cells[1].Value;description=$r.Cells[2].Value}};[ordered]@{schemaVersion=3;name=$safe;targetProcess=$target.Text.Trim();startHotkey=$script:startKey;steps=$rows}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 (Join-Path $macroDir ($safe+'.json'));Set-Status 'ЗБЕРЕЖЕНО' $good}catch{Set-Status $_.Exception.Message $bad}})
$open.Add_Click({$d=New-Object Windows.Forms.OpenFileDialog;$d.InitialDirectory=$macroDir;$d.Filter='Macro (*.json)|*.json';if($d.ShowDialog()-eq'OK'){try{$o=Get-Content -Raw -Encoding UTF8 $d.FileName|ConvertFrom-Json;if($o.schemaVersion-notin@(2,3)){throw 'Непідтримуваний формат макросу'};$name.Text=$o.name;$target.Text=$o.targetProcess;$loadedHotkey=if($o.PSObject.Properties['startHotkey']){[string]$o.startHotkey}else{'F10'};if(-not $loadedHotkey -or $loadedHotkey -eq 'F12' -or -not [Enum]::IsDefined([Windows.Forms.Keys],$loadedHotkey)){$loadedHotkey='F10'};$script:startKey=$loadedHotkey;$script:startWasDown=$false;$hotkey.Text=$loadedHotkey-replace'^D(?=\d)','';$grid.Rows.Clear();foreach($r in $o.steps){[void]$grid.Rows.Add($r.command,$r.argument,$r.description)};Set-Status "ВІДКРИТО · КЛАВІША: $($hotkey.Text)" $good}catch{Set-Status $_.Exception.Message $bad}}})

$script:steps=@();$script:index=0;$script:running=$false;$script:next=[DateTime]::MinValue;$script:held=New-Object Collections.Generic.HashSet[string];$script:startKey='F10';$script:startWasDown=$false
$timer=New-Object Windows.Forms.Timer;$timer.Interval=15;$timer.Add_Tick({
 $startDown=([MNative]::GetAsyncKeyState((Get-KeyCode $script:startKey)) -band 0x8000) -ne 0;if($startDown -and -not $script:startWasDown -and -not $script:running){Start-Run};$script:startWasDown=$startDown
 if(([MNative]::GetAsyncKeyState(0x7B)-band0x8000)-and$script:running){Stop-Run 'АВАРІЙНО ЗУПИНЕНО';return};if(-not$script:running-or[DateTime]::Now-lt$script:next){return};if($script:index-ge$script:steps.Count){Stop-Run 'ВИКОНАННЯ ЗАВЕРШЕНО';$status.ForeColor=$good;return}
 $s=$script:steps[$script:index];$script:index++;try{switch($s.C){WAIT{$script:next=[DateTime]::Now.AddMilliseconds([int]$s.A)}KEY{Key-Event $s.A;Key-Event $s.A $true}KEYDOWN{Key-Event $s.A;[void]$script:held.Add($s.A)}KEYUP{Key-Event $s.A $true;[void]$script:held.Remove($s.A)}TEXT{[Windows.Forms.SendKeys]::SendWait($s.A)}WAITCOLOR{$q=$s.A-split' ';$pc=Read-Pixel ([int]$q[0]) ([int]$q[1]);$hex=$q[2].TrimStart('#');$er=[Convert]::ToInt32($hex.Substring(0,2),16);$eg=[Convert]::ToInt32($hex.Substring(2,2),16);$eb=[Convert]::ToInt32($hex.Substring(4,2),16);$tol=[int]$q[3];if([Math]::Abs($pc.R-$er)-gt$tol-or[Math]::Abs($pc.G-$eg)-gt$tol-or[Math]::Abs($pc.B-$eb)-gt$tol){if(-not$s.PSObject.Properties['Since']){$s|Add-Member Since ([DateTime]::Now)};if(([DateTime]::Now-$s.Since).TotalMilliseconds-gt[int]$q[4]){throw 'Тайм-аут очікування кольору'};$script:index--;$script:next=[DateTime]::Now.AddMilliseconds(50)}}MOVE{$xy=$s.A-replace'\s+',' '-split' ';[MNative]::SetCursorPos([int]$xy[0],[int]$xy[1])|Out-Null}CLICK{switch($s.A){LEFT{[MNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[MNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}RIGHT{[MNative]::mouse_event(8,0,0,0,[UIntPtr]::Zero);[MNative]::mouse_event(16,0,0,0,[UIntPtr]::Zero)}MIDDLE{[MNative]::mouse_event(32,0,0,0,[UIntPtr]::Zero);[MNative]::mouse_event(64,0,0,0,[UIntPtr]::Zero)}}}};if($s.C-ne'WAIT'){$script:next=[DateTime]::Now.AddMilliseconds(15)};Set-Status "ВИКОНУЄТЬСЯ $($script:index)/$($script:steps.Count)" $gold2}catch{Stop-Run $_.Exception.Message}
});$timer.Start()
$run.Add_Click({Start-Run});$stop.Add_Click({Stop-Run});$form.Add_FormClosing({if($script:running){Stop-Run}})
$form.Controls.AddRange(@($title,$sub,$name,$target,$focus,$grid,$key,$hold,$release,$wait,$write,$click,$move,$repeat,$end,$up,$down,$delete,$pixel,$side,$status))
Add-Row 'KEY' 'D1' 'Натиснути клавішу';Add-Row 'WAIT' '250' 'Пауза, мс';Add-Row 'KEY' 'D2' 'Натиснути клавішу'
Apply-CyberPWVisualPolish $form;[void]$form.ShowDialog()
