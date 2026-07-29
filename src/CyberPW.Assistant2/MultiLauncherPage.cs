using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class MultiLauncherPage:UserControl,IModulePage
    {
        LauncherConfig config; readonly TextBox path=new TextBox(); readonly CheckedListBox list=new CheckedListBox(); readonly NumericUpDown delay=new NumericUpDown(); readonly Label status;
        public string Title{get{return"MultiLauncher";}}
        public MultiLauncherPage()
        {
            BackColor = Theme.Ink; BackgroundImage = AssetImages.Load("summer","multilauncher.jpg"); BackgroundImageLayout = ImageLayout.Stretch;config=MultiLauncherStore.Load();
            var h=Theme.Label("MULTILAUNCHER",24,Theme.GoldSoft,FontStyle.Bold);h.Location=new Point(24,20);Controls.Add(h);
            path.SetBounds(26,75,600,32);path.Text=MultiLauncherStore.ResolveGamePath(config.GamePath);path.ReadOnly=true;Controls.Add(path);
            var browse=Theme.Button("ОБРАТИ ПАПКУ");browse.SetBounds(645,70,170,42);browse.Click+=delegate{using(var d=new FolderBrowserDialog()){if(d.ShowDialog()==DialogResult.OK){string p=MultiLauncherStore.ResolveGamePath(d.SelectedPath);if(p=="")MessageBox.Show("ElementClient.exe не знайдено.");else{path.Text=config.GamePath=p;Save();}}}};Controls.Add(browse);
            list.SetBounds(26,130,790,380);list.CheckOnClick=true;list.BackColor=Theme.Panel;list.ForeColor=Theme.Text;Controls.Add(list);
            var add=Theme.Button("+ ПРОФІЛЬ");add.SetBounds(26,530,140,42);add.Click+=delegate{CreateProfile();};Controls.Add(add);
            delay.SetBounds(185,535,60,30);delay.Minimum=1;delay.Maximum=30;delay.Value=Math.Max(1,Math.Min(30,config.DelaySeconds));Controls.Add(delay);
            var selected=Theme.Button("ЗАПУСТИТИ ВИБРАНИХ");selected.SetBounds(420,530,190,42);selected.Click+=delegate{Launch(false);};Controls.Add(selected);
            var all=Theme.Button("ЗАПУСТИТИ ВСІХ");all.SetBounds(625,530,190,42);all.Click+=delegate{Launch(true);};Controls.Add(all);
            status=Theme.Label("",9,Theme.Muted,FontStyle.Regular);status.Location=new Point(28,590);Controls.Add(status);Render();
        }
        void Render(){list.Items.Clear();foreach(var p in config.Characters.OrderBy(x=>x.Value.Nick)){int i=list.Items.Add(new ProfileItem(p.Key,p.Value));list.SetItemChecked(i,p.Value.Selected);}}
        void Save(){config.DelaySeconds=(int)delay.Value;MultiLauncherStore.Save(config);}
        void CreateProfile(){using(var d=new ProfileDialog()){if(d.ShowDialog(FindForm())!=DialogResult.OK)return;string id=Guid.NewGuid().ToString("N");config.Characters[id]=d.Profile;Save();Render();}}
        void Launch(bool all){var items=list.Items.Cast<ProfileItem>().Where((x,i)=>all||list.GetItemChecked(i)).ToList();foreach(var item in items){string exe=File.Exists(Path.Combine(path.Text,"ElementClient.exe"))?Path.Combine(path.Text,"ElementClient.exe"):Path.Combine(path.Text,"elementclient.exe");string login=MultiLauncherStore.Unprotect(item.Profile.LoginProtected),pass=MultiLauncherStore.Unprotect(item.Profile.PasswordProtected);if(!File.Exists(exe)||login==""||pass==""){status.Text="Перевірте папку й акаунт: "+item.Profile.Nick;return;}Process.Start(new ProcessStartInfo(exe,"startbypatcher console:1 user:\""+login+"\" pwd:\""+pass+"\" role:\""+item.Profile.Nick+"\""){WorkingDirectory=path.Text});Thread.Sleep((int)delay.Value*1000);}status.Text="Запущено: "+items.Count;}
        public void OnActivated(){Render();}
    }
    internal sealed class ProfileItem{public string Id;public CharacterProfile Profile;public ProfileItem(string id,CharacterProfile p){Id=id;Profile=p;}public override string ToString(){return Profile.Nick+" · "+Profile.Class;}}
    internal sealed class ProfileDialog:Form
    {
        readonly TextBox nick=new TextBox(),login=new TextBox(),pass=new TextBox();readonly ComboBox cls=new ComboBox();public CharacterProfile Profile;
        public ProfileDialog(){Text="Створити профіль";ClientSize=new Size(420,300);StartPosition=FormStartPosition.CenterParent;BackColor=Theme.Ink;ForeColor=Theme.Text;BackgroundImage=AssetImages.Load("summer","multilauncher.jpg");BackgroundImageLayout=ImageLayout.Stretch;nick.SetBounds(25,25,360,30);cls.SetBounds(25,70,360,30);cls.Items.AddRange(new object[]{"Воїн","Маг","Танк","Друїд","Лучник","Жрець","Асасин","Шаман","Страж","Містик"});cls.SelectedIndex=0;login.SetBounds(25,115,360,30);pass.SetBounds(25,160,360,30);pass.UseSystemPasswordChar=true;var save=Theme.Button("СТВОРИТИ");save.SetBounds(225,215,160,40);save.Click+=delegate{if(nick.Text.Trim()==""||login.Text==""||pass.Text=="")return;Profile=new CharacterProfile{Nick=nick.Text.Trim(),Class=cls.Text,Selected=true,LoginProtected=MultiLauncherStore.Protect(login.Text),PasswordProtected=MultiLauncherStore.Protect(pass.Text)};DialogResult=DialogResult.OK;};Controls.AddRange(new Control[]{nick,cls,login,pass,save});}
    }
}
