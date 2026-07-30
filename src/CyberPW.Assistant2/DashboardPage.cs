using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class DashboardPage : UserControl, IModulePage
    {
        sealed class EventRow { public string Time, Name; public EventRow(string t, string n) { Time = t; Name = n; } }
        readonly Action<string> nav;
        readonly Label progress, calendarDay, calendarNext, calendarEvents, charactersSummary;
        readonly Button[] dayButtons = new Button[7];
        readonly FlowLayoutPanel charactersPanel = new FlowLayoutPanel();
        readonly Timer characterTimer = new Timer();
        readonly Dictionary<string, Image> classImages = new Dictionary<string, Image>(StringComparer.OrdinalIgnoreCase);
        string clientSignature = "";
        int loginRefreshCountdown;
        int selectedDay;
        readonly List<EventRow>[] schedule = BuildSchedule();
        public string Title { get { return "Головна"; } }

        public DashboardPage(Action<string> navigate)
        {
            nav = navigate; BackColor = Theme.Ink; BackgroundImage = AssetImages.Load("main-summer.jpg"); BackgroundImageLayout = ImageLayout.Stretch;
            var hero = new CardPanel { BackColor = Color.FromArgb(0, 54, 45), BorderThickness = 2 }; hero.SetBounds(18, 18, 590, 250); Controls.Add(hero);
            var title = Theme.Label("CyberPW Assistant", 27, Theme.GoldSoft, FontStyle.Bold); title.Location = new Point(28, 25); hero.Controls.Add(title);
            var sub = Theme.Label("ІНСТРУМЕНТИ ТА ПОМІЧНИКИ ДЛЯ PERFECT WORLD", 10, Theme.Text, FontStyle.Bold); sub.Location = new Point(30, 78); hero.Controls.Add(sub);
            var text = Theme.Label("Ваші персонажі тепер прямо на головній:\nзапуск, клас, статус клієнта та швидкий доступ\nдо профілів MultiLauncher.", 11, Theme.Muted, FontStyle.Regular); text.Location = new Point(30, 116); hero.Controls.Add(text);
            progress = Theme.Label("TITULHELPER: 0 / 260    ● ГОТОВО    VERSION 2.0 BETA", 9, Theme.Cyan, FontStyle.Bold); progress.Location = new Point(30, 205); hero.Controls.Add(progress);

            var calendar = new CardPanel { BackColor = Color.FromArgb(0, 48, 40), BorderThickness = 3 }; calendar.SetBounds(625, 18, 385, 250); Controls.Add(calendar);
            var ch = Theme.Label("КАЛЕНДАР ІВЕНТІВ", 12, Theme.GoldSoft, FontStyle.Bold); ch.Location = new Point(18, 14); calendar.Controls.Add(ch);
            calendarDay = Theme.Label("", 9, Theme.Muted, FontStyle.Bold); calendarDay.AutoSize = false; calendarDay.TextAlign = ContentAlignment.MiddleRight; calendarDay.SetBounds(270, 14, 95, 24); calendar.Controls.Add(calendarDay);
            calendarNext = Theme.Label("", 8.5f, Theme.Cyan, FontStyle.Bold); calendarNext.SetBounds(18, 47, 347, 28); calendarNext.AutoSize = false; calendar.Controls.Add(calendarNext);
            string[] days = { "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "НД" };
            for (int i = 0; i < 7; i++) { int index = i; var b = Theme.Button(days[i]); b.SetBounds(18 + i * 50, 82, 42, 34); b.Click += (s, e) => SelectDay(index); dayButtons[i] = b; calendar.Controls.Add(b); }
            calendarEvents = Theme.Label("", 8.5f, Theme.Text, FontStyle.Regular); calendarEvents.SetBounds(20, 127, 345, 108); calendarEvents.AutoSize = false; calendar.Controls.Add(calendarEvents);

            var rosterTitle = Theme.Label("МОЇ ПЕРСОНАЖІ", 13, Theme.GoldSoft, FontStyle.Bold); rosterTitle.Location = new Point(22, 289); Controls.Add(rosterTitle);
            charactersSummary = Theme.Label("", 9, Theme.Cyan, FontStyle.Bold); charactersSummary.SetBounds(190, 292, 470, 24); charactersSummary.AutoSize = false; Controls.Add(charactersSummary);
            var manage = Theme.Button("⚙ MULTILAUNCHER"); manage.SetBounds(825, 282, 185, 38); manage.Click += (s, e) => nav("MULTILAUNCHER"); Controls.Add(manage);
            charactersPanel.SetBounds(18, 328, 992, 270); charactersPanel.BackColor = Color.Transparent; charactersPanel.AutoScroll = true; charactersPanel.WrapContents = true; charactersPanel.Padding = new Padding(0, 0, 0, 8); Controls.Add(charactersPanel);

            selectedDay = DayIndex(DateTime.Now.DayOfWeek); SelectDay(selectedDay); UpdateProgress(); RefreshCharacters();
            clientSignature = CurrentClientSignature();
            characterTimer.Interval = 1000;
            characterTimer.Tick += (s, e) =>
            {
                string current = CurrentClientSignature();
                if (!string.Equals(current, clientSignature, StringComparison.Ordinal))
                {
                    clientSignature = current;
                    loginRefreshCountdown = string.IsNullOrEmpty(current) ? 0 : 3;
                    RefreshCharacters();
                }
                else if (loginRefreshCountdown > 0 && --loginRefreshCountdown == 0)
                {
                    // Одноразово підхоплюємо профіль після повного входу персонажа у світ.
                    RefreshCharacters();
                }
            };
            characterTimer.Start();
            Disposed += (s, e) => { characterTimer.Dispose(); foreach (Image image in classImages.Values) image.Dispose(); };
        }

        void RefreshCharacters()
        {
            LauncherConfig config = MultiLauncherStore.Load();
            var profiles = config.Characters.OrderBy(x => x.Value.Nick).ToList();
            foreach (var pair in profiles)
            {
                CharacterProfile profile = pair.Value;
                if (!IsOnline(profile)) continue;
                try
                {
                    DetectedCharacter live = TitleMemoryService.ReadCharacter(Process.GetProcessById(profile.LastProcessId));
                    profile.Level = live.Level; profile.Experience = live.Experience; profile.ExperienceRequired = live.ExperienceRequired; profile.Health = live.Health; profile.Mana = live.Mana; profile.MaxHealth = live.MaxHealth; profile.MaxMana = live.MaxMana;
                }
                catch { }
            }
            int online = profiles.Count(x => IsOnline(x.Value));
            charactersSummary.Text = profiles.Count == 0 ? "Увійдіть персонажем у гру — картка зʼявиться автоматично" : profiles.Count + " персонажів    ● У ГРІ: " + online;
            charactersPanel.SuspendLayout(); charactersPanel.Controls.Clear();
            if (profiles.Count == 0) charactersPanel.Controls.Add(BuildEmptyCard());
            else foreach (var pair in profiles) charactersPanel.Controls.Add(BuildCharacterCard(pair.Value, config));
            charactersPanel.ResumeLayout();
        }

        Control BuildEmptyCard()
        {
            var card = new CardPanel { Size = new Size(965, 155), BackColor = Color.FromArgb(215, 0, 46, 39), BorderThickness = 2, Margin = new Padding(3, 3, 3, 10) };
            var title = Theme.Label("ПЕРСОНАЖІ ЩЕ НЕ ЗНАЙДЕНІ", 14, Theme.GoldSoft, FontStyle.Bold); title.Location = new Point(28, 28); card.Controls.Add(title);
            var text = Theme.Label("Запустіть CyberPW, увійдіть персонажем у світ і поверніться сюди.\nAssistant автоматично визначить нік та клас.", 10, Theme.Text, FontStyle.Regular); text.Location = new Point(30, 65); card.Controls.Add(text);
            var open = Theme.Button("ВІДКРИТИ MULTILAUNCHER"); open.SetBounds(700, 52, 230, 48); open.Click += (s, e) => nav("MULTILAUNCHER"); card.Controls.Add(open); return card;
        }

        Control BuildCharacterCard(CharacterProfile profile, LauncherConfig config)
        {
            bool online = IsOnline(profile), ready = HasCredentials(profile);
            var card = new CardPanel { Size = new Size(317, 188), BackColor = Color.FromArgb(225, 0, 48, 40), BorderThickness = online ? 3 : 2, Margin = new Padding(3, 3, 8, 10), BackgroundImage = AssetImages.Load("summer", "multilauncher.jpg"), BackgroundImageLayout = ImageLayout.Stretch };
            var shade = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(178, 0, 35, 30) }; card.Controls.Add(shade);
            Image icon = GetClassImage(profile.Class); if (icon != null) { var portrait = new PictureBox { Image = icon, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.FromArgb(175, 0, 28, 25) }; portrait.SetBounds(14, 15, 66, 66); shade.Controls.Add(portrait); }
            var nick = Theme.Label(profile.Nick, 12, Theme.GoldSoft, FontStyle.Bold); nick.SetBounds(92, 13, 205, 25); nick.AutoSize = false; shade.Controls.Add(nick);
            var cls = Theme.Label(profile.Class.ToUpperInvariant() + (profile.Level > 0 ? "  ·  РІВЕНЬ " + profile.Level : ""), 8.5f, Theme.Text, FontStyle.Bold); cls.SetBounds(92, 40, 165, 20); cls.AutoSize = false; shade.Controls.Add(cls);
            var state = Theme.Label(online ? "● У ГРІ" : "● OFFLINE", 8, online ? Theme.Cyan : Theme.Muted, FontStyle.Bold); state.SetBounds(215, 40, 82, 20); state.AutoSize = false; state.TextAlign = ContentAlignment.MiddleRight; shade.Controls.Add(state);
            int hpPercent = profile.MaxHealth > 0 ? Math.Max(0, Math.Min(100, profile.Health * 100 / profile.MaxHealth)) : 0;
            int mpPercent = profile.MaxMana > 0 ? Math.Max(0, Math.Min(100, profile.Mana * 100 / profile.MaxMana)) : 0;
            AddStatBar(shade, "HP", 92, 67, Color.FromArgb(193, 45, 55), hpPercent, profile.MaxHealth > 0 ? FormatNumber(profile.Health) + " / " + FormatNumber(profile.MaxHealth) : "—");
            AddStatBar(shade, "MP", 92, 89, Color.FromArgb(45, 112, 205), mpPercent, profile.MaxMana > 0 ? FormatNumber(profile.Mana) + " / " + FormatNumber(profile.MaxMana) : "—");
            int expPercent = profile.ExperienceRequired > 0 ? (int)Math.Max(0, Math.Min(100, profile.Experience * 100L / profile.ExperienceRequired)) : 0;
            AddStatBar(shade, "EXP", 14, 116, Color.FromArgb(212, 153, 28), expPercent, null);
            var expText = Theme.Label(profile.ExperienceRequired > 0 ? FormatNumber(profile.Experience) + " / " + FormatNumber(profile.ExperienceRequired) + "  ·  " + expPercent + "%" : (profile.Experience > 0 ? FormatNumber(profile.Experience) + " EXP" : "EXP синхронізується у грі"), 7.5f, Theme.Text, FontStyle.Bold);
            expText.SetBounds(43, 133, 254, 18); expText.AutoSize = false; expText.TextAlign = ContentAlignment.MiddleRight; shade.Controls.Add(expText);
            var launch = Theme.Button(ready ? (online ? "ЗАПУСТИТИ ЩЕ ВІКНО" : "ЗАПУСТИТИ") : "НАЛАШТУВАТИ"); launch.SetBounds(14, 151, 237, 30);
            launch.Click += (s, e) => { if (!ready) nav("MULTILAUNCHER"); else LaunchProfile(profile, config); }; shade.Controls.Add(launch);
            var edit = Theme.Button("⚙"); edit.SetBounds(260, 151, 42, 30); edit.Click += (s, e) => nav("MULTILAUNCHER"); shade.Controls.Add(edit);
            return card;
        }

        void AddStatBar(Control parent, string name, int x, int y, Color color, int percent, string valueText)
        {
            var label = Theme.Label(name, 7.5f, Theme.GoldSoft, FontStyle.Bold); label.SetBounds(x, y - 1, 24, 18); label.AutoSize = false; parent.Controls.Add(label);
            var frame = new Panel { BackColor = Color.FromArgb(215, 183, 147, 45) }; frame.SetBounds(x + 25, y, 180, 15); parent.Controls.Add(frame);
            var back = new Panel { BackColor = Color.FromArgb(210, 12, 20, 20) }; back.SetBounds(2, 2, 176, 11); frame.Controls.Add(back);
            var fill = new Panel { BackColor = color }; fill.SetBounds(0, 0, percent <= 0 ? 0 : Math.Max(4, 176 * percent / 100), 11); back.Controls.Add(fill);
            if (!string.IsNullOrWhiteSpace(valueText))
            {
                var value = Theme.Label(valueText, 6.7f, Color.White, FontStyle.Bold); value.Dock = DockStyle.Fill; value.AutoSize = false; value.TextAlign = ContentAlignment.MiddleCenter; value.BackColor = Color.Transparent; back.Controls.Add(value); value.BringToFront();
            }
        }

        static string FormatNumber(long value) { return value.ToString("N0").Replace(",", " "); }

        void LaunchProfile(CharacterProfile profile, LauncherConfig config)
        {
            string game = MultiLauncherStore.ResolveGamePath(config.GamePath); string exe = Path.Combine(game, "ElementClient.exe"); if (!File.Exists(exe)) exe = Path.Combine(game, "elementclient.exe");
            string login = MultiLauncherStore.Unprotect(profile.LoginProtected), password = MultiLauncherStore.Unprotect(profile.PasswordProtected);
            if (!File.Exists(exe) || login == "" || password == "") { MessageBox.Show("Відкрийте MultiLauncher і перевірте папку гри, логін та пароль.", "MultiLauncher", MessageBoxButtons.OK, MessageBoxIcon.Information); nav("MULTILAUNCHER"); return; }
            Process.Start(new ProcessStartInfo(exe, "startbypatcher console:1 user:\"" + login + "\" pwd:\"" + password + "\" role:\"" + profile.Nick + "\"") { WorkingDirectory = game });
        }

        bool HasCredentials(CharacterProfile p) { return MultiLauncherStore.Unprotect(p.LoginProtected) != "" && MultiLauncherStore.Unprotect(p.PasswordProtected) != ""; }
        string CurrentClientSignature()
        {
            try { return string.Join(",", TitleMemoryService.FindClients("ElementClient").Select(x => x.Id.ToString()).ToArray()); }
            catch { return ""; }
        }
        bool IsOnline(CharacterProfile p) { if (p.LastProcessId <= 0) return false; try { var process = Process.GetProcessById(p.LastProcessId); return !process.HasExited && string.Equals(process.ProcessName, "ElementClient", StringComparison.OrdinalIgnoreCase); } catch { return false; } }
        Image GetClassImage(string className)
        {
            string file; switch (className) { case "Воїн": file = "warrior.png"; break; case "Маг": file = "mage.png"; break; case "Танк": file = "tank.png"; break; case "Друїд": file = "druid.png"; break; case "Лучник": file = "archer.png"; break; case "Жрець": file = "cleric.png"; break; case "Асасин": file = "assassin.png"; break; case "Шаман": file = "shaman.png"; break; case "Страж": file = "seeker.png"; break; case "Містик": file = "mystic.png"; break; default: return null; }
            Image image; if (classImages.TryGetValue(file, out image)) return image; string path = Path.Combine(AppPaths.Root, "class-icons", file); if (!File.Exists(path)) return null; using (Image source = Image.FromFile(path)) image = new Bitmap(source); classImages[file] = image; return image;
        }

        void SelectDay(int index) { selectedDay = index; for (int i = 0; i < dayButtons.Length; i++) { dayButtons[i].BackColor = i == index ? Color.FromArgb(185, 137, 10) : Theme.Panel2; dayButtons[i].ForeColor = i == index ? Color.White : Theme.GoldSoft; } calendarDay.Text = DayName(index); var rows = schedule[index]; calendarEvents.Text = string.Join("\n", rows.Select(x => x.Time.PadRight(15) + x.Name).ToArray()); string next = NextText(index, rows); calendarNext.Text = next == null ? "НАСТУПНЕ: подій більше немає" : "НАСТУПНЕ: " + next; }
        string NextText(int index, List<EventRow> rows) { if (rows.Count == 0) return null; bool today = index == DayIndex(DateTime.Now.DayOfWeek); TimeSpan now = DateTime.Now.TimeOfDay; foreach (var row in rows) foreach (string token in row.Time.Split('·')) { string value = token.Trim(); int dash = value.IndexOf('–'); if (dash > 0) value = value.Substring(0, dash); TimeSpan time; if (TimeSpan.TryParse(value.Replace('.', ':'), out time) && (!today || time >= now)) return value + " · " + row.Name; } return null; }
        void UpdateProgress() { try { int total = JsonFiles.Read<List<TitleRecord>>(AppPaths.Titles).Count, done = 0; if (File.Exists(AppPaths.State)) { var s = JsonFiles.Read<TitleState>(AppPaths.State); if (s != null && s.done != null) done = s.done.Count(x => x.Value); } progress.Text = "TITULHELPER: " + done + " / " + total + "    ● ГОТОВО    VERSION 2.0 BETA"; } catch { } }
        static int DayIndex(DayOfWeek d) { return d == DayOfWeek.Sunday ? 6 : (int)d - 1; }
        static string DayName(int i) { return new[] { "Понеділок", "Вівторок", "Середа", "Четвер", "Пʼятниця", "Субота", "Неділя" }[i]; }
        static List<EventRow>[] BuildSchedule() { var s = new List<EventRow>[7]; for (int i = 0; i < 7; i++) s[i] = new List<EventRow>(); Add(s, 0, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 0, "19:00–19:30", "Плато Асурів"); Add(s, 0, "21:00", "Атака тигрів небожителів"); Add(s, 1, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 1, "19:00–19:30", "Плато Асурів"); Add(s, 1, "20:00", "Світові боси · Хроно боси"); Add(s, 1, "20:40", "Інгримунд"); Add(s, 2, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 2, "19:00", "Початок ставок"); Add(s, 2, "21:00", "Місто Темних звірів"); Add(s, 3, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 3, "19:00", "Закінчення ставок"); Add(s, 3, "20:00", "Конкурс ремісників · боси"); Add(s, 3, "21:40", "Ейнгард"); Add(s, 4, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 4, "19:00–19:30", "Плато Асурів"); Add(s, 4, "20:20–21:20", "Битва Династій"); Add(s, 5, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 5, "19:00–21:18", "Територіальні війни"); Add(s, 5, "19:00–22:00", "Битва Орденів"); Add(s, 6, "12:20 · 21:20", "Скачки на острові змій"); Add(s, 6, "18:00–19:18", "Територіальні війни"); Add(s, 6, "20:20–21:20", "Битва Династій"); Add(s, 6, "21:30", "Замок Царя Драконів"); return s; }
        static void Add(List<EventRow>[] s, int d, string t, string n) { s[d].Add(new EventRow(t, n)); }
        public void OnActivated() { UpdateProgress(); SelectDay(selectedDay); RefreshCharacters(); }
    }
}