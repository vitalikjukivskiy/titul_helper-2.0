$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'CyberPW-Common.ps1')
$MapPath=Join-Path $AppDir 'gvg-map.png'
$StatePath=Join-Path $AppDir 'territories.json'
$PolygonPath=Join-Path $AppDir 'territory-polygons.json'
$script:Zones=[ordered]@{}
$script:Territories=@()
$script:SelectedNumber=1
$script:DisplayZoneByDomainId=@{
  1=1;2=2;3=3;4=4;5=5;6=6;7=7;8=8;9=9;10=10;11=12;12=11;13=18
  14=13;15=14;16=15;17=16;18=17;19=19;20=20;21=21;22=22;23=23;24=24
  25=25;26=31;27=26;28=33;29=27;30=34;31=28;32=29;33=30;34=32
  35=37;36=38;37=39;38=40;39=35;40=36;41=41;42=42;43=43;44=44
  45=46;46=45;47=47;48=48;49=49;50=50;51=51
}
$script:DefaultOwnerByDomainId=@{
  1='CyberPunk';2='CyberPunk';3='CyberPunk';4='CyberPunk';5='Invictus';6='Invictus'
  7='Thunder';8='CyberPunk';9='CyberPunk';10='Thunder';11='CyberPunk';12='Invictus'
  13='CyberPunk';14='Thunder';15='Thunder';16='Thunder';17='Thunder';18='Thunder'
  19='Thunder';20='Thunder';21='Thunder';22='Thunder';23='Thunder';24='CyberPunk'
  25='Thunder';26='Thunder';27='Thunder';28='Thunder';29='Thunder';30='Thunder'
  31='Thunder';32='CyberPunk';33='Thunder';34='Thunder';35='Mystery';36='Thunder'
  37='Thunder';38='Invictus';39='Mystery';40='Thunder';41='Mystery';42='Mystery'
  43='Invictus';44='Invictus';45='Eclipse';46='Eclipse';47='Eclipse'
  48='Mystery';49='Mystery';50='Mystery';51='Eclipse'
}
$script:TerritoryNameFix=@{
  45='Остров Разбитой мечты';46='Остров Рваных облаков';49='Деревня падающих звезд';51='Поляна снежного дракона'
}

function Convert-MapPoint([double]$X,[double]$Y){
  # domain.data uses the original 1024-map coordinate space. The screenshot
  # contains the same map inside this measured rectangle.
  [Drawing.PointF]::new(
    [single](60+(($X-303)*533/421)),
    [single](33+(($Y-199)*797/629))
  )
}
function Load-Territories {
  if(-not(Test-Path -LiteralPath $PolygonPath)){throw 'Не знайдено territory-polygons.json.'}
  $raw=Get-Content -LiteralPath $PolygonPath -Raw -Encoding UTF8|ConvertFrom-Json
  $script:Territories=@(
    $raw|Where-Object{[int]$_.Number-ge1-and[int]$_.Number-le51}|ForEach-Object{
      $path=New-Object Drawing.Drawing2D.GraphicsPath
      $points=@($_.Points|ForEach-Object{Convert-MapPoint ([double]$_.X) ([double]$_.Y)})
      if($points.Count-ge3){$path.AddPolygon([Drawing.PointF[]]$points)}
      [pscustomobject]@{
        Number=[int]$_.Number;DisplayZone=[int]$script:DisplayZoneByDomainId[[int]$_.Number];Name=$(if($script:TerritoryNameFix.ContainsKey([int]$_.Number)){$script:TerritoryNameFix[[int]$_.Number]}else{[string]$_.Name});Level=(4-[int]$_.Level)
        Reward=[int64]$_.Reward;Center=Convert-MapPoint ([double]$_.Center.X) ([double]$_.Center.Y)
        Path=$path
      }
    }
  )
}

function New-Zone([int]$Number){
  $owner=if($script:DefaultOwnerByDomainId.ContainsKey($Number)){$script:DefaultOwnerByDomainId[$Number]}else{''}
  [ordered]@{Number=$Number;Owner=$owner;Attacker='';Defender=$owner;BattleTime='';Notes='';Updated='2026-07-24 · зі скриншотів'}
}
function Load-Zones {
  1..51|ForEach-Object{$script:Zones[[string]$_]=New-Zone $_}
  if(-not(Test-Path -LiteralPath $StatePath)){return}
  try{
    $saved=Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8|ConvertFrom-Json
    foreach($property in $saved.PSObject.Properties){
      $number=[int]$property.Name
      if($number-ge1-and$number-le51){
        $zone=New-Zone $number
        foreach($field in @('Owner','Attacker','Defender','BattleTime','Notes','Updated')){
          if($property.Value.PSObject.Properties.Name-contains$field){$zone[$field]=[string]$property.Value.$field}
        }
        $script:Zones[[string]$number]=$zone
      }
    }
  }catch{
    [Windows.Forms.MessageBox]::Show("Не вдалося прочитати territories.json.`r`n$($_.Exception.Message)",'Карта ТВ')|Out-Null
  }
}
function Save-Zones {
  $script:Zones|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $StatePath -Encoding UTF8
}

