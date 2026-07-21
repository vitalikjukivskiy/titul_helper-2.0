param(
  [switch]$ScanOnly,
  [string]$GamePath,
  [string]$LaunchProfile
)

$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath=Join-Path $AppDir 'characters.json'
$ClassIconDir=Join-Path $AppDir 'class-icons'
$utf8NoBom=New-Object Text.UTF8Encoding($false,$false)
$script:SessionAccounts=@{}

$classes=@(
  'Не визначено','Воїн','Маг','Танк','Друїд','Лучник','Жрець','Асасин','Шаман','Страж','Містик'
)
$classGlyphs=@{
  'Не визначено'='?';'Воїн'='В';'Маг'='М';'Танк'='Т';'Друїд'='Д';'Лучник'='Л'
  'Жрець'='Ж';'Асасин'='А';'Шаман'='Ш';'Страж'='С';'Містик'='МС'
}
$classColors=@{
  'Не визначено'=[Drawing.Color]::FromArgb(80,96,91);'Танк'=[Drawing.Color]::FromArgb(190,116,35)
  'Воїн'=[Drawing.Color]::FromArgb(196,67,53);'Маг'=[Drawing.Color]::FromArgb(74,119,208)
  'Лучник'=[Drawing.Color]::FromArgb(55,155,99);'Жрець'=[Drawing.Color]::FromArgb(220,190,74)
  'Друїд'=[Drawing.Color]::FromArgb(165,75,175);'Асасин'=[Drawing.Color]::FromArgb(81,68,133)
  'Шаман'=[Drawing.Color]::FromArgb(49,168,183);'Страж'=[Drawing.Color]::FromArgb(164,145,74)
  'Містик'=[Drawing.Color]::FromArgb(60,150,114)
}
$classIconFiles=@{
  'Воїн'='warrior.png';'Маг'='mage.png';'Танк'='tank.png';'Друїд'='druid.png'
  'Лучник'='archer.png';'Жрець'='cleric.png';'Асасин'='assassin.png';'Шаман'='shaman.png'
  'Страж'='seeker.png';'Містик'='mystic.png'
}

function Read-Config {
  $default=[ordered]@{GamePath='';DelaySeconds=4;Characters=[ordered]@{}}
  if(-not(Test-Path $ConfigPath)){return $default}
  try{
    $raw=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
    if($raw.GamePath){$default.GamePath=[string]$raw.GamePath}
    if($raw.DelaySeconds){$default.DelaySeconds=[int]$raw.DelaySeconds}
    if($raw.Characters){foreach($p in $raw.Characters.PSObject.Properties){$default.Characters[$p.Name]=$p.Value}}
  }catch{}
  $default
}
function Save-Config {
  $script:Config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}
