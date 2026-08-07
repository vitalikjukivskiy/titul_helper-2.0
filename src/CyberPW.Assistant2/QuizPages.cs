using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class QuizRecord
    {
        public string level { get; set; }
        public string question { get; set; }
        public string answer { get; set; }
    }

    internal static partial class QuizData
    {
        public static List<QuizRecord> LoadKh() { return Decode(Kh); }
        public static List<QuizRecord> LoadChonPon() { return Decode(ChonPon); }
        static List<QuizRecord> Decode(string payload)
        {
            byte[] packed = Convert.FromBase64String(payload);
            using (var input = new MemoryStream(packed))
            using (var gzip = new GZipStream(input, CompressionMode.Decompress))
            using (var output = new MemoryStream())
            {
                gzip.CopyTo(output);
                string json = Encoding.UTF8.GetString(output.ToArray());
                return new JavaScriptSerializer().Deserialize<List<QuizRecord>>(json) ?? new List<QuizRecord>();
            }
        }
    }

    internal abstract class QuizBasePage : UserControl, IModulePage
    {
        readonly string pageTitle, levelCaption;
        readonly Func<List<QuizRecord>> loader;
        readonly string[] levelLabels, levelKeys;
        readonly TextBox search = new TextBox();
        readonly ComboBox level = new ComboBox();
        readonly ListBox results = new ListBox();
        readonly Label count = new Label();
        readonly TextBox question = new TextBox();
        readonly TextBox answer = new TextBox();
        List<QuizRecord> all = new List<QuizRecord>();
        List<QuizRecord> filtered = new List<QuizRecord>();
        public string Title { get { return pageTitle; } }

        protected QuizBasePage(string title, string subtitle, string caption, string[] labels, string[] keys, Func<List<QuizRecord>> dataLoader)
        {
            pageTitle=title; loader=dataLoader; levelLabels=labels; levelKeys=keys; levelCaption=caption;
            BackColor=Theme.Ink; ForeColor=Theme.Text; Font=new Font("Segoe UI",9);
            var titleLabel=Theme.Label(title,22,Theme.GoldSoft,FontStyle.Bold); titleLabel.SetBounds(24,14,620,40); Controls.Add(titleLabel);
            var subtitleLabel=Theme.Label(subtitle,9,Theme.Muted,FontStyle.Regular); subtitleLabel.SetBounds(26,52,720,24); Controls.Add(subtitleLabel);
            var searchLabel=Theme.Label("ПОШУК ЗА ПИТАННЯМ АБО ВІДПОВІДДЮ",8,Theme.GoldSoft,FontStyle.Bold); searchLabel.SetBounds(24,88,320,20); Controls.Add(searchLabel);
            search.SetBounds(24,110,520,32); search.Font=new Font("Segoe UI",11); search.BackColor=Color.FromArgb(21,35,32); search.ForeColor=Color.White; search.BorderStyle=BorderStyle.FixedSingle; search.TextChanged+=delegate{ApplyFilter();}; Controls.Add(search);
            level.DropDownStyle=ComboBoxStyle.DropDownList; level.SetBounds(562,110,190,32); level.BackColor=Color.FromArgb(21,35,32); level.ForeColor=Color.White; level.Items.Add("Усі рівні"); for(int i=0;i<levelLabels.Length;i++)level.Items.Add(levelLabels[i]); level.SelectedIndex=0; level.SelectedIndexChanged+=delegate{ApplyFilter();}; Controls.Add(level);
            count.SetBounds(770,112,220,28); count.ForeColor=Theme.Cyan; count.Font=new Font("Segoe UI",9,FontStyle.Bold); count.TextAlign=ContentAlignment.MiddleRight; Controls.Add(count);
            results.SetBounds(24,158,470,458); results.BackColor=Color.FromArgb(14,27,25); results.ForeColor=Theme.Text; results.BorderStyle=BorderStyle.FixedSingle; results.Font=new Font("Segoe UI",9); results.SelectedIndexChanged+=delegate{ShowSelected();}; Controls.Add(results);
            var qLabel=Theme.Label("ПИТАННЯ",9,Theme.GoldSoft,FontStyle.Bold); qLabel.SetBounds(516,158,180,22); Controls.Add(qLabel);
            question.SetBounds(516,184,486,214); question.Multiline=true; question.ReadOnly=true; question.ScrollBars=ScrollBars.Vertical; question.BackColor=Color.FromArgb(14,27,25); question.ForeColor=Color.White; question.BorderStyle=BorderStyle.FixedSingle; question.Font=new Font("Segoe UI",10); Controls.Add(question);
            var aLabel=Theme.Label("ПРАВИЛЬНА ВІДПОВІДЬ",9,Theme.Cyan,FontStyle.Bold); aLabel.SetBounds(516,416,260,22); Controls.Add(aLabel);
            answer.SetBounds(516,442,486,174); answer.Multiline=true; answer.ReadOnly=true; answer.ScrollBars=ScrollBars.Vertical; answer.BackColor=Color.FromArgb(8,48,42); answer.ForeColor=Color.FromArgb(160,245,210); answer.BorderStyle=BorderStyle.FixedSingle; answer.Font=new Font("Segoe UI",13,FontStyle.Bold); Controls.Add(answer);
            LoadData();
        }
        void LoadData(){try{all=loader()??new List<QuizRecord>();}catch(Exception e){MessageBox.Show("Не вдалося завантажити базу вікторини.\r\n\r\n"+e.Message,"CyberPW Assistant",MessageBoxButtons.OK,MessageBoxIcon.Warning);all=new List<QuizRecord>();}ApplyFilter();}
        string LevelKey(){int idx=level.SelectedIndex-1;return idx<0||idx>=levelKeys.Length?"":levelKeys[idx];}
        void ApplyFilter(){string needle=(search.Text??"").Trim(),lvl=LevelKey();filtered=all.Where(x=>(lvl.Length==0||x.level==lvl)&&(needle.Length==0||(x.question??"").IndexOf(needle,StringComparison.CurrentCultureIgnoreCase)>=0||(x.answer??"").IndexOf(needle,StringComparison.CurrentCultureIgnoreCase)>=0)).ToList();results.BeginUpdate();results.Items.Clear();foreach(QuizRecord item in filtered)results.Items.Add("["+(item.level??"").Replace("-","–")+"] "+item.question);results.EndUpdate();count.Text="Знайдено: "+filtered.Count+" / "+all.Count;if(results.Items.Count>0)results.SelectedIndex=0;else{question.Text="";answer.Text="";}}
        void ShowSelected(){int i=results.SelectedIndex;if(i<0||i>=filtered.Count)return;QuizRecord item=filtered[i];question.Text=levelCaption+": "+(item.level??"").Replace("-","–")+"\r\n\r\n"+item.question;answer.Text=item.answer;}
        public void OnActivated(){if(all.Count==0)LoadData();search.Focus();}
    }
    internal sealed class GuildQuizPage:QuizBasePage{public GuildQuizPage():base("ВІКТОРИНА КХ","79 питань · Зал єднання · українська база · працює офлайн","Рівень Залу єднання",new[]{"1–2 рівень","3 рівень","4 рівень","5 рівень","6 рівень","7 рівень","8 рівень"},new[]{"1-2","3","4","5","6","7","8"},QuizData.LoadKh){}}
    internal sealed class ChonPonQuizPage:QuizBasePage{public ChonPonQuizPage():base("ВІКТОРИНА ЧОН-ПОН","200 питань · рівні 60–105 · українська база · працює офлайн","Рівень персонажа",new[]{"60–69","70–79","80–89","90–105"},new[]{"60-69","70-79","80-89","90-105"},QuizData.LoadChonPon){}}
}
