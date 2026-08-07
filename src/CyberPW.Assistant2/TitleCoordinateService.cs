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

        static readonly Point[] ProbeOffsets = new Point[]
        {
            new Point(0,0), new Point(-18,0), new Point(18,0),
            new Point(0,-8), new Point(0,8), new Point(-12,-6), new Point(12,6)
        };

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

        public static void SaveCoordinateReference(Point relative, Dictionary<string,object> config)
        {
            try
            {
                Process game=FindGame(); if(game==null) return;
                RECT rect; if(!GetWindowRect(game.MainWindowHandle,out rect)) return;
                Color[] signature=ReadSignature(rect,relative.X,relative.Y);
                for(int i=0;i<signature.Length;i++)
                {
                    config["CoordSig"+i+"R"]=signature[i].R;
                    config["CoordSig"+i+"G"]=signature[i].G;
                    config["CoordSig"+i+"B"]=signature[i].B;
                }
                config["CoordSigCount"]=signature.Length;
            }
            catch { }
        }

        public static void Inject(Form owner,TitleRecord title,Dictionary<string,object> config)
        {
            if(title==null)throw new InvalidOperationException("Оберіть титул.");
            if(title.x==0&&title.y==0)throw new InvalidOperationException("Цей титул не має координат.");

            int ox=Get(config,"OpenOffsetX"),oy=Get(config,"OpenOffsetY"),cx=Get(config,"CoordOffsetX"),cy=Get(config,"CoordOffsetY");
            int delay=Math.Max(250,Get(config,"DelayMs",650));
            if(ox<=0||oy<=0||cx<=0||cy<=0)throw new InvalidOperationException("Спочатку налаштуйте обидві координатні точки.");

            Process game=FindGame();if(game==null)throw new InvalidOperationException("CyberPW не запущено.");
            owner.WindowState=FormWindowState.Minimized;

            Activate(game);
            PressEscape(2,130);
            Thread.Sleep(250);

            RECT rect;if(!GetWindowRect(game.MainWindowHandle,out rect))throw new InvalidOperationException("Не вдалося визначити вікно CyberPW.");

            if(!EnsureCoordinatePanel(game,rect,ox,oy,cx,cy,config,delay))
            {
                PressEscape(3,120);
                throw new InvalidOperationException(
                    "Не вдалося відкрити поле координат біля карти.\n\n"+
                    "TitulHelper зупинив введення, щоб координати або назва не потрапили в інше поле.\n"+
                    "Спробуйте повторно налаштувати КРОК 1 і КРОК 2 або активувати клієнт гри.");
            }

            Activate(game);
            if(!GetWindowRect(game.MainWindowHandle,out rect))throw new InvalidOperationException("Не вдалося визначити вікно CyberPW.");
            Click(rect.Left+cx,rect.Top+cy);
            Thread.Sleep(220);

            PressKey(Keys.End);
            for(int i=0;i<16;i++){ PressKey(Keys.Back); Thread.Sleep(12); }
            MacroNative.Text(title.x+" "+title.y);
            PressKey(Keys.Enter);
            Thread.Sleep(delay);

            MacroNative.Text(title.name);
            PressKey(Keys.Enter);
            Thread.Sleep(260);

            Activate(game);
            PressEscape(3,130);
        }

        static bool EnsureCoordinatePanel(Process game,RECT rect,int ox,int oy,int cx,int cy,Dictionary<string,object> config,int delay)
        {
            Color[] before=ReadSignature(rect,cx,cy);

            Activate(game);
            Click(rect.Left+ox,rect.Top+oy);
            Thread.Sleep(delay);

            if(PanelLooksOpen(rect,cx,cy,config,before)) return true;

            Activate(game);
            if(!GetWindowRect(game.MainWindowHandle,out rect)) return false;
            before=ReadSignature(rect,cx,cy);
            Click(rect.Left+ox,rect.Top+oy);
            Thread.Sleep(Math.Max(delay,800));

            return PanelLooksOpen(rect,cx,cy,config,before);
        }

        static bool PanelLooksOpen(RECT rect,int cx,int cy,Dictionary<string,object> config,Color[] before)
        {
            Color[] now=ReadSignature(rect,cx,cy);
            int expectedCount=Get(config,"CoordSigCount",0);
            if(expectedCount==ProbeOffsets.Length)
            {
                int matches=0;
                int beforeDistance=0;
                int nowDistance=0;
                for(int i=0;i<ProbeOffsets.Length;i++)
                {
                    int rr=Get(config,"CoordSig"+i+"R",-1);
                    int gg=Get(config,"CoordSig"+i+"G",-1);
                    int bb=Get(config,"CoordSig"+i+"B",-1);
                    if(rr<0||gg<0||bb<0) continue;

                    int dNow=Distance(now[i],rr,gg,bb);
                    int dBefore=Distance(before[i],rr,gg,bb);
                    nowDistance+=dNow;
                    beforeDistance+=dBefore;
                    if(dNow<=150) matches++;
                }

                if(matches>=4 && nowDistance+120<beforeDistance) return true;
                if(matches>=5 && nowDistance<=650) return true;
            }

            int changedPoints=0;
            for(int i=0;i<ProbeOffsets.Length;i++)
                if(ColorDistance(now[i],before[i])>=80) changedPoints++;
            return changedPoints>=3;
        }

        static Color[] ReadSignature(RECT rect,int cx,int cy)
        {
            Color[] values=new Color[ProbeOffsets.Length];
            for(int i=0;i<ProbeOffsets.Length;i++)
                values[i]=SafePixel(rect.Left+cx+ProbeOffsets[i].X,rect.Top+cy+ProbeOffsets[i].Y);
            return values;
        }

        static int Distance(Color value,int r,int g,int b)
        {
            return Math.Abs(value.R-r)+Math.Abs(value.G-g)+Math.Abs(value.B-b);
        }

        static int ColorDistance(Color a,Color b)
        {
            return Math.Abs(a.R-b.R)+Math.Abs(a.G-b.G)+Math.Abs(a.B-b.B);
        }

        static Color SafePixel(int x,int y)
        {
            try { return MacroNative.Pixel(x,y); }
            catch { return Color.Black; }
        }

        static void Activate(Process game)
        {
            if(game==null||game.HasExited||game.MainWindowHandle==IntPtr.Zero)throw new InvalidOperationException("Вікно CyberPW вже закрито.");
            ShowWindowAsync(game.MainWindowHandle,9);
            SetForegroundWindow(game.MainWindowHandle);
            Thread.Sleep(350);
        }

        static void PressEscape(int count,int pause)
        {
            for(int i=0;i<count;i++){ PressKey(Keys.Escape); Thread.Sleep(pause); }
        }

        static void PressKey(Keys key)
        {
            MacroNative.Key((ushort)key,false);
            MacroNative.Key((ushort)key,true);
        }

        public static int Get(Dictionary<string,object> config,string key,int fallback=0)
        {
            object value;if(config!=null&&config.TryGetValue(key,out value)){int parsed;if(int.TryParse(Convert.ToString(value),out parsed))return parsed;}return fallback;
        }

        static Process FindGame()
        {
            Process best=null;long bestArea=-1;
            foreach(Process p in Process.GetProcessesByName("ElementClient"))
            {
                if(p.MainWindowHandle==IntPtr.Zero)continue;
                RECT r;if(GetWindowRect(p.MainWindowHandle,out r))
                {
                    long area=(long)(r.Right-r.Left)*(r.Bottom-r.Top);
                    if(area>bestArea){best=p;bestArea=area;}
                }
            }
            return best;
        }

        static void Click(int x,int y)
        {
            SetCursorPos(x,y);
            Thread.Sleep(45);
            mouse_event(2,0,0,0,UIntPtr.Zero);
            Thread.Sleep(35);
            mouse_event(4,0,0,0,UIntPtr.Zero);
        }
    }

    internal sealed class CoordinateSetupDialog:Form
    {
        readonly Dictionary<string,object> config;readonly Label status=new Label();
        public CoordinateSetupDialog(Dictionary<string,object> state)
        {
            config=state;Text="TitulHelper — налаштування координат";ClientSize=new Size(720,510);StartPosition=FormStartPosition.CenterParent;FormBorderStyle=FormBorderStyle.FixedDialog;MaximizeBox=false;MinimizeBox=false;BackColor=Theme.Ink;ForeColor=Theme.Text;BackgroundImage=AssetImages.Load("summer","titles.jpg");BackgroundImageLayout=ImageLayout.Stretch;
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
        void CaptureStep(string x,string y)
        {
            try
            {
                Hide();
                Point p=TitleCoordinateService.CaptureRelative(Owner);
                config[x]=p.X;config[y]=p.Y;
                if(x=="CoordOffsetX") TitleCoordinateService.SaveCoordinateReference(p,config);
            }
            catch(Exception e){MessageBox.Show(e.Message,"TitulHelper");}
            finally{Show();Activate();RefreshStatus();}
        }
        void RefreshStatus(){status.Text="Кнопка: "+(TitleCoordinateService.Get(config,"OpenOffsetX")>0?"ГОТОВО ✓":"НЕ НАЛАШТОВАНО")+"     Поле: "+(TitleCoordinateService.Get(config,"CoordOffsetX")>0?"ГОТОВО ✓":"НЕ НАЛАШТОВАНО");}
    }
}