function Protect-AccountValue([string]$Value){
  if([string]::IsNullOrEmpty($Value)){return ''}
  ConvertFrom-SecureString (ConvertTo-SecureString $Value -AsPlainText -Force)
}
function Unprotect-AccountValue([string]$Value){
  if([string]::IsNullOrEmpty($Value)){return ''}
  try{
    $secure=ConvertTo-SecureString $Value
    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try{[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)}
  }catch{''}
}
function Get-Account([string]$FileName){
  if($script:SessionAccounts.ContainsKey($FileName)){return $script:SessionAccounts[$FileName]}
  $saved=$script:Config.Characters[$FileName]
  [pscustomobject]@{
    Login=Unprotect-AccountValue ([string]$saved.LoginProtected)
    Password=Unprotect-AccountValue ([string]$saved.PasswordProtected)
    Remember=[bool]($saved.LoginProtected -or $saved.PasswordProtected)
  }
}
function Set-Account([string]$FileName,[string]$Login,[string]$Password,[bool]$Remember){
  $script:SessionAccounts[$FileName]=[pscustomobject]@{Login=$Login;Password=$Password;Remember=$Remember}
  if(-not $script:Config.Characters[$FileName]){$script:Config.Characters[$FileName]=[ordered]@{}}
  $entry=$script:Config.Characters[$FileName]
  $loginValue=if($Remember){Protect-AccountValue $Login}else{''}
  $passwordValue=if($Remember){Protect-AccountValue $Password}else{''}
  if($entry -is [Collections.IDictionary]){
    $entry['LoginProtected']=$loginValue;$entry['PasswordProtected']=$passwordValue
  }else{
    $entry|Add-Member -NotePropertyName LoginProtected -NotePropertyValue $loginValue -Force
    $entry|Add-Member -NotePropertyName PasswordProtected -NotePropertyValue $passwordValue -Force
  }
  Save-Config
}
function Resolve-GamePath([string]$Requested){
  $candidates=@($Requested,$script:Config.GamePath,'D:\CyberPW')|Where-Object{$_}
  foreach($candidate in $candidates){
    try{$full=[IO.Path]::GetFullPath($candidate)}catch{continue}
    if((Test-Path -LiteralPath $full -PathType Container) -and
       ((Test-Path -LiteralPath (Join-Path $full 'ElementClient.exe')) -or (Test-Path -LiteralPath (Join-Path $full 'elementclient.exe')))){
      return $full.TrimEnd('\')
    }
  }
  ''
}
function Get-Profiles {
  $result=@()
  foreach($id in @($script:Config.Characters.Keys)){
    $saved=$script:Config.Characters[$id]
    if(-not $saved.Nick){continue}
    $class=[string]$saved.Class;if($class -eq 'Варвар'){$class='Танк'};if($class -eq 'Психік'){$class='Шаман'};if($classes -notcontains $class){$class='Не визначено'}
    $selected=if($null-ne$saved.Selected){[bool]$saved.Selected}else{$true}
    $result+=[pscustomobject]@{FileName=[string]$id;Role=[string]$saved.Nick;Valid=$true;Reason='Профіль готовий';Class=$class;Selected=$selected}
  }
  @($result|Sort-Object Role)
}
function Sync-ProfileBat([string]$Id,[string]$Nick){
  $folder=Join-Path $AppDir 'profiles';if(-not(Test-Path -LiteralPath $folder)){New-Item -ItemType Directory -Path $folder|Out-Null}
  $safeName=($Nick -replace '[\\/:*?"<>|]','_').Trim();if(-not $safeName){$safeName='profile'}
  $path=Join-Path $folder ($safeName+'-'+$Id.Substring(0,8)+'.bat')
  $body="@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0..\CyberPW-MultiLauncher.ps1`" -LaunchProfile `"$Id`"`r`n"
  [IO.File]::WriteAllText($path,$body,[Text.Encoding]::Default)
}

$script:Config=Read-Config
$script:GamePath=Resolve-GamePath $GamePath
$script:Characters=Get-Profiles

if($ScanOnly){
  $script:Characters|Select-Object FileName,Role,Valid,Reason,Class,Selected|ConvertTo-Json -Depth 5
  exit
}

$jade=[Drawing.Color]::FromArgb(5,31,27);$jade2=[Drawing.Color]::FromArgb(9,55,47)
$panel=[Drawing.Color]::FromArgb(14,43,38);$gold=[Drawing.Color]::FromArgb(222,177,54)
$goldSoft=[Drawing.Color]::FromArgb(255,225,143);$textColor=[Drawing.Color]::FromArgb(239,245,241)
$muted=[Drawing.Color]::FromArgb(160,186,176);$cyan=[Drawing.Color]::FromArgb(42,214,183);$danger=[Drawing.Color]::FromArgb(218,82,72)

function Style-Button($button,$back,$fore=$textColor){
  $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.FlatAppearance.BorderColor=$gold
  $button.BackColor=$back;$button.ForeColor=$fore;$button.Cursor='Hand';$button.Font=New-Object Drawing.Font('Segoe UI Semibold',9)
}
function New-Label($value,$x,$y,$w,$h,$size,$color,$style='Regular'){
  $l=New-Object Windows.Forms.Label;$l.Text=$value;$l.SetBounds($x,$y,$w,$h);$l.ForeColor=$color;$l.BackColor=[Drawing.Color]::Transparent
  $l.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::$style);$l
}
function New-ClassIcon([string]$Class,[int]$Size=58){
  $file=[string]$classIconFiles[$Class]
  if($file){
    $path=Join-Path $ClassIconDir $file
    if(Test-Path -LiteralPath $path){
      try{
        $source=[Drawing.Image]::FromFile($path)
        try{
          $bmp=New-Object Drawing.Bitmap $Size,$Size
          $g=[Drawing.Graphics]::FromImage($bmp)
          try{
            $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.DrawImage($source,0,0,$Size,$Size)
          }finally{$g.Dispose()}
          return $bmp
        }finally{$source.Dispose()}
      }catch{}
    }
  }
  $bmp=New-Object Drawing.Bitmap $Size,$Size;$g=[Drawing.Graphics]::FromImage($bmp)
  try{
    $g.SmoothingMode='AntiAlias';$color=$classColors[$Class];if(-not $color){$color=$classColors['Не визначено']}
    $brush=New-Object Drawing.Drawing2D.LinearGradientBrush (New-Object Drawing.Rectangle 0,0,$Size,$Size),$color,$jade2,45
    $g.FillEllipse($brush,2,2,$Size-5,$Size-5);$brush.Dispose();$pen=New-Object Drawing.Pen $goldSoft,2;$g.DrawEllipse($pen,2,2,$Size-5,$Size-5);$pen.Dispose()
    $glyph=[string]$classGlyphs[$Class];if(-not $glyph){$glyph='?'};$fontSize=if($glyph.Length-gt1){14}else{20};$font=New-Object Drawing.Font('Segoe UI Semibold',$fontSize,[Drawing.FontStyle]::Bold)
    $sf=New-Object Drawing.StringFormat;$sf.Alignment='Center';$sf.LineAlignment='Center';$b=New-Object Drawing.SolidBrush $textColor
    $g.DrawString($glyph,$font,$b,(New-Object Drawing.RectangleF 0,0,$Size,$Size),$sf);$b.Dispose();$sf.Dispose();$font.Dispose()
  }finally{$g.Dispose()}
  $bmp
}
function Update-ConfigFromCards {
  foreach($card in @($flow.Controls)){
    if(-not $card.Tag){continue};$item=$card.Tag.Item;$combo=$card.Tag.Combo;$check=$card.Tag.Check
    $old=$script:Config.Characters[$item.FileName]
    $script:Config.Characters[$item.FileName]=[ordered]@{
      Nick=[string]$item.Role;Class=[string]$combo.SelectedItem;Selected=[bool]$check.Checked
      LoginProtected=[string]$old.LoginProtected;PasswordProtected=[string]$old.PasswordProtected
    }
  }
  $script:Config.GamePath=$script:GamePath;$script:Config.DelaySeconds=[int]$delay.Value;Save-Config
}
function Launch-Character($item){
  if(-not $item.Valid){return $false}
  try{
    $account=Get-Account $item.FileName
    if([string]::IsNullOrWhiteSpace($account.Login)-or[string]::IsNullOrEmpty($account.Password)){throw 'Спочатку відкрийте «АКАУНТ» і введіть логін та пароль.'}
    if($account.Login -match '["\r\n]' -or $account.Password -match '["\r\n]'){throw 'Логін і пароль не можуть містити лапки або перенесення рядка.'}
    if([string]::IsNullOrWhiteSpace($script:GamePath)){throw 'Не вибрано папку гри.'}
    $arguments='startbypatcher user:"'+$account.Login+'" pwd:"'+$account.Password+'" role:"'+$item.Role+'"'
    $before=@(Get-Process -Name ElementClient -ErrorAction SilentlyContinue).Count
    $exe=Join-Path $script:GamePath 'ElementClient.exe';if(-not(Test-Path -LiteralPath $exe)){$exe=Join-Path $script:GamePath 'elementclient.exe'}
    Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $script:GamePath|Out-Null
    $script:Launched[$item.FileName]=Get-Date
    if($status){$status.Text="Запущено: $($item.Role) · було вікон: $before";$status.ForeColor=$cyan}
    return $true
  }catch{
    if($LaunchProfile){Write-Error $_.Exception.Message}else{[Windows.Forms.MessageBox]::Show("Не вдалося запустити $($item.Role).`r`n$($_.Exception.Message)",'MultiLauncher')|Out-Null}
    return $false
  }
}
function Show-AccountDialog($item,$button){
  $account=Get-Account $item.FileName
  $dlg=New-Object Windows.Forms.Form;$dlg.Text='Акаунт · '+$item.Role;$dlg.Size='430,285';$dlg.StartPosition='CenterParent';$dlg.FormBorderStyle='FixedDialog';$dlg.MaximizeBox=$false;$dlg.MinimizeBox=$false;$dlg.BackColor=$jade;$dlg.ForeColor=$textColor
  $loginLabel=New-Label 'ЛОГІН' 28 22 350 22 9 $goldSoft 'Bold'
  $login=New-Object Windows.Forms.TextBox;$login.SetBounds(28,46,360,30);$login.Text=$account.Login;$login.BackColor=$panel;$login.ForeColor=$textColor
  $passLabel=New-Label 'ПАРОЛЬ' 28 87 350 22 9 $goldSoft 'Bold'
  $pass=New-Object Windows.Forms.TextBox;$pass.SetBounds(28,111,318,30);$pass.Text=$account.Password;$pass.UseSystemPasswordChar=$true;$pass.BackColor=$panel;$pass.ForeColor=$textColor
  $show=New-Object Windows.Forms.Button;$show.Text='👁';$show.SetBounds(350,110,38,32);Style-Button $show $jade2;$show.Add_Click({$pass.UseSystemPasswordChar=-not $pass.UseSystemPasswordChar})
  $remember=New-Object Windows.Forms.CheckBox;$remember.Text="Запам'ятати на цьому комп'ютері";$remember.SetBounds(28,153,330,26);$remember.Checked=$account.Remember;$remember.ForeColor=$textColor;$remember.BackColor=[Drawing.Color]::Transparent
  $save=New-Object Windows.Forms.Button;$save.Text='ЗБЕРЕГТИ';$save.SetBounds(228,193,160,38);Style-Button $save ([Drawing.Color]::FromArgb(18,126,98));$save.DialogResult='OK'
  $dlg.AcceptButton=$save;$dlg.Controls.AddRange(@($loginLabel,$login,$passLabel,$pass,$show,$remember,$save))
  if($dlg.ShowDialog($form)-eq'OK'){
    Set-Account $item.FileName $login.Text $pass.Text $remember.Checked
    $button.Text=if($login.Text){'✓ АКАУНТ'}else{'АКАУНТ'}
  }
  $dlg.Dispose()
}
function Show-CreateProfileDialog {
  $dlg=New-Object Windows.Forms.Form;$dlg.Text='Створити профіль';$dlg.Size='470,445';$dlg.StartPosition='CenterParent';$dlg.FormBorderStyle='FixedDialog';$dlg.MaximizeBox=$false;$dlg.MinimizeBox=$false;$dlg.BackColor=$jade;$dlg.ForeColor=$textColor
  $nickLabel=New-Label 'НІК ПЕРСОНАЖА' 30 20 380 20 9 $goldSoft 'Bold';$nick=New-Object Windows.Forms.TextBox;$nick.SetBounds(30,43,390,30);$nick.BackColor=$panel;$nick.ForeColor=$textColor
  $classLabel=New-Label 'КЛАС' 30 82 380 20 9 $goldSoft 'Bold';$classBox=New-Object Windows.Forms.ComboBox;$classBox.SetBounds(30,105,390,30);$classBox.DropDownStyle='DropDownList';$classBox.BackColor=$panel;$classBox.ForeColor=$textColor;[void]$classBox.Items.AddRange([object[]]$classes);$classBox.SelectedIndex=0
  $loginLabel=New-Label 'ЛОГІН' 30 147 380 20 9 $goldSoft 'Bold';$login=New-Object Windows.Forms.TextBox;$login.SetBounds(30,170,390,30);$login.BackColor=$panel;$login.ForeColor=$textColor
  $passLabel=New-Label 'ПАРОЛЬ' 30 212 380 20 9 $goldSoft 'Bold';$pass=New-Object Windows.Forms.TextBox;$pass.SetBounds(30,235,348,30);$pass.UseSystemPasswordChar=$true;$pass.BackColor=$panel;$pass.ForeColor=$textColor
  $show=New-Object Windows.Forms.Button;$show.Text='👁';$show.SetBounds(382,234,38,32);Style-Button $show $jade2;$show.Add_Click({$pass.UseSystemPasswordChar=-not $pass.UseSystemPasswordChar})
  $remember=New-Object Windows.Forms.CheckBox;$remember.Text="Запам'ятати на цьому комп'ютері";$remember.SetBounds(30,278,350,25);$remember.Checked=$true;$remember.ForeColor=$textColor;$remember.BackColor=[Drawing.Color]::Transparent
  $hint=New-Label 'Буде створено безпечний BAT-ярлик без пароля всередині.' 30 310 390 35 8 $muted
  $create=New-Object Windows.Forms.Button;$create.Text='СТВОРИТИ ПРОФІЛЬ';$create.SetBounds(230,348,190,40);Style-Button $create ([Drawing.Color]::FromArgb(18,126,98))
  $create.Add_Click({
    if([string]::IsNullOrWhiteSpace($nick.Text)-or[string]::IsNullOrWhiteSpace($login.Text)-or[string]::IsNullOrEmpty($pass.Text)){[Windows.Forms.MessageBox]::Show('Заповніть нік, логін і пароль.','MultiLauncher')|Out-Null;return}
    if($nick.Text -match '["\r\n]' -or $login.Text -match '["\r\n]' -or $pass.Text -match '["\r\n]'){[Windows.Forms.MessageBox]::Show('Поля не можуть містити лапки або перенесення рядка.','MultiLauncher')|Out-Null;return}
    $id=[guid]::NewGuid().ToString('N');$script:Config.Characters[$id]=[ordered]@{Nick=$nick.Text.Trim();Class=[string]$classBox.SelectedItem;Selected=$true;LoginProtected='';PasswordProtected=''}
    Set-Account $id $login.Text $pass.Text $remember.Checked;Sync-ProfileBat $id $nick.Text.Trim();$dlg.DialogResult='OK';$dlg.Close()
  })
  $dlg.Controls.AddRange(@($nickLabel,$nick,$classLabel,$classBox,$loginLabel,$login,$passLabel,$pass,$show,$remember,$hint,$create))
  if($dlg.ShowDialog($form)-eq'OK'){$script:Characters=Get-Profiles;Render-Cards;$status.Text='Профіль створено. BAT-ярлик лежить у папці profiles.'}
  $dlg.Dispose()
}
function Launch-Many($items){
  $valid=@($items|Where-Object Valid);if(-not $valid.Count){[Windows.Forms.MessageBox]::Show('Немає вибраних профілів.','MultiLauncher')|Out-Null;return}
  Update-ConfigFromCards
  $launchSelected.Enabled=$false;$launchAll.Enabled=$false;$scan.Enabled=$false
  try{
    for($i=0;$i-lt$valid.Count;$i++){
      $status.Text="Запуск $($i+1)/$($valid.Count): $($valid[$i].Role)";[Windows.Forms.Application]::DoEvents()
      [void](Launch-Character $valid[$i])
      if($i-lt$valid.Count-1){
        $until=(Get-Date).AddSeconds([int]$delay.Value)
        while((Get-Date)-lt$until){Start-Sleep -Milliseconds 100;[Windows.Forms.Application]::DoEvents()}
      }
    }
  }finally{$launchSelected.Enabled=$true;$launchAll.Enabled=$true;$scan.Enabled=$true}
  $status.Text="Готово. Надіслано запусків: $($valid.Count)";$status.ForeColor=$cyan
}
function Render-Cards {
  foreach($c in @($flow.Controls)){if($c.Tag -and $c.Tag.Icon.Image){$c.Tag.Icon.Image.Dispose()}}
  $flow.Controls.Clear()
  foreach($item in $script:Characters){
    $card=New-Object Windows.Forms.Panel;$card.Size='312,160';$card.Margin='8,8,8,8';$card.BackColor=if($item.Valid){$panel}else{[Drawing.Color]::FromArgb(58,29,28)}
    $check=New-Object Windows.Forms.CheckBox;$check.SetBounds(12,12,24,24);$check.Checked=[bool]$item.Selected;$check.Enabled=[bool]$item.Valid;$check.BackColor=[Drawing.Color]::Transparent
    $icon=New-Object Windows.Forms.PictureBox;$icon.SetBounds(42,18,58,58);$icon.SizeMode='StretchImage';$icon.Image=New-ClassIcon $item.Class
    $name=New-Label $item.Role.ToUpperInvariant() 112 12 187 25 11 $goldSoft 'Bold'
    $role=New-Label 'Збережений профіль' 112 39 187 23 9 $textColor
    $combo=New-Object Windows.Forms.ComboBox;$combo.SetBounds(112,66,187,26);$combo.DropDownStyle='DropDownList';$combo.BackColor=$jade;$combo.ForeColor=$textColor
    [void]$combo.Items.AddRange([object[]]$classes);$combo.SelectedItem=$item.Class;if($combo.SelectedIndex-lt0){$combo.SelectedIndex=0};$combo.Enabled=[bool]$item.Valid
    $infoColor=if($item.Valid){$muted}else{$danger};$info=New-Label $item.Reason 12 101 286 22 8 $infoColor
    $accountData=Get-Account $item.FileName;$accountButton=New-Object Windows.Forms.Button;$accountButton.Text=if($accountData.Login){'✓ АКАУНТ'}else{'АКАУНТ'};$accountButton.SetBounds(12,126,120,26);Style-Button $accountButton $jade2;$accountButton.Enabled=[bool]$item.Valid;$accountButton.Tag=$item;$accountButton.Add_Click({Show-AccountDialog $this.Tag $this})
    $run=New-Object Windows.Forms.Button;$run.Text='ЗАПУСТИТИ';$run.SetBounds(172,126,127,26);Style-Button $run ([Drawing.Color]::FromArgb(18,126,98));$run.Enabled=[bool]$item.Valid;$run.Tag=$item;$run.Add_Click({Update-ConfigFromCards;[void](Launch-Character $this.Tag)})
    $combo.Add_SelectedIndexChanged({$owner=$this.Parent;if($owner -and $owner.Tag){$owner.Tag.Icon.Image.Dispose();$owner.Tag.Icon.Image=New-ClassIcon ([string]$this.SelectedItem);Update-ConfigFromCards}})
    $check.Add_CheckedChanged({Update-ConfigFromCards})
    $card.Controls.AddRange(@($check,$icon,$name,$role,$combo,$info,$accountButton,$run));$card.Tag=[pscustomobject]@{Item=$item;Combo=$combo;Check=$check;Icon=$icon};$flow.Controls.Add($card)
  }
  $validCount=@($script:Characters|Where-Object Valid).Count;$badCount=$script:Characters.Count-$validCount
  $badSuffix=if($badCount){" · потребують уваги: $badCount"}else{''};$summary.Text="Персонажів: $validCount"+$badSuffix
}
function Rescan {
  $script:Characters=Get-Profiles;Render-Cards
}