Load-Zones
Load-Territories
$theme=Get-CyberPWTheme
$jade=$theme.Base;$jade2=$theme.Button;$panel=$theme.Panel;$field=$theme.Field
$gold=$theme.Gold;$goldSoft=$theme.GoldSoft;$textColor=$theme.Text;$muted=$theme.Muted
$cyan=$theme.AccentBright;$danger=$theme.Danger

function Style-Button($button,$back,$fore=$textColor){
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$gold
  $button.BackColor=$back;$button.ForeColor=$fore;$button.Cursor='Hand'
  $button.Font=New-Object Drawing.Font('Segoe UI Semibold',9)
}
function New-Label($value,$x,$y,$w,$h,$size,$color,$style='Regular'){
  $label=New-Object Windows.Forms.Label;$label.Text=$value;$label.SetBounds($x,$y,$w,$h)
  $label.ForeColor=$color;$label.BackColor=[Drawing.Color]::Transparent
  $label.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style);$label
}
function Style-Field($control){
  $control.BackColor=$field;$control.ForeColor=$textColor
  if($control.PSObject.Properties.Name-contains'BorderStyle'){$control.BorderStyle='FixedSingle'}
}

$form=New-Object Windows.Forms.Form
$form.Text='Cyber.pw Asistant — Карта ТВ'
$form.Size='1180,820';$form.MinimumSize='1000,700';$form.StartPosition='CenterScreen'
$form.BackColor=$jade;$form.ForeColor=$textColor;$form.AutoScaleMode='Dpi'

$header=New-Label 'КАРТА ТЕРИТОРІАЛЬНИХ ВІЙН' 24 14 650 38 22 $goldSoft 'Bold'
$subtitle=New-Label '51 територія · власники кланів · атаки та розклад боїв' 27 52 650 24 10 $muted

$mapPanel=New-Object Windows.Forms.Panel;$mapPanel.SetBounds(20,88,700,650)
$mapPanel.Anchor='Top,Bottom,Left';$mapPanel.BackColor=$panel;$mapPanel.AutoScroll=$true
$mapBox=New-Object Windows.Forms.PictureBox;$mapBox.Location='0,0';$mapBox.Size='713,873'
$mapBox.SizeMode='Normal';$mapBox.BackColor=$panel;$mapBox.Cursor='Hand'
if(Test-Path -LiteralPath $MapPath){
  $source=[Drawing.Image]::FromFile($MapPath)
  $mapBox.Image=New-Object Drawing.Bitmap $source;$source.Dispose()
}else{$mapBox.BackColor=$danger}
$mapPanel.Controls.Add($mapBox)

$editor=New-Object Windows.Forms.Panel;$editor.SetBounds(740,88,415,650)
$editor.Anchor='Top,Bottom,Left,Right';$editor.BackColor=$panel
$zoneTitle=New-Label 'ТЕРИТОРІЯ' 24 18 120 24 10 $goldSoft 'Bold'
$zoneBox=New-Object Windows.Forms.ComboBox;$zoneBox.SetBounds(24,44,365,32)
$zoneBox.DropDownStyle='DropDownList';Style-Field $zoneBox
$script:Territories|ForEach-Object{[void]$zoneBox.Items.Add(('Зона {0:D2} · {1}'-f$_.DisplayZone,$_.Name))}

$territoryInfo=New-Label '' 24 82 365 34 9 $cyan 'Bold'
$ownerLabel=New-Label 'ВЛАСНИК ТЕРИТОРІЇ' 24 124 365 22 9 $goldSoft 'Bold'
$owner=New-Object Windows.Forms.TextBox;$owner.SetBounds(24,148,365,30);Style-Field $owner
$attackerLabel=New-Label 'АТАКУЮЧИЙ КЛАН' 24 194 365 22 9 $goldSoft 'Bold'
$attacker=New-Object Windows.Forms.TextBox;$attacker.SetBounds(24,218,365,30);Style-Field $attacker
$defenderLabel=New-Label 'КЛАН-ЗАХИСНИК' 24 264 365 22 9 $goldSoft 'Bold'
$defender=New-Object Windows.Forms.TextBox;$defender.SetBounds(24,288,365,30);Style-Field $defender
$timeLabel=New-Label 'ДАТА І ЧАС БОЮ' 24 334 365 22 9 $goldSoft 'Bold'
$battleTime=New-Object Windows.Forms.TextBox;$battleTime.SetBounds(24,358,365,30);Style-Field $battleTime
$battleTime.Text='Неділя 18:00'
$notesLabel=New-Label 'НОТАТКИ' 24 404 365 22 9 $goldSoft 'Bold'
$notes=New-Object Windows.Forms.TextBox;$notes.SetBounds(24,428,365,62);$notes.Multiline=$true;$notes.ScrollBars='Vertical';Style-Field $notes
$updated=New-Label 'Ще не оновлювалось' 24 500 365 24 8 $muted

