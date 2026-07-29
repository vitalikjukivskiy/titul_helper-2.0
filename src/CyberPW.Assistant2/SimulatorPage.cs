using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class Drop { public string name { get; set; } public double chance { get; set; } public int stack { get; set; } public string icon { get; set; } }
    internal sealed class SimulatorPage : UserControl, IModulePage
    {
        readonly List<Drop> drops; readonly Dictionary<string,int> counts=new Dictionary<string,int>(); readonly Random rng=new Random();
        readonly NumericUpDown amount=new NumericUpDown(); readonly ListView list=new ListView(); readonly Label opened; readonly Label last; readonly PictureBox lastIcon=new PictureBox(); readonly ImageList images=new ImageList(); int total;
        public string Title { get { return "Симулятор"; } }
        public SimulatorPage()
        {
            BackColor=Theme.Ink; drops=JsonFiles.Read<List<Drop>>(System.IO.Path.Combine(AppPaths.Data,"chest-drops.json"));
            var title=Theme.Label("СИМУЛЯТОР СКРИНІ ТОРА · BETA",24,Theme.GoldSoft,FontStyle.Bold);title.Location=new Point(24,20);Controls.Add(title);
            amount.SetBounds(26,85,170,38);amount.Minimum=1;amount.Maximum=1000000;amount.Value=10;Controls.Add(amount);
            var open=Theme.Button("ВІДКРИТИ");open.SetBounds(215,83,170,42);open.Click+=delegate{Open((int)amount.Value);};Controls.Add(open);
            var reset=Theme.Button("СКИНУТИ");reset.SetBounds(400,83,140,42);reset.Click+=delegate{counts.Clear();total=0;RefreshRows();};Controls.Add(reset);
            opened=Theme.Label("ВІДКРИТО: 0",18,Theme.Cyan,FontStyle.Bold);opened.Location=new Point(580,87);Controls.Add(opened);
            lastIcon.SetBounds(27,138,52,52);lastIcon.SizeMode=PictureBoxSizeMode.Zoom;Controls.Add(lastIcon);
            last=Theme.Label("Скриня чекає відкриття",14,Theme.GoldSoft,FontStyle.Bold);last.Location=new Point(94,150);Controls.Add(last);
            list.SetBounds(26,200,850,420);list.View=View.Details;list.FullRowSelect=true;list.BackColor=Theme.Panel;list.ForeColor=Theme.Text;
            images.ImageSize=new Size(40,40);images.ColorDepth=ColorDepth.Depth32Bit;foreach(var d in drops){string path=System.IO.Path.Combine(AppPaths.LootIcons,d.icon);if(System.IO.File.Exists(path)&&!images.Images.ContainsKey(d.icon)){using(var source=Image.FromFile(path))images.Images.Add(d.icon,new Bitmap(source));}}list.SmallImageList=images;
            list.Columns.Add("Предмет",430);list.Columns.Add("Шанс",100);list.Columns.Add("Разів",90);list.Columns.Add("Штук",90);list.Columns.Add("Фактично",110);Controls.Add(list);
        }
        void Open(int n){Drop d=null;double weight=drops.Sum(x=>x.chance);for(int i=0;i<n;i++){double r=rng.NextDouble()*weight,s=0;foreach(var x in drops){s+=x.chance;if(r<s){d=x;break;}}if(!counts.ContainsKey(d.name))counts[d.name]=0;counts[d.name]++;}total+=n;last.Text=d.name+" · "+d.stack+" шт.";lastIcon.Image=images.Images.ContainsKey(d.icon)?images.Images[d.icon]:null;RefreshRows();}
        void RefreshRows(){opened.Text="ВІДКРИТО: "+total;list.Items.Clear();foreach(var d in drops){int c;if(!counts.TryGetValue(d.name,out c)||c==0)continue;var row=new ListViewItem(d.name);row.ImageKey=d.icon;row.ForeColor=d.chance<.05?Theme.GoldSoft:(d.chance<1?Theme.Cyan:Theme.Text);row.SubItems.Add(d.chance.ToString("N3")+"%");row.SubItems.Add(c.ToString());row.SubItems.Add((c*d.stack).ToString());row.SubItems.Add((100.0*c/Math.Max(1,total)).ToString("N3")+"%");list.Items.Add(row);}}
        public void OnActivated(){}
    }
}