$script:Launched=@{}
if($LaunchProfile){
  $profile=@($script:Characters|Where-Object FileName -eq $LaunchProfile)|Select-Object -First 1
  if(-not $profile){Write-Error 'Профіль не знайдено.';exit 2}
  if(Launch-Character $profile){exit 0}else{exit 1}
}
foreach($profile in $script:Characters){Sync-ProfileBat $profile.FileName $profile.Role}
$form=New-Object Windows.Forms.Form;$form.Text='Cyber.pw Asistant — MultiLauncher';$form.Size='1040,760';$form.MinimumSize='900,650';$form.StartPosition='CenterScreen';$form.BackColor=$jade;$form.ForeColor=$textColor;$form.Font=New-Object Drawing.Font('Segoe UI',9);$form.Icon=$null
$header=New-Label 'MULTILAUNCHER' 24 16 400 42 24 $goldSoft 'Bold'
$sub=New-Label 'Створюйте профілі персонажів і запускайте їх без ручного редагування BAT' 27 58 700 24 10 $muted
$pathBox=New-Object Windows.Forms.TextBox;$pathBox.SetBounds(26,94,625,30);$pathBox.ReadOnly=$true;$pathBox.Text=$script:GamePath;$pathBox.BackColor=$panel;$pathBox.ForeColor=$textColor
$browse=New-Object Windows.Forms.Button;$browse.Text='ПАПКА ГРИ';$browse.SetBounds(660,92,112,34);Style-Button $browse $jade2
$scan=New-Object Windows.Forms.Button;$scan.Text='+ ПРОФІЛЬ';$scan.SetBounds(780,92,112,34);Style-Button $scan ([Drawing.Color]::FromArgb(18,126,98))
$windows=New-Label 'Вікон: 0' 902 98 100 24 10 $cyan 'Bold'
$summary=New-Label 'Персонажів: 0' 26 136 500 24 10 $textColor 'Bold'
$delayLabel=New-Label 'Затримка між вікнами:' 620 136 170 24 9 $muted
$delay=New-Object Windows.Forms.NumericUpDown;$delay.SetBounds(790,134,58,26);$delay.Minimum=1;$delay.Maximum=30;$delay.Value=[Math]::Min(30,[Math]::Max(1,[int]$script:Config.DelaySeconds));$delay.BackColor=$panel;$delay.ForeColor=$textColor
$sec=New-Label 'сек.' 852 136 42 24 9 $muted
$flow=New-Object Windows.Forms.FlowLayoutPanel;$flow.SetBounds(18,169,988,466);$flow.Anchor='Top,Bottom,Left,Right';$flow.AutoScroll=$true;$flow.WrapContents=$true;$flow.BackColor=[Drawing.Color]::FromArgb(6,36,31);$flow.Padding='8,8,8,8'
$status=New-Label 'Оберіть папку гри та створіть перший профіль.' 26 646 560 28 9 $muted;$status.Anchor='Bottom,Left'
$launchSelected=New-Object Windows.Forms.Button;$launchSelected.Text='▶ ЗАПУСТИТИ ВИБРАНИХ';$launchSelected.SetBounds(596,642,190,42);$launchSelected.Anchor='Bottom,Right';Style-Button $launchSelected ([Drawing.Color]::FromArgb(18,126,98))
$launchAll=New-Object Windows.Forms.Button;$launchAll.Text='▶▶ ЗАПУСТИТИ ВСІХ';$launchAll.SetBounds(796,642,190,42);$launchAll.Anchor='Bottom,Right';Style-Button $launchAll ([Drawing.Color]::FromArgb(138,94,16))
$note=New-Label 'Збережені логіни й паролі шифруються Windows для поточного користувача та не записуються в журнал.' 26 690 760 24 8 $muted;$note.Anchor='Bottom,Left'
$form.Controls.AddRange(@($header,$sub,$pathBox,$browse,$scan,$windows,$summary,$delayLabel,$delay,$sec,$flow,$status,$launchSelected,$launchAll,$note))

