Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if(-not('CyberPWDesignNative'-as[type])){
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CyberPWDesignNative {
  [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd,int attribute,ref int value,int size);
}
'@
}

function Set-CyberPWRounded($Control,[int]$Radius=12){
  if($null-eq$Control-or$Control.Width-lt4-or$Control.Height-lt4){return}
  $diameter=[Math]::Min($Radius*2,[Math]::Min($Control.Width-1,$Control.Height-1))
  $path=New-Object Drawing.Drawing2D.GraphicsPath
  $rect=New-Object Drawing.Rectangle 0,0,($Control.Width-1),($Control.Height-1)
  $path.AddArc($rect.Left,$rect.Top,$diameter,$diameter,180,90)
  $path.AddArc($rect.Right-$diameter,$rect.Top,$diameter,$diameter,270,90)
  $path.AddArc($rect.Right-$diameter,$rect.Bottom-$diameter,$diameter,$diameter,0,90)
  $path.AddArc($rect.Left,$rect.Bottom-$diameter,$diameter,$diameter,90,90)
  $path.CloseFigure()
  $old=$Control.Region
  $Control.Region=New-Object Drawing.Region $path
  $path.Dispose()
  if($old){$old.Dispose()}
}

function Enable-CyberPWDoubleBuffer($Control){
  try{
    $property=$Control.GetType().GetProperty('DoubleBuffered',[Reflection.BindingFlags]'Instance,NonPublic')
    if($property){$property.SetValue($Control,$true,$null)}
  }catch{}
}

function Set-CyberPWDwmCorners($Form){
  try{
    if([Environment]::OSVersion.Version.Major-lt10){return}
    $preference=2
    [void][CyberPWDesignNative]::DwmSetWindowAttribute($Form.Handle,33,[ref]$preference,4)
  }catch{}
}

function Apply-CyberPWVisualPolish($Form){
  if($null-eq$Form){return}
  $theme=Get-CyberPWTheme
  $Form.AutoScaleMode='Dpi'
  $Form.Font=New-Object Drawing.Font('Segoe UI',9)
  $Form.Add_Shown({Set-CyberPWDwmCorners $this})
  Enable-CyberPWDoubleBuffer $Form

  $queue=New-Object Collections.Queue
  foreach($rootControl in $Form.Controls){$queue.Enqueue($rootControl)}
  while($queue.Count){
    $control=$queue.Dequeue()
    Enable-CyberPWDoubleBuffer $control

    if($control-is[Windows.Forms.Button]){
      $control.FlatStyle='Flat'
      $control.FlatAppearance.BorderSize=1
      if($control.FlatAppearance.BorderColor.ToArgb()-eq[Drawing.Color]::Empty.ToArgb()){$control.FlatAppearance.BorderColor=$theme.Gold}
      $control.Font=New-Object Drawing.Font('Segoe UI Semibold',[Math]::Max(8,$control.Font.Size))
      Set-CyberPWRounded $control 9
      $control.Add_Resize({Set-CyberPWRounded $this 9})
    }
    elseif($control-is[Windows.Forms.Panel]){
      if($control.Width-ge100-and$control.Height-ge48-and$control.BackColor.A-gt0){
        Set-CyberPWRounded $control 13
        $control.Add_Resize({Set-CyberPWRounded $this 13})
      }
    }
    elseif($control-is[Windows.Forms.DataGridView]){
      $control.BorderStyle='None'
      $control.CellBorderStyle='SingleHorizontal'
      $control.ColumnHeadersBorderStyle='None'
      $control.ColumnHeadersHeight=[Math]::Max(34,$control.ColumnHeadersHeight)
      $control.RowTemplate.Height=[Math]::Max(34,$control.RowTemplate.Height)
      $control.EnableHeadersVisualStyles=$false
      Set-CyberPWRounded $control 11
      $control.Add_Resize({Set-CyberPWRounded $this 11})
    }
    elseif($control-is[Windows.Forms.ListView]){
      $control.BorderStyle='None'
      Set-CyberPWRounded $control 10
      $control.Add_Resize({Set-CyberPWRounded $this 10})
    }
    elseif($control-is[Windows.Forms.ListBox]){
      $control.BorderStyle='None'
      Set-CyberPWRounded $control 9
      $control.Add_Resize({Set-CyberPWRounded $this 9})
    }
    elseif($control-is[Windows.Forms.TextBox]){
      $control.BorderStyle='FixedSingle'
      $control.Font=New-Object Drawing.Font('Segoe UI',[Math]::Max(9,$control.Font.Size))
    }
    elseif($control-is[Windows.Forms.NumericUpDown]){
      $control.BorderStyle='FixedSingle'
      $control.Font=New-Object Drawing.Font('Segoe UI',[Math]::Max(9,$control.Font.Size))
    }
    elseif($control-is[Windows.Forms.ComboBox]){
      $control.FlatStyle='Flat'
      $control.Font=New-Object Drawing.Font('Segoe UI',[Math]::Max(9,$control.Font.Size))
    }

    foreach($child in $control.Controls){$queue.Enqueue($child)}
  }
  $Form.Invalidate($true)
}
