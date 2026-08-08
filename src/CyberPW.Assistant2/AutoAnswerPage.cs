using System;using System.Diagnostics;using System.Drawing;using System.IO;using System.Windows.Forms;
namespace CyberPW.Assistant2{internal sealed class AutoAnswerPage:UserControl,IModulePage{
 readonly Label status;readonly Button launch,setup;
 string ModuleRoot{get{return Path.Combine(AppPaths.Root,"modules","autoanswer");}}
 string Entry{get{return Path.Combine(ModuleRoot,"CyberPW-AutoAnswer-SUPER-BETA.ps1");}}
 string SetupScript{get{return Path.Combine(ModuleRoot,"Ensure-OcrRuntime.ps1");}}
 string TessExe{get{return Path.Combine(ModuleRoot,"runtime","tesseract","tesseract.exe");}}
 public AutoAnswerPage(){Dock=DockStyle.Fill;BackColor=Theme.Ink;ForeColor=Theme.Text;Font=new Font("Segoe UI",10);
  var title=Theme.Label("АВТОВІДПОВІДІ · СУПЕР БЕТА",22,Theme.GoldSoft,FontStyle.Bold);title.SetBounds(28,28,760,42);Controls.Add(title);
  var sub=Theme.Label("Чон-Пон + КХ · OCR-помічник · без автокліків",11,Theme.Cyan,FontStyle.Bold);sub.SetBounds(30,78,760,30);Controls.Add(sub);
  var card=new CardPanel();card.SetBounds(28,126,790,255);Controls.Add(card);
  var info=Theme.Label("Сканує вікно CyberPW, знаходить питання та показує правильну відповідь тільки коли впевненість достатня.\n\n• Чон-Пон + КХ в одному модулі\n• кастомна область сканування\n• український інтерфейс\n• найкращі збіги замість сирого OCR\n• автокліків немає",11,Theme.Text,FontStyle.Regular);info.AutoSize=false;info.SetBounds(24,20,735,160);card.Controls.Add(info);
  status=Theme.Label("",10,Theme.Muted,FontStyle.Bold);status.SetBounds(28,405,790,30);Controls.Add(status);
  launch=Theme.Button("▶ ВІДКРИТИ АВТОВІДПОВІДІ");launch.SetBounds(28,455,300,46);launch.Click+=(s,e)=>LaunchModule();Controls.Add(launch);
  setup=Theme.Button("⚙ ПІДГОТУВАТИ OCR");setup.SetBounds(348,455,230,46);setup.Click+=(s,e)=>RunPowerShell(SetupScript,true);Controls.Add(setup);
  var note=Theme.Label("На новому ПК один раз натисни «ПІДГОТУВАТИ OCR». Tesseract встановиться локально в папку модуля, без ручного налаштування.",9,Theme.Muted,FontStyle.Regular);note.AutoSize=false;note.SetBounds(30,525,790,60);Controls.Add(note);UpdateStatus();}
 public void OnActivated(){UpdateStatus();}
 void UpdateStatus(){if(!File.Exists(Entry))status.Text="Модуль не знайдено у збірці.";else if(!File.Exists(TessExe))status.Text="OCR ще не підготовлений на цьому ПК.";else status.Text="Готово до роботи.";}
 void LaunchModule(){if(!File.Exists(Entry)){MessageBox.Show("Файл модуля відсутній:\n"+Entry,"Автовідповіді");return;}if(!File.Exists(TessExe)){var r=MessageBox.Show("OCR ще не підготовлений. Підготувати зараз?","Автовідповіді",MessageBoxButtons.YesNo,MessageBoxIcon.Information);if(r==DialogResult.Yes)RunPowerShell(SetupScript,true);UpdateStatus();if(!File.Exists(TessExe))return;}RunPowerShell(Entry,false);}
 void RunPowerShell(string script,bool wait){try{if(!File.Exists(script))throw new FileNotFoundException(script);var psi=new ProcessStartInfo("powershell.exe","-NoProfile -ExecutionPolicy Bypass -File \""+script+"\""){WorkingDirectory=ModuleRoot,UseShellExecute=true};var p=Process.Start(psi);if(wait&&p!=null)p.WaitForExit();UpdateStatus();}catch(Exception ex){MessageBox.Show("Не вдалося запустити модуль.\n\n"+ex.Message,"Автовідповіді",MessageBoxButtons.OK,MessageBoxIcon.Warning);}}
}}