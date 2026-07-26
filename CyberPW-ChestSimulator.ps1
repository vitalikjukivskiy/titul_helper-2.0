param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'CyberPW-Common.ps1')
$IconDir=Join-Path $AppDir 'loot-icons'

$theme=Get-CyberPWTheme
$jade=$theme.Base;$jade2=$theme.Button;$panel=$theme.Panel
$gold=$theme.Gold;$goldSoft=$theme.GoldSoft;$text=$theme.Text
$muted=$theme.Muted;$cyan=$theme.AccentBright;$rare=$theme.Rare
$drops=@(
  [pscustomobject]@{Name='Ідеальний приз';Chance=92.0;Stack=15;Icon='otlichniy_priz.png'},
  [pscustomobject]@{Name='Чудовий приз';Chance=2.9;Stack=1;Icon='sertifikat_yuvelira.png'},
  [pscustomobject]@{Name='Нашивка офіцера-примари';Chance=2.5;Stack=4;Icon='nabor_run_4_ur.png'},
  [pscustomobject]@{Name='Платиновий ідол';Chance=1.0;Stack=1;Icon='shkatulka_s_platinovym_idolom.png'},
  [pscustomobject]@{Name='Платиновий амулет';Chance=1.0;Stack=1;Icon='shkatulka_s_platinovym_amuletom.png'},
  [pscustomobject]@{Name='Золота монета';Chance=.1;Stack=1;Icon='bronzovaya_moneta.png'},
  [pscustomobject]@{Name='Емблема майстра меча · воїн';Chance=.1;Stack=1;Icon='vygravirovannoe_lezvie.png'},
  [pscustomobject]@{Name='Душа Меча';Chance=.05;Stack=1;Icon='spyashchaya_dusha_polkovodca.png'},
  [pscustomobject]@{Name='Нагорода істинному чемпіону';Chance=.05;Stack=1;Icon='vysshiy_kamen_bozhestva.png'},
  [pscustomobject]@{Name='Книга Долі';Chance=.05;Stack=1;Icon='svitok_drakona.png'},
  [pscustomobject]@{Name='Камінь Ночі';Chance=.05;Stack=1;Icon='kamen_nebosvoda.png'},
  [pscustomobject]@{Name='Камінь Сюань Юань';Chance=.05;Stack=1;Icon='mercayushchiy_kamen.png'},
  [pscustomobject]@{Name='Камінь Джунглів';Chance=.05;Stack=1;Icon='kamen_dzhungley.png'},
  [pscustomobject]@{Name='Зачіска · Знак місяця';Chance=.03;Stack=1;Icon='veer_zari.png'},
  [pscustomobject]@{Name='Зброя · Знак місяця';Chance=.03;Stack=1;Icon='drakonya_uprash.png'},
  [pscustomobject]@{Name='Крила бога удачі';Chance=.03;Stack=1;Icon='plash_vozn.png'},
  [pscustomobject]@{Name='Крила Пегаса';Chance=.02;Stack=1;Icon='lazurnaya_pechat.png'},
  [pscustomobject]@{Name='Знак командира';Chance=.02;Stack=1;Icon='znak_komandira.png'},
  [pscustomobject]@{Name='Печатка Куба';Chance=.02;Stack=1;Icon='pechat_kuba.png'},
  [pscustomobject]@{Name='Алмазна броня';Chance=.025;Stack=1;Icon='almaznaya_bronya.png'},
  [pscustomobject]@{Name="Кам'яна броня";Chance=.025;Stack=1;Icon='kamennaya_bronya.png'},
  [pscustomobject]@{Name='★★ Повний контроль ситуації';Chance=.010;Stack=1;Icon='shkatulka_s_kartoy_s.png'},
  [pscustomobject]@{Name='★★ Долина під владними хмарами';Chance=.010;Stack=1;Icon='dusha_tay_shang.png'},
  [pscustomobject]@{Name='Божественний сувій';Chance=.009;Stack=1;Icon='bozhestvenniy_svitok.png'},
  [pscustomobject]@{Name='★★★ Унікальне крило';Chance=.008;Stack=1;Icon='siyanie_bogini_sihe.png'}
)
$totalWeight=($drops|Measure-Object Chance -Sum).Sum
$counts=@{};$script:Opened=0;$rng=New-Object Random

function Label($value,$x,$y,$w,$h,$size,$color,$style='Regular'){$l=New-Object Windows.Forms.Label;$l.Text=$value;$l.SetBounds($x,$y,$w,$h);$l.ForeColor=$color;$l.BackColor=[Drawing.Color]::Transparent;$l.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style);$l}
function ButtonStyle($b,$back){$b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=$gold;$b.FlatAppearance.BorderSize=1;$b.BackColor=$back;$b.ForeColor=$text;$b.Cursor='Hand';$b.Font=New-Object Drawing.Font('Segoe UI Semibold',10)}
function LoadIcon($name){$p=Join-Path $IconDir $name;if(-not(Test-Path -LiteralPath $p)){return $null};$s=[Drawing.Image]::FromFile($p);try{return New-Object Drawing.Bitmap $s}finally{$s.Dispose()}}
function Roll-Drop {$r=$rng.NextDouble()*$totalWeight;$sum=0.0;foreach($d in $drops){$sum+=$d.Chance;if($r-lt$sum){return $d}};$drops[-1]}
function Refresh-Results {
  $openedLabel.Text="ВІДКРИТО: $script:Opened";$list.Items.Clear()
  foreach($d in $drops){$c=if($counts.ContainsKey($d.Name)){[int]$counts[$d.Name]}else{0};if(-not$c){continue};$item=New-Object Windows.Forms.ListViewItem $d.Name;$item.ImageKey=$d.Icon;[void]$item.SubItems.Add(('{0:N3}%' -f $d.Chance));[void]$item.SubItems.Add([string]$c);[void]$item.SubItems.Add([string]($c*$d.Stack));[void]$item.SubItems.Add(('{0:N3}%' -f (100*$c/[Math]::Max(1,$script:Opened))));if($d.Chance-lt.05){$item.ForeColor=$rare}elseif($d.Chance-lt1){$item.ForeColor=$cyan}else{$item.ForeColor=$text};[void]$list.Items.Add($item)}
}
function Open-Chests([int]$n){$last=$null;for($i=0;$i-lt$n;$i++){$last=Roll-Drop;if(-not$counts.ContainsKey($last.Name)){$counts[$last.Name]=0};$counts[$last.Name]++};$script:Opened+=$n;if($last){$lastName.Text=$last.Name;$lastChance.Text=('Шанс: {0}%  ·  отримано: {1} шт.' -f $last.Chance,$last.Stack);if($lastIcon.Image){$lastIcon.Image.Dispose()};$lastIcon.Image=LoadIcon $last.Icon};Refresh-Results}

