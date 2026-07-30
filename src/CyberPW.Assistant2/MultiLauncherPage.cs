using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class MultiLauncherPage : UserControl, IModulePage
    {
        LauncherConfig config;
        readonly TextBox path = new TextBox();
        readonly ListView list = new ListView();
        readonly ImageList profileImages = new ImageList();
        readonly NumericUpDown delay = new NumericUpDown();
        readonly Label status;
        readonly System.Windows.Forms.Timer discoveryTimer = new System.Windows.Forms.Timer();
        readonly Dictionary<string, Image> classImages = new Dictionary<string, Image>(StringComparer.OrdinalIgnoreCase);
        bool discovering;

        public string Title { get { return "MultiLauncher"; } }

        public MultiLauncherPage()
        {
            BackColor = Theme.Ink;
            BackgroundImage = AssetImages.Load("summer", "multilauncher.jpg");
            BackgroundImageLayout = ImageLayout.Stretch;
            config = MultiLauncherStore.Load();

            var h = Theme.Label("MULTILAUNCHER", 24, Theme.GoldSoft, FontStyle.Bold);
            h.Location = new Point(24, 20); Controls.Add(h);
            path.SetBounds(26, 75, 600, 32); path.Text = MultiLauncherStore.ResolveGamePath(config.GamePath); path.ReadOnly = true; Controls.Add(path);
            var browse = Theme.Button("ОБРАТИ ПАПКУ"); browse.SetBounds(645, 70, 170, 42);
            browse.Click += delegate { using (var d = new FolderBrowserDialog()) if (d.ShowDialog() == DialogResult.OK) { string p = MultiLauncherStore.ResolveGamePath(d.SelectedPath); if (p == "") MessageBox.Show("ElementClient.exe не знайдено."); else { path.Text = config.GamePath = p; Save(); } } }; Controls.Add(browse);

            list.SetBounds(26, 130, 790, 380); list.BackColor = Theme.Panel; list.ForeColor = Theme.Text;
            list.View = View.Details; list.CheckBoxes = true; list.FullRowSelect = true; list.HideSelection = false; list.HeaderStyle = ColumnHeaderStyle.None;
            list.Columns.Add("Персонаж", 250); list.Columns.Add("Клас", 150); list.Columns.Add("Стан", 360);
            profileImages.ImageSize = new Size(42, 42); profileImages.ColorDepth = ColorDepth.Depth32Bit; list.SmallImageList = profileImages;
            list.DoubleClick += delegate { EditSelectedProfile(); }; Controls.Add(list);

            var add = Theme.Button("+ ПРОФІЛЬ"); add.SetBounds(26, 530, 140, 42); add.Click += delegate { CreateProfile(); }; Controls.Add(add);
            delay.SetBounds(185, 535, 60, 30); delay.Minimum = 1; delay.Maximum = 30; delay.Value = Math.Max(1, Math.Min(30, config.DelaySeconds)); Controls.Add(delay);
            var selected = Theme.Button("ЗАПУСТИТИ ВИБРАНИХ"); selected.SetBounds(420, 530, 190, 42); selected.Click += delegate { Launch(false); }; Controls.Add(selected);
            var all = Theme.Button("ЗАПУСТИТИ ВСІХ"); all.SetBounds(625, 530, 190, 42); all.Click += delegate { Launch(true); }; Controls.Add(all);
            status = Theme.Label("Очікую вхід персонажа у світ…", 9, Theme.Muted, FontStyle.Regular); status.SetBounds(28, 590, 780, 28); Controls.Add(status);

            discoveryTimer.Interval = 3000; discoveryTimer.Tick += delegate { DiscoverLoggedCharacters(); }; discoveryTimer.Start();
            Disposed += delegate { discoveryTimer.Dispose(); foreach (Image image in classImages.Values) image.Dispose(); };
            Render(); DiscoverLoggedCharacters();
        }

        void Render()
        {
            list.BeginUpdate(); list.Items.Clear();
            foreach (var pair in config.Characters.OrderBy(x => x.Value.Nick))
            {
                var profile = pair.Value; string imageKey = EnsureClassImage(profile.Class);
                var row = new ListViewItem(profile.Nick) { Tag = new ProfileItem(pair.Key, profile), Checked = profile.Selected, ImageKey = imageKey };
                row.SubItems.Add(profile.Class);
                row.SubItems.Add(HasCredentials(profile) ? "готовий до запуску" : "знайдено у грі · подвійний клік для додавання акаунта");
                list.Items.Add(row);
            }
            list.EndUpdate();
        }

        string EnsureClassImage(string className)
        {
            Image image = GetClassImage(className); if (image == null) return "";
            string key = className ?? ""; if (!profileImages.Images.ContainsKey(key)) profileImages.Images.Add(key, image);
            return key;
        }
        Image GetClassImage(string className)
        {
            string file;
            switch (className)
            {
                case "Воїн": file = "warrior.png"; break; case "Маг": file = "mage.png"; break;
                case "Танк": file = "tank.png"; break; case "Друїд": file = "druid.png"; break;
                case "Лучник": file = "archer.png"; break; case "Жрець": file = "cleric.png"; break;
                case "Асасин": file = "assassin.png"; break; case "Шаман": file = "shaman.png"; break;
                case "Страж": file = "seeker.png"; break; case "Містик": file = "mystic.png"; break;
                default: return null;
            }
            Image cached; if (classImages.TryGetValue(file, out cached)) return cached;
            string iconPath = Path.Combine(AppPaths.Root, "class-icons", file); if (!File.Exists(iconPath)) return null;
            using (Image source = Image.FromFile(iconPath)) cached = new Bitmap(source);
            classImages[file] = cached; return cached;
        }

        void DiscoverLoggedCharacters()
        {
            if (discovering) return; discovering = true;
            try
            {
                int found = 0, added = 0; bool changed = false;
                foreach (Process process in TitleMemoryService.FindClients("ElementClient"))
                {
                    try
                    {
                        DetectedCharacter detected = TitleMemoryService.ReadCharacter(process); found++;
                        var existing = config.Characters.FirstOrDefault(x => string.Equals(x.Value.Nick, detected.Nick, StringComparison.OrdinalIgnoreCase));
                        CharacterProfile profile = existing.Value;
                        if (profile == null)
                        {
                            profile = new CharacterProfile { Nick = detected.Nick, Class = detected.ClassName, Selected = false, AutoDetected = true, LastProcessId = detected.ProcessId, LoginProtected = "", PasswordProtected = "" };
                            config.Characters[Guid.NewGuid().ToString("N")] = profile; added++; changed = true;
                        }
                        else
                        {
                            if (detected.ClassName != "Не визначено" && profile.Class != detected.ClassName) { profile.Class = detected.ClassName; changed = true; }
                            if (profile.LastProcessId != detected.ProcessId || !profile.AutoDetected) { profile.LastProcessId = detected.ProcessId; profile.AutoDetected = true; changed = true; }
                        }
                    }
                    catch { }
                }
                if (changed) { Save(); Render(); }
                if (added > 0) status.Text = "Автоматично додано персонажів: " + added + ". Двічі клацніть картку, щоб додати дані входу.";
                else if (found > 0) status.Text = "У грі знайдено персонажів: " + found + ". Профілі синхронізовано.";
                else status.Text = "Увійдіть персонажем у світ — його картка з’явиться автоматично.";
            }
            finally { discovering = false; }
        }

        bool HasCredentials(CharacterProfile profile) { return MultiLauncherStore.Unprotect(profile.LoginProtected) != "" && MultiLauncherStore.Unprotect(profile.PasswordProtected) != ""; }
        void Save() { config.DelaySeconds = (int)delay.Value; MultiLauncherStore.Save(config); }
        void CreateProfile() { using (var d = new ProfileDialog(null)) { if (d.ShowDialog(FindForm()) != DialogResult.OK) return; config.Characters[Guid.NewGuid().ToString("N")] = d.Profile; Save(); Render(); } }
        void EditSelectedProfile() { if (list.SelectedItems.Count == 0) return; var item = (ProfileItem)list.SelectedItems[0].Tag; using (var d = new ProfileDialog(item.Profile)) { if (d.ShowDialog(FindForm()) != DialogResult.OK) return; config.Characters[item.Id] = d.Profile; Save(); Render(); } }

        void Launch(bool all)
        {
            var rows = list.Items.Cast<ListViewItem>().Where(x => all || x.Checked).ToList();
            foreach (ListViewItem row in list.Items) ((ProfileItem)row.Tag).Profile.Selected = row.Checked;
            Save();
            var items = rows.Select(x => (ProfileItem)x.Tag).ToList();
            foreach (var item in items)
            {
                string exe = File.Exists(Path.Combine(path.Text, "ElementClient.exe")) ? Path.Combine(path.Text, "ElementClient.exe") : Path.Combine(path.Text, "elementclient.exe");
                string login = MultiLauncherStore.Unprotect(item.Profile.LoginProtected), pass = MultiLauncherStore.Unprotect(item.Profile.PasswordProtected);
                if (!File.Exists(exe) || login == "" || pass == "") { status.Text = "Відкрийте профіль подвійним кліком і додайте акаунт: " + item.Profile.Nick; return; }
                Process.Start(new ProcessStartInfo(exe, "startbypatcher console:1 user:\"" + login + "\" pwd:\"" + pass + "\" role:\"" + item.Profile.Nick + "\"") { WorkingDirectory = path.Text });
                Thread.Sleep((int)delay.Value * 1000);
            }
            status.Text = "Запущено: " + items.Count;
        }
        public void OnActivated() { Render(); DiscoverLoggedCharacters(); }
    }

    internal sealed class ProfileItem { public string Id; public CharacterProfile Profile; public ProfileItem(string id, CharacterProfile p) { Id = id; Profile = p; } public override string ToString() { return Profile.Nick + " · " + Profile.Class; } }

    internal sealed class ProfileDialog : Form
    {
        readonly TextBox nick = new TextBox(), login = new TextBox(), pass = new TextBox(); readonly ComboBox cls = new ComboBox(); public CharacterProfile Profile; readonly CharacterProfile source;
        public ProfileDialog(CharacterProfile profile)
        {
            source = profile; Text = profile == null ? "Створити профіль" : "Налаштувати профіль"; ClientSize = new Size(420, 410); StartPosition = FormStartPosition.CenterParent; BackColor = Theme.Ink; ForeColor = Theme.Text;
            BackgroundImage = AssetImages.Load("summer", "multilauncher.jpg"); BackgroundImageLayout = ImageLayout.Stretch;
            var nickLabel = Theme.Label("НІК ПЕРСОНАЖА · визначається автоматично", 8, Theme.GoldSoft, FontStyle.Bold); nickLabel.SetBounds(25, 18, 360, 20);
            nick.SetBounds(25, 40, 360, 30);
            var classLabel = Theme.Label("КЛАС ПЕРСОНАЖА", 8, Theme.GoldSoft, FontStyle.Bold); classLabel.SetBounds(25, 78, 360, 20);
            cls.SetBounds(25, 100, 360, 30); cls.DropDownStyle = ComboBoxStyle.DropDownList;
            cls.Items.AddRange(new object[] { "Воїн", "Маг", "Танк", "Друїд", "Лучник", "Жрець", "Асасин", "Шаман", "Страж", "Містик", "Не визначено" });
            var loginLabel = Theme.Label("ЛОГІН АКАУНТА", 8, Theme.GoldSoft, FontStyle.Bold); loginLabel.SetBounds(25, 138, 360, 20);
            login.SetBounds(25, 160, 360, 30);
            var passLabel = Theme.Label("ПАРОЛЬ", 8, Theme.GoldSoft, FontStyle.Bold); passLabel.SetBounds(25, 198, 360, 20);
            pass.SetBounds(25, 220, 360, 30); pass.UseSystemPasswordChar = true;
            var guide = Theme.Label("ЯК КОРИСТУВАТИСЬ: увійдіть персонажем у гру → відкрийте MultiLauncher → двічі клацніть його картку → один раз введіть логін і пароль.", 8, Theme.Text, FontStyle.Regular);
            guide.SetBounds(25, 264, 360, 52); guide.AutoSize = false;
            if (profile != null) { nick.Text = profile.Nick; cls.SelectedItem = profile.Class; login.Text = MultiLauncherStore.Unprotect(profile.LoginProtected); pass.Text = MultiLauncherStore.Unprotect(profile.PasswordProtected); }
            if (cls.SelectedIndex < 0) cls.SelectedIndex = 0;
            var save = Theme.Button("ЗБЕРЕГТИ"); save.SetBounds(225, 335, 160, 44);
            save.Click += delegate { if (nick.Text.Trim() == "" || login.Text == "" || pass.Text == "") { MessageBox.Show("Вкажіть нік, клас, логін і пароль."); return; } Profile = new CharacterProfile { Nick = nick.Text.Trim(), Class = cls.Text, Selected = source == null || source.Selected, AutoDetected = source != null && source.AutoDetected, LastProcessId = source == null ? 0 : source.LastProcessId, LoginProtected = MultiLauncherStore.Protect(login.Text), PasswordProtected = MultiLauncherStore.Protect(pass.Text) }; DialogResult = DialogResult.OK; };
            Controls.AddRange(new Control[] { nickLabel, nick, classLabel, cls, loginLabel, login, passLabel, pass, guide, save });
        }
    }
}