$browse.Add_Click({$dlg=New-Object Windows.Forms.FolderBrowserDialog;$dlg.Description='Оберіть папку CyberPW з ElementClient.exe';if($script:GamePath){$dlg.SelectedPath=$script:GamePath};if($dlg.ShowDialog()-eq'OK'){$resolved=Resolve-GamePath $dlg.SelectedPath;if(-not $resolved){[Windows.Forms.MessageBox]::Show('У цій папці не знайдено ElementClient.exe.','MultiLauncher')|Out-Null;return};$script:GamePath=$resolved;$pathBox.Text=$resolved;$script:Config.GamePath=$resolved;Save-Config;Rescan}})
$scan.Add_Click({if(-not $script:GamePath){[Windows.Forms.MessageBox]::Show('Спочатку оберіть папку гри.','MultiLauncher')|Out-Null;return};Show-CreateProfileDialog})
$launchSelected.Add_Click({$items=@();foreach($card in @($flow.Controls)){if($card.Tag.Check.Checked){$items+=$card.Tag.Item}};Launch-Many $items})
$launchAll.Add_Click({Launch-Many @($script:Characters|Where-Object Valid)})
$delay.Add_ValueChanged({$script:Config.DelaySeconds=[int]$delay.Value;Save-Config})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1500;$timer.Add_Tick({$windows.Text='Вікон: '+@(Get-Process -Name ElementClient -ErrorAction SilentlyContinue).Count});$timer.Start()
$form.Add_FormClosed({$timer.Stop();Update-ConfigFromCards;foreach($card in @($flow.Controls)){if($card.Tag.Icon.Image){$card.Tag.Icon.Image.Dispose()}}})
Render-Cards
if(-not $script:GamePath){$status.Text='Папку CyberPW не знайдено автоматично. Оберіть її вручну.'}elseif(-not $script:Characters.Count){$status.Text='Папку гри знайдено. Натисніть «+ ПРОФІЛЬ».'}else{$status.Text='Готово. Запускайте одного або кілька персонажів.'}
[void]$form.ShowDialog()