$save=New-Object Windows.Forms.Button;$save.Text='ЗБЕРЕГТИ ТЕРИТОРІЮ';$save.SetBounds(24,538,365,43);Style-Button $save ([Drawing.Color]::FromArgb(18,126,98))
$clear=New-Object Windows.Forms.Button;$clear.Text='ОЧИСТИТИ ДАНІ ЗОНИ';$clear.SetBounds(24,590,176,36);Style-Button $clear $jade2
$export=New-Object Windows.Forms.Button;$export.Text='ВІДКРИТИ JSON';$export.SetBounds(213,590,176,36);Style-Button $export $jade2

$script:Loading=$false
function Show-Zone([int]$number){
  if($number-lt1-or$number-gt51){return}
  $script:Loading=$true
  $zoneBox.SelectedIndex=$number-1
  $script:SelectedNumber=$number
  $territory=$script:Territories|Where-Object {$_.Number -eq $number}|Select-Object -First 1
  $territoryInfo.Text="Рівень: $($territory.Level)  ·  Нагорода: $($territory.Reward.ToString('N0'))"
  $zone=$script:Zones[[string]$number]
  $owner.Text=$zone.Owner;$attacker.Text=$zone.Attacker;$defender.Text=$zone.Defender
  $battleTime.Text=$zone.BattleTime;$notes.Text=$zone.Notes
  $updated.Text=if($zone.Updated){"Оновлено: $($zone.Updated)"}else{'Ще не оновлювалось'}
  $mapBox.Invalidate()
  $script:Loading=$false
}
function Store-CurrentZone {
  if($zoneBox.SelectedIndex-lt0){return}
  $number=$zoneBox.SelectedIndex+1;$zone=$script:Zones[[string]$number]
  $zone.Owner=$owner.Text.Trim();$zone.Attacker=$attacker.Text.Trim();$zone.Defender=$defender.Text.Trim()
  $zone.BattleTime=$battleTime.Text.Trim();$zone.Notes=$notes.Text.Trim()
  $zone.Updated=(Get-Date).ToString('yyyy-MM-dd HH:mm')
  Save-Zones;$updated.Text="Оновлено: $($zone.Updated)"
}

$zoneBox.Add_SelectedIndexChanged({if(-not$script:Loading){Show-Zone ($zoneBox.SelectedIndex+1)}})
$save.Add_Click({Store-CurrentZone})
$clear.Add_Click({
  if($zoneBox.SelectedIndex-lt0){return};$number=$zoneBox.SelectedIndex+1
  if([Windows.Forms.MessageBox]::Show("Очистити дані зони $number?",'Карта ТВ','YesNo','Question')-eq'Yes'){
    $script:Zones[[string]$number]=New-Zone $number;Save-Zones;Show-Zone $number
  }
})
$export.Add_Click({
  if(-not(Test-Path -LiteralPath $StatePath)){Save-Zones}
  Start-Process notepad.exe -ArgumentList ('"'+$StatePath+'"')
})
$mapBox.Add_Paint({
  param($sender,$eventArgs)
  $selected=$script:Territories|Where-Object {$_.Number -eq $script:SelectedNumber}|Select-Object -First 1
  if($selected){
    $fill=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(80,255,214,64))
    $outline=New-Object Drawing.Pen $goldSoft,4
    $eventArgs.Graphics.SmoothingMode='AntiAlias'
    $eventArgs.Graphics.FillPath($fill,$selected.Path)
    $eventArgs.Graphics.DrawPath($outline,$selected.Path)
    $fill.Dispose();$outline.Dispose()
  }
})
$mapBox.Add_MouseMove({
  $mouseX=[single]$_.X;$mouseY=[single]$_.Y
  $hit=$script:Territories|Where-Object{$_.Path.IsVisible($mouseX,$mouseY)}|Select-Object -First 1
  if($hit){$mapBox.Cursor='Hand';$mapBox.Tag=$hit.Number}else{$mapBox.Cursor='Default';$mapBox.Tag=$null}
})
$mapBox.Add_MouseClick({
  $point=[Drawing.PointF]::new([single]$_.X,[single]$_.Y)
  $hit=$script:Territories|Where-Object{$_.Path.IsVisible($point)}|Select-Object -First 1
  if($hit){Show-Zone ([int]$hit.Number)}
})

$editor.Controls.AddRange(@($zoneTitle,$zoneBox,$territoryInfo,$ownerLabel,$owner,$attackerLabel,$attacker,$defenderLabel,$defender,$timeLabel,$battleTime,$notesLabel,$notes,$updated,$save,$clear,$export))
$form.Controls.AddRange(@($header,$subtitle,$mapPanel,$editor))
[void](Add-CyberPWCommunityBar $form)
[void](Add-CyberPWThemeToggle $form $MyInvocation.MyCommand.Path)
Show-Zone 1
$form.Add_FormClosed({
  if($mapBox.Image){$mapBox.Image.Dispose()}
  foreach($territory in $script:Territories){if($territory.Path){$territory.Path.Dispose()}}
})
Apply-CyberPWVisualPolish $form;[void]$form.ShowDialog()
