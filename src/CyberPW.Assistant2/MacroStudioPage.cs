using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class MacroStudioPage:UserControl,IModulePage
    {
        readonly DataGridView grid=new DataGridView();readonly TextBox name=new TextBox(),target=new TextBox(),startKey=new TextBox(),stopKey=new TextBox();readonly Label status;readonly MacroRunner runner=new MacroRunner();readonly System.Windows.Forms.Timer hotkeys=new System.Windows.Forms.Timer();bool running,startDown,stopDown;
        public string Title{get{return"Macro Studio";}}
        public MacroStudioPage()
        {
            BackColor=Theme.Ink;var h=Theme.Label("MACRO STUDIO · C#",24,Theme.GoldSoft,FontStyle.Bold);h.Location=new Point(22,18);Controls.Add(h);
            name.SetBounds(24,70,220,30);name.Text="Новий макрос";target.SetBounds(260,70,150,30);target.Text="ElementClient";startKey.SetBounds(425,70,65,30);startKey.Text="F10";stopKey.SetBounds(505,70,65,30);stopKey.Text="F12";Controls.AddRange(new Control[]{name,target,startKey,stopKey});
            grid.SetBounds(24,115,820,390);grid.AllowUserToAddRows=false;grid.BackgroundColor=Theme.Panel;grid.ForeColor=Color.Black;grid.Columns.Add("command","КОМАНДА");grid.Columns.Add("argument","АРГУМЕНТ");grid.Columns.Add("description","ОПИС");grid.Columns[0].Width=150;grid.Columns[1].Width=250;grid.Columns[2].Width=390;Controls.Add(grid);
            var add=Theme.Button("+ ДІЯ");add.SetBounds(24,520,100,40);add.Click+=delegate{grid.Rows.Add("WAIT","100","Пауза, мс");};Controls.Add(add);
            var remove=Theme.Button("ВИДАЛИТИ");remove.SetBounds(135,520,110,40);remove.Click+=delegate{if(grid.CurrentRow!=null)grid.Rows.Remove(grid.CurrentRow);};Controls.Add(remove);
            var save=Theme.Button("ЗБЕРЕГТИ");save.SetBounds(260,520,120,40);save.Click+=delegate{Save();};Controls.Add(save);
            var open=Theme.Button("ВІДКРИТИ");open.SetBounds(390,520,120,40);open.Click+=delegate{Open();};Controls.Add(open);
            var run=Theme.Button("ЗАПУСТИТИ");run.SetBounds(525,520,140,40);run.Click+=delegate{Start();};Controls.Add(run);
            var stop=Theme.Button("СТОП");stop.SetBounds(680,520,140,40);stop.Click+=delegate{Stop();};Controls.Add(stop);
            status=Theme.Label("ГОТОВО",9,Theme.Cyan,FontStyle.Bold);status.Location=new Point(25,580);Controls.Add(status);
            hotkeys.Interval=40;hotkeys.Tick+=delegate{PollHotkeys();};hotkeys.Start();
        }
        List<MacroRow> Rows(){var rows=new List<MacroRow>();foreach(DataGridViewRow r in grid.Rows)rows.Add(new MacroRow{command=Convert.ToString(r.Cells[0].Value),argument=Convert.ToString(r.Cells[1].Value),description=Convert.ToString(r.Cells[2].Value)});return rows;}
        void Save(){try{Directory.CreateDirectory(AppPaths.Macros);var file=new MacroFile{schemaVersion=4,name=name.Text,targetProcess=target.Text,startHotkey=startKey.Text,stopHotkey=stopKey.Text,steps=Rows()};JsonFiles.Write(Path.Combine(AppPaths.Macros,Safe(name.Text)+".json"),file);status.Text="ЗБЕРЕЖЕНО";}catch(Exception e){status.Text=e.Message;}}
        void Open(){using(var d=new OpenFileDialog()){d.InitialDirectory=AppPaths.Macros;d.Filter="Macro (*.json)|*.json";if(d.ShowDialog()!=DialogResult.OK)return;var f=JsonFiles.Read<MacroFile>(d.FileName);if(f.schemaVersion<2||f.schemaVersion>4)throw new InvalidOperationException("Непідтримуваний формат.");name.Text=f.name;target.Text=f.targetProcess;startKey.Text=f.startHotkey??"F10";stopKey.Text=f.stopHotkey??"F12";grid.Rows.Clear();foreach(var r in f.steps)grid.Rows.Add(r.command,r.argument,r.description);}}
        void Start(){if(running)return;try{var steps=MacroCompiler.Compile(Rows());running=true;status.Text="ПРАЦЮЄ";new Thread(new ThreadStart(delegate{try{runner.Run(steps,target.Text,true);}catch(Exception e){BeginInvoke((Action)(()=>status.Text=e.Message));}finally{running=false;}})){IsBackground=true}.Start();}catch(Exception e){status.Text=e.Message;}}
        void Stop(){runner.Stop();running=false;status.Text="ЗУПИНЕНО";}
        void PollHotkeys(){Keys a,b;if(!Enum.TryParse(startKey.Text,true,out a)||!Enum.TryParse(stopKey.Text,true,out b))return;bool ad=(MacroNative.GetAsyncKeyState((int)a)&0x8000)!=0,bd=(MacroNative.GetAsyncKeyState((int)b)&0x8000)!=0;if(ad&&!startDown)Start();if(bd&&!stopDown)Stop();startDown=ad;stopDown=bd;}
        static string Safe(string value){foreach(char c in Path.GetInvalidFileNameChars())value=value.Replace(c,'_');return string.IsNullOrWhiteSpace(value)?"Новий макрос":value.Trim();}
        public void OnActivated(){}
    }
}
