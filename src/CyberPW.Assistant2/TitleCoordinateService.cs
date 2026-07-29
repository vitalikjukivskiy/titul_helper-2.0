using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal static class TitleCoordinateService
    {
        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
        [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
        [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
        [DllImport("user32.dll")] static extern void mouse_event(uint flags,uint dx,uint dy,int data,UIntPtr extra);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr h,int command);
        [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left,Top,Right,Bottom; }
        [StructLayout(LayoutKind.Sequential)] struct POINT { public int X,Y; }

        public static Point CaptureRelative(Form owner)
        {
            owner.WindowState=FormWindowState.Minimized;Thread.Sleep(3000);
            try
            {
                Process game=FindGame();if(game==null)throw new InvalidOperationException("CyberPW не запущено.");
                RECT rect;POINT cursor;if(!GetWindowRect(game.MainWindowHandle,out rect)||!GetCursorPos(out cursor))throw new InvalidOperationException("Не вдалося прочитати положення вікна.");
                if(cursor.X<rect.Left||cursor.X>=rect.Right||cursor.Y<rect.Top||cursor.Y>=rect.Bottom)throw new InvalidOperationException("Курсор був поза вікном CyberPW.");
                return new Point(cursor.X-rect.Left,cursor.Y-rect.Top);
            }
            finally { owner.WindowState=FormWindowState.Normal;owner.Activate(); }
        }

        public static void Inject(Form owner,TitleRecord title,Dictionary<string,object> config)
        {
            if(title==null)throw new InvalidOperationException("Оберіть титул.");
            if(title.x==0&&title.y==0)throw new InvalidOperationException("Цей титул не має координат.");
            int ox=Get(config,"OpenOffsetX"),oy=Get(config,"OpenOffsetY"),cx=Get(config,"CoordOffsetX"),cy=Get(config,"CoordOffsetY"),delay=Math.Max(100,Get(config,"DelayMs",650));
            if(ox<=0||oy<=0||cx<=0||cy<=0)throw new InvalidOperationException("Спочатку налаштуйте обидві координатні точки.");
            Process game=FindGame();if(game==null)throw new InvalidOperationException("CyberPW не запущено.");
            RECT rect;if(!GetWindowRect(game.MainWindowHandle,out rect))throw new InvalidOperationException("Не вдалося визначити вікно CyberPW.");
            owner.WindowState=FormWindowState.Minimized;ShowWindowAsync(game.MainWindowHandle,9);SetForegroundWindow(game.MainWindowHandle);Thread.Sleep(350);
            Click(rect.Left+ox,rect.Top+oy);Thread.Sleep(delay);Click(rect.Left+cx,rect.Top+cy);Thread.Sleep(180);
            SendKeys.SendWait("{END}");SendKeys.SendWait("{BACKSPACE 12}");SendKeys.SendWait(title.x+" "+title.y);SendKeys.SendWait("{ENTER}");Thread.Sleep(delay);SendKeys.SendWait(title.name);SendKeys.SendWait("{ENTER}");
        }

        public static int Get(Dictionary<string,object> config,string key,int fallback=0)
        {
            object value;if(config!=null&&config.TryGetValue(key,out value)){int parsed;if(int.TryParse(Convert.ToString(value),out parsed))return parsed;}return fallback;
        }
        static Process FindGame()
        {
            Process best=null;long bestArea=-1;foreach(Process p in Process.GetProcessesByName("ElementClient")){if(p.MainWindowHandle==IntPtr.Zero)continue;RECT r;if(GetWindowRect(p.MainWindowHandle,out r)){long area=(long)(r.Right-r.Left)*(r.Bottom-r.Top);if(area>bestArea){best=p;bestArea=area;}}}return best;
        }
        static void Click(int x,int y){SetCursorPos(x,y);mouse_event(2,0,0,0,UIntPtr.Zero);mouse_event(4,0,0,0,UIntPtr.Zero);}
    }

    internal sealed class CoordinateSetupDialog:Form
    {
        readonly Dictionary<string,object> config;readonly Label status=new Label();
        public CoordinateSetupDialog(Dictionary<string,object> state)
        {
            config=state;Text="TitulHelper — налаштування координат";ClientSize=new Size(720,510);StartPosition=FormStartPosition.CenterParent;FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;MinimizeBox=false;BackColor=Theme.Ink;ForeColor=Theme.Text;
            var heading=Theme.Label("НАЛАШТУВАННЯ У ДВА КРОКИ",16,Theme.GoldSoft,FontStyle.Bold);heading.Location=new Point(24,18);Controls.Add(heading);
            AddStep("КРОК 1 · КНОПКА ВІДКРИТТЯ","coordinate-toggle.png",24,delegate{CaptureStep("OpenOffsetX","OpenOffsetY");});
            AddStep("КРОК 2 · ПОЛЕ КООРДИНАТ","coordinate-field.png",376,delegate{CaptureStep("CoordOffsetX","CoordOffsetY");});
            status.SetBounds(24,430,520,40);status.ForeColor=Theme.Cyan;Controls.Add(status);var close=Theme.Button("ГОТОВО");close.SetBounds(560,430,136,42);close.Click+=delegate{DialogResult=DialogResult.OK;};Controls.Add(close);RefreshStatus();
        }
        void AddStep(string title,string image,int x,EventHandler action)
        {
            var group=new GroupBox{Text=title,ForeColor=Theme.GoldSoft};group.SetBounds(x,100,320,310);
            var box=new PictureBox{Image=AssetImages.Load("help",image),SizeMode=PictureBoxSizeMode.Zoom,BackColor=Theme.Panel};box.SetBounds(16,35,286,180);group.Controls.Add(box);
            var button=Theme.Button(title.StartsWith("КРОК 1")?"1 · ЗАПАМ’ЯТАТИ КНОПКУ":"2 · ЗАПАМ’ЯТАТИ ПОЛЕ");button.SetBounds(16,245,286,44);button.Click+=action;group.Controls.Add(button);Controls.Add(group);
        }
        void CaptureStep(string x,string y){try{Hide();Point p=TitleCoordinateService.CaptureRelative(Owner);config[x]=p.X;config[y]=p.Y;}catch(Exception e){MessageBox.Show(e.Message,"TitulHelper");}finally{Show();Activate();RefreshStatus();}}
        void RefreshStatus(){status.Text="Кнопка: "+(TitleCoordinateService.Get(config,"OpenOffsetX")>0?"ГОТОВО ✓":"НЕ НАЛАШТОВАНО")+"     Поле: "+(TitleCoordinateService.Get(config,"CoordOffsetX")>0?"ГОТОВО ✓":"НЕ НАЛАШТОВАНО");}
    }
}