$form=New-Object Windows.Forms.Form;$form.Text='Cyber.pw Asistant — Симулятор скрині [BETA]';$form.Size='1120,800';$form.MinimumSize='980,720';$form.StartPosition='CenterScreen';$form.BackColor=$jade;$form.ForeColor=$text
$form.AutoScaleMode='Dpi';$form.AutoScroll=$true;$form.MaximizeBox=$true
$title=Label 'СИМУЛЯТОР СКРИНІ ТОРА · BETA' 24 18 750 44 24 $goldSoft 'Bold';$sub=Label 'Бета-версія · тестуйте шанси без витрат у грі · результати є лише симуляцією' 27 60 800 24 10 $muted
$controls=New-Object Windows.Forms.Panel;$controls.SetBounds(22,98,1070,100);$controls.Anchor='Top,Left,Right';$controls.BackColor=$panel
$countLabel=Label 'СКІЛЬКИ ВІДКРИТИ' 20 12 210 22 9 $goldSoft 'Bold';$amount=New-Object Windows.Forms.NumericUpDown;$amount.SetBounds(20,40,180,36);$amount.Minimum=1;$amount.Maximum=1000000;$amount.Value=10;$amount.BackColor=$jade2;$amount.ForeColor=$text;$amount.Font=New-Object Drawing.Font('Segoe UI',12)
$open=New-Object Windows.Forms.Button;$open.Text='ВІДКРИТИ';$open.SetBounds(220,37,190,42);ButtonStyle $open ([Drawing.Color]::FromArgb(18,126,98));$open.Add_Click({Open-Chests ([int]$amount.Value)})
$reset=New-Object Windows.Forms.Button;$reset.Text='СКИНУТИ';$reset.SetBounds(424,37,140,42);ButtonStyle $reset $jade2;$reset.Add_Click({$counts.Clear();$script:Opened=0;$lastName.Text='Скриня чекає відкриття';$lastChance.Text='';if($lastIcon.Image){$lastIcon.Image.Dispose();$lastIcon.Image=$null};Refresh-Results})
$openedLabel=Label 'ВІДКРИТО: 0' 610 32 420 48 22 $cyan 'Bold';$openedLabel.TextAlign='MiddleRight';$openedLabel.Anchor='Top,Left,Right';$controls.Controls.AddRange(@($countLabel,$amount,$open,$reset,$openedLabel))
$recent=New-Object Windows.Forms.Panel;$recent.SetBounds(22,214,1070,105);$recent.Anchor='Top,Left,Right';$recent.BackColor=$panel;$lastIcon=New-Object Windows.Forms.PictureBox;$lastIcon.SetBounds(20,18,68,68);$lastIcon.SizeMode='Zoom';$lastName=Label 'Скриня чекає відкриття' 108 20 700 34 16 $goldSoft 'Bold';$lastName.Anchor='Top,Left,Right';$lastChance=Label '' 110 56 700 28 10 $muted;$lastChance.Anchor='Top,Left,Right';$recent.Controls.AddRange(@($lastIcon,$lastName,$lastChance))
$list=New-Object Windows.Forms.ListView;$list.SetBounds(22,336,1070,350);$list.Anchor='Top,Bottom,Left,Right';$list.View='Details';$list.FullRowSelect=$true;$list.GridLines=$false;$list.BackColor=$theme.Field;$list.ForeColor=$text;$list.Font=New-Object Drawing.Font('Segoe UI',10)
[void]$list.Columns.Add('Предмет',500);[void]$list.Columns.Add('Шанс',115);[void]$list.Columns.Add('Випало, разів',130);[void]$list.Columns.Add('Всього штук',130);[void]$list.Columns.Add('Фактично',120)
$images=New-Object Windows.Forms.ImageList;$images.ImageSize='40,40';$images.ColorDepth='Depth32Bit';foreach($d in $drops){if(-not$images.Images.ContainsKey($d.Icon)){$im=LoadIcon $d.Icon;if($im){[void]$images.Images.Add($d.Icon,$im)}}};$list.SmallImageList=$images
$note=Label ('Шанси зі скріншота. Сума вказаних ваг: {0:N3}%; під час симуляції вони пропорційно нормалізуються.' -f $totalWeight) 25 696 900 24 8 $muted;$note.Anchor='Bottom,Left'
$form.Controls.AddRange(@($title,$sub,$controls,$recent,$list,$note));[void](Add-CyberPWCommunityBar $form);[void](Add-CyberPWThemeToggle $form $MyInvocation.MyCommand.Path);$form.Add_FormClosed({if($lastIcon.Image){$lastIcon.Image.Dispose()};$images.Dispose()});Apply-CyberPWVisualPolish $form;[void]$form.ShowDialog()
