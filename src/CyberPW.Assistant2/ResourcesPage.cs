using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class ResourceDatabase
    {
        public int pointCount;
        public List<ResourceGroup> groups = new List<ResourceGroup>();
    }

    internal sealed class ResourceGroup
    {
        public int id;
        public int tier;
        public string kind;
        public string name;
        public List<ResourcePoint> points = new List<ResourcePoint>();
        public override string ToString() { return "T" + tier + " · " + name; }
    }

    internal sealed class ResourcePoint
    {
        public int x;
        public int z;
        public int h;
    }

    internal sealed class ResourceSelection
    {
        public ResourceGroup Group;
        public ResourcePoint Point;
    }

    internal sealed class ResourcesPage : UserControl, IModulePage
    {
        readonly ResourceMapCanvas map = new ResourceMapCanvas();
        readonly ComboBox games = new ComboBox();
        readonly ComboBox category = new ComboBox();
        readonly ComboBox tier = new ComboBox();
        readonly ComboBox resource = new ComboBox();
        readonly TextBox search = new TextBox();
        readonly CheckBox opened = new CheckBox();
        readonly Label coordinates, status, windowCount, found;
        readonly ResourceDatabase database;
        int selectedX = -1, selectedY = -1;
        public string Title { get { return "Реси"; } }

        public ResourcesPage()
        {
            BackColor = Theme.Ink;
            database = LoadDatabase();

            var heading = Theme.Label("КАРТА РЕСУРСІВ · BETA", 22, Theme.GoldSoft, FontStyle.Bold);
            heading.SetBounds(24, 8, 350, 34); Controls.Add(heading);
            var subtitle = Theme.Label("4 538 точок · ресурси й трави · працює без інтернету", 9, Theme.Muted, FontStyle.Regular);
            subtitle.SetBounds(26, 42, 510, 23); Controls.Add(subtitle);

            category.SetBounds(24, 70, 128, 28); SetupCombo(category);
            category.Items.AddRange(new object[] { "Усі категорії", "Ресурси", "Трави" }); category.SelectedIndex = 0;
            Controls.Add(category);
            tier.SetBounds(158, 70, 112, 28); SetupCombo(tier);
            tier.Items.AddRange(new object[] { "Усі рівні", "T1", "T2", "T3", "T4" }); tier.SelectedIndex = 0;
            Controls.Add(tier);
            search.SetBounds(276, 70, 176, 28); search.BackColor = Theme.Panel; search.ForeColor = Theme.Text;
            search.BorderStyle = BorderStyle.FixedSingle; Controls.Add(search);
            resource.SetBounds(458, 70, 216, 28); SetupCombo(resource); Controls.Add(resource);

            map.SetBounds(24, 106, 650, 516);
            map.CoordinatePicked += delegate(int x, int y) { SelectCoordinates(x, y, "ТОЧКУ ВИБРАНО НА КАРТІ", null); };
            map.ResourcePicked += delegate(ResourceSelection value)
            {
                SelectCoordinates(value.Point.x, value.Point.z,
                    "СКОПІЙОВАНО: " + value.Point.x + " " + value.Point.z + " · " + value.Group.name,
                    value.Group);
                try { Clipboard.SetText(value.Point.x + " " + value.Point.z); }
                catch { SetStatus("Точку вибрано, але буфер обміну зайнятий іншою програмою", Theme.GoldSoft); }
            };
            map.AutoInputRequested += delegate
            {
                if (selectedX < 0 || selectedY < 0) return;
                Inject();
            };
            Controls.Add(map);

            var side = new CardPanel { BackColor = Color.FromArgb(225, 4, 54, 46) };
            side.SetBounds(692, 70, 314, 552); Controls.Add(side);
            found = Theme.Label("Завантаження бази…", 9, Theme.Cyan, FontStyle.Bold);
            found.SetBounds(18, 12, 278, 22); side.Controls.Add(found);
            var gameLabel = Theme.Label("ВІКНО ГРИ", 9, Theme.GoldSoft, FontStyle.Bold);
            gameLabel.SetBounds(18, 40, 180, 22); side.Controls.Add(gameLabel);
            games.SetBounds(18, 64, 205, 30); SetupCombo(games); side.Controls.Add(games);
            var refresh = Theme.Button("↻"); refresh.SetBounds(232, 61, 62, 36); refresh.Click += delegate { RefreshGames(); }; side.Controls.Add(refresh);
            windowCount = Theme.Label("Вікон: 0", 8, Theme.Cyan, FontStyle.Bold);
            windowCount.SetBounds(19, 98, 250, 20); side.Controls.Add(windowCount);

            coordinates = Theme.Label("Координати: —", 15, Theme.GoldSoft, FontStyle.Bold);
            coordinates.SetBounds(18, 124, 278, 32); side.Controls.Add(coordinates);
            var hint = Theme.Label("Колесо миші — масштаб. Затисніть і тягніть карту. Натисніть маркер, щоб вибрати точну точку.", 9, Theme.Text, FontStyle.Regular);
            hint.SetBounds(18, 158, 276, 58); hint.AutoSize = false; side.Controls.Add(hint);
            var resetMap = Theme.Button("ПОКАЗАТИ ВСЮ КАРТУ"); resetMap.SetBounds(18, 220, 276, 38);
            resetMap.Click += delegate { map.ResetView(); }; side.Controls.Add(resetMap);
            var paste = Theme.Button("ВСТАВИТИ КООРДИНАТИ"); paste.SetBounds(18, 266, 276, 38);
            paste.Click += delegate { PasteCoordinates(); }; side.Controls.Add(paste);

            opened.Text = "Панель координат уже відкрита"; opened.SetBounds(18, 315, 276, 28);
            opened.ForeColor = Theme.Text; opened.BackColor = Color.Transparent; side.Controls.Add(opened);
            var openPanel = Theme.Button("ВІДКРИТИ ПАНЕЛЬ"); openPanel.SetBounds(18, 348, 276, 38);
            openPanel.Click += delegate { OpenCoordinatePanel(); }; side.Controls.Add(openPanel);
            var inject = Theme.Button("ПОСТАВИТИ МІТКУ"); inject.SetBounds(18, 394, 276, 48);
            inject.Click += delegate { Inject(); }; side.Controls.Add(inject);
            var openSite = Theme.Button("ДЖЕРЕЛО: WORLDMAP.PW"); openSite.SetBounds(18, 450, 276, 36);
            openSite.Click += delegate { OpenSite(); }; side.Controls.Add(openSite);
            status = Theme.Label("Калібрування береться з TitulHelper", 8, Theme.Cyan, FontStyle.Bold);
            status.SetBounds(18, 494, 278, 45); status.AutoSize = false; side.Controls.Add(status);

            category.SelectedIndexChanged += delegate { ApplyFilters(true); };
            tier.SelectedIndexChanged += delegate { ApplyFilters(true); };
            search.TextChanged += delegate { ApplyFilters(true); };
            resource.SelectedIndexChanged += delegate { ApplyFilters(false); };
            ApplyFilters(true);
            RefreshGames();
        }

        static void SetupCombo(ComboBox combo)
        {
            combo.DropDownStyle = ComboBoxStyle.DropDownList;
            combo.BackColor = Theme.Panel; combo.ForeColor = Theme.Text;
        }

        static ResourceDatabase LoadDatabase()
        {
            try
            {
                string path = Path.Combine(AppPaths.Assets, "resource-points.json");
                if (!File.Exists(path)) return new ResourceDatabase();
                var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 100 };
                return serializer.Deserialize<ResourceDatabase>(File.ReadAllText(path)) ?? new ResourceDatabase();
            }
            catch { return new ResourceDatabase(); }
        }

        IEnumerable<ResourceGroup> BaseFilter()
        {
            IEnumerable<ResourceGroup> groups = database.groups ?? new List<ResourceGroup>();
            if (category.SelectedIndex == 1) groups = groups.Where(x => x.kind == "resource");
            if (category.SelectedIndex == 2) groups = groups.Where(x => x.kind == "herb");
            if (tier.SelectedIndex > 0) groups = groups.Where(x => x.tier == tier.SelectedIndex);
            string query = search.Text.Trim();
            if (query.Length > 0) groups = groups.Where(x => (x.name ?? "").IndexOf(query, StringComparison.CurrentCultureIgnoreCase) >= 0);
            return groups.OrderBy(x => x.tier).ThenBy(x => x.name);
        }

        void ApplyFilters(bool rebuildNames)
        {
            if (rebuildNames)
            {
                int previousId = resource.SelectedItem is ResourceGroup ? ((ResourceGroup)resource.SelectedItem).id : 0;
                resource.SelectedIndexChanged -= ResourceChanged;
                resource.Items.Clear(); resource.Items.Add("Усі види");
                foreach (ResourceGroup group in BaseFilter()) resource.Items.Add(group);
                resource.SelectedIndex = 0;
                for (int i = 1; i < resource.Items.Count; i++) if (((ResourceGroup)resource.Items[i]).id == previousId) resource.SelectedIndex = i;
                resource.SelectedIndexChanged += ResourceChanged;
            }
            List<ResourceGroup> visible = BaseFilter().ToList();
            ResourceGroup selected = resource.SelectedItem as ResourceGroup;
            if (selected != null) visible = visible.Where(x => x.id == selected.id).ToList();
            map.Groups = visible;
            int points = visible.Sum(x => x.points == null ? 0 : x.points.Count);
            found.Text = visible.Count + " видів · " + points.ToString("N0") + " точок";
        }

        void ResourceChanged(object sender, EventArgs e) { ApplyFilters(false); }

        void SelectCoordinates(int x, int y, string message, ResourceGroup group)
        {
            selectedX = Math.Max(0, Math.Min(800, x)); selectedY = Math.Max(0, Math.Min(1000, y));
            coordinates.Text = "Координати: " + selectedX + " " + selectedY;
            map.SelectedCoordinates = new Point(selectedX, selectedY); map.Invalidate();
            SetStatus(message, group == null ? Theme.Cyan : Theme.GoldSoft);
        }

        void PasteCoordinates()
        {
            try
            {
                string value = Clipboard.ContainsText() ? Clipboard.GetText().Trim() : "";
                MatchCollection numbers = Regex.Matches(value, @"-?\d+");
                if (numbers.Count < 2) throw new InvalidOperationException("У буфері не знайдено дві координати.");
                int x = int.Parse(numbers[0].Value), y = int.Parse(numbers[1].Value);
                if (x < 0 || x > 800 || y < 0 || y > 1000) throw new InvalidOperationException("Координати поза межами карти: X 0–800, Y 0–1000.");
                SelectCoordinates(x, y, "КООРДИНАТИ ВСТАВЛЕНО", null);
            }
            catch (Exception e) { MessageBox.Show(e.Message, "Карта ресурсів"); }
        }

        void OpenSite()
        {
            try { Process.Start(new ProcessStartInfo("https://worldmap.pw/index.html") { UseShellExecute = true }); }
            catch (Exception e) { MessageBox.Show("Не вдалося відкрити worldmap.pw.\n" + e.Message, "Карта ресурсів"); }
        }

        void RefreshGames()
        {
            int old = games.SelectedItem is GameItem ? ((GameItem)games.SelectedItem).Id : 0;
            games.Items.Clear();
            foreach (Process process in Process.GetProcessesByName("ElementClient").Where(x => x.MainWindowHandle != IntPtr.Zero).OrderBy(x => x.Id)) games.Items.Add(new GameItem(process));
            for (int i = 0; i < games.Items.Count; i++) if (((GameItem)games.Items[i]).Id == old) games.SelectedIndex = i;
            if (games.SelectedIndex < 0 && games.Items.Count > 0) games.SelectedIndex = 0;
            windowCount.Text = "Вікон: " + games.Items.Count;
        }

        Process Game()
        {
            var item = games.SelectedItem as GameItem;
            if (item == null) return null;
            try { return Process.GetProcessById(item.Id); } catch { return null; }
        }
        Dictionary<string, object> Config()
        {
            string path = Path.Combine(AppPaths.Data, "state.json");
            if (!File.Exists(path)) return new Dictionary<string, object>();
            TitleState state = JsonFiles.Read<TitleState>(path);
            return state != null && state.config != null ? state.config : new Dictionary<string, object>();
        }
        static int ConfigInt(Dictionary<string, object> values, string key, int fallback)
        {
            object raw; int result;
            return values != null && values.TryGetValue(key, out raw) && int.TryParse(Convert.ToString(raw), out result) ? result : fallback;
        }
        static void Focus(Process process) { ShowWindowAsync(process.MainWindowHandle, 9); SetForegroundWindow(process.MainWindowHandle); Thread.Sleep(300); }
        static void ClickAt(Process process, int x, int y)
        {
            RECT rect; if (!GetWindowRect(process.MainWindowHandle, out rect)) throw new InvalidOperationException("Не вдалося визначити вікно гри.");
            SetCursorPos(rect.Left + x, rect.Top + y); mouse_event(2, 0, 0, 0, UIntPtr.Zero); mouse_event(4, 0, 0, 0, UIntPtr.Zero);
        }
        void OpenCoordinatePanel()
        {
            try
            {
                Process process = Game(); if (process == null) throw new InvalidOperationException("Виберіть запущене вікно гри.");
                var config = Config(); int x = ConfigInt(config, "OpenOffsetX", 0), y = ConfigInt(config, "OpenOffsetY", 0);
                if (x <= 0 || y <= 0) throw new InvalidOperationException("Спочатку налаштуйте кнопку координат у TitulHelper.");
                Focus(process); ClickAt(process, x, y); Thread.Sleep(ConfigInt(config, "DelayMs", 650)); opened.Checked = true;
                SetStatus("ПАНЕЛЬ КООРДИНАТ ВІДКРИТО", Theme.Cyan);
            }
            catch (Exception e) { MessageBox.Show(e.Message, "Карта ресурсів"); }
        }
        void Inject()
        {
            try
            {
                if (selectedX < 0 || selectedY < 0) throw new InvalidOperationException("Спочатку виберіть точку ресурсу.");
                Process process = Game(); if (process == null) throw new InvalidOperationException("Виберіть запущене вікно гри.");
                var config = Config();
                int openX = ConfigInt(config, "OpenOffsetX", 0), openY = ConfigInt(config, "OpenOffsetY", 0), coordX = ConfigInt(config, "CoordOffsetX", 0), coordY = ConfigInt(config, "CoordOffsetY", 0);
                if (openX <= 0 || openY <= 0 || coordX <= 0 || coordY <= 0) throw new InvalidOperationException("Спочатку виконайте обидва кроки налаштування координат у TitulHelper.");
                Focus(process);
                if (!opened.Checked) { ClickAt(process, openX, openY); Thread.Sleep(ConfigInt(config, "DelayMs", 650)); opened.Checked = true; }
                ClickAt(process, coordX, coordY); Thread.Sleep(180);
                SendKeys.SendWait("{END}"); SendKeys.SendWait("{BACKSPACE 16}"); SendKeys.SendWait(selectedX + " " + selectedY); SendKeys.SendWait("{ENTER}");
                SetStatus("МІТКУ ВСТАНОВЛЕНО: " + selectedX + " " + selectedY, Theme.GoldSoft);
            }
            catch (Exception e) { MessageBox.Show(e.Message, "Карта ресурсів"); }
        }
        void SetStatus(string text, Color color) { status.Text = text; status.ForeColor = color; }
        public void OnActivated() { RefreshGames(); }

        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr handle);
        [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr handle, int command);
        [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
        [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint x, uint y, int data, UIntPtr extra);
        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr handle, out RECT rect);
        struct RECT { public int Left, Top, Right, Bottom; }
    }

    internal sealed class ResourceMapCanvas : Control
    {
        Image mapImage;
        RectangleF mapBounds;
        Point selected = new Point(-1, -1);
        List<ResourceGroup> groups = new List<ResourceGroup>();
        readonly Dictionary<int, Image> icons = new Dictionary<int, Image>();
        ResourceSelection selectedResource;
        RectangleF popupBounds = RectangleF.Empty;
        RectangleF autoButtonBounds = RectangleF.Empty;
        float zoom = 1f;
        PointF pan = PointF.Empty;
        Point dragStart;
        PointF panStart;
        bool dragging;
        public event Action<int, int> CoordinatePicked;
        public event Action<ResourceSelection> ResourcePicked;
        public event Action AutoInputRequested;
        public Point SelectedCoordinates { get { return selected; } set { selected = value; } }
        public List<ResourceGroup> Groups
        {
            get { return groups; }
            set
            {
                groups = value ?? new List<ResourceGroup>();
                if (selectedResource != null && !groups.Any(x => x.id == selectedResource.Group.id)) selectedResource = null;
                Invalidate();
            }
        }

        public ResourceMapCanvas()
        {
            DoubleBuffered = true; BackColor = Color.FromArgb(5, 35, 31); Cursor = Cursors.Cross;
            mapImage = AssetImages.Load("resource-map.png");
            MouseWheel += OnMapWheel; MouseDown += OnMapDown; MouseMove += OnMapMove; MouseUp += OnMapUp;
            MouseDoubleClick += delegate { ResetView(); };
        }

        public void ResetView() { zoom = 1f; pan = PointF.Empty; Invalidate(); }

        void ClampPan()
        {
            if (zoom <= 1.001f) { pan = PointF.Empty; return; }
            if (mapImage == null) return;
            float fit = Math.Min((ClientSize.Width - 12f) / mapImage.Width, (ClientSize.Height - 12f) / mapImage.Height);
            float width = mapImage.Width * fit * zoom, height = mapImage.Height * fit * zoom;
            float maxX = Math.Max(0, (width - ClientSize.Width) / 2f + 6f);
            float maxY = Math.Max(0, (height - ClientSize.Height) / 2f + 6f);
            pan = new PointF(Math.Max(-maxX, Math.Min(maxX, pan.X)), Math.Max(-maxY, Math.Min(maxY, pan.Y)));
        }

        RectangleF CalculateBounds()
        {
            if (mapImage == null) return RectangleF.Empty;
            float fit = Math.Min((ClientSize.Width - 12f) / mapImage.Width, (ClientSize.Height - 12f) / mapImage.Height);
            float width = mapImage.Width * fit * zoom, height = mapImage.Height * fit * zoom;
            return new RectangleF((ClientSize.Width - width) / 2f + pan.X, (ClientSize.Height - height) / 2f + pan.Y, width, height);
        }

        PointF ToScreen(int x, int z)
        {
            return new PointF(mapBounds.Left + x / 800f * mapBounds.Width, mapBounds.Bottom - z / 1000f * mapBounds.Height);
        }

        Image Icon(ResourceGroup group)
        {
            Image icon;
            if (icons.TryGetValue(group.id, out icon)) return icon;
            icon = AssetImages.Load("resource-icons", group.id + ".png");
            icons[group.id] = icon;
            return icon;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); e.Graphics.Clear(Color.FromArgb(5, 35, 31));
            if (mapImage == null) { TextRenderer.DrawText(e.Graphics, "Карта не знайдена", Font, ClientRectangle, Theme.Muted, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter); return; }
            mapBounds = CalculateBounds();
            e.Graphics.InterpolationMode = zoom > 2f ? System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor : System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            e.Graphics.DrawImage(mapImage, mapBounds);
            using (var shade = new SolidBrush(Color.FromArgb(45, 0, 20, 16))) e.Graphics.FillRectangle(shade, mapBounds);
            using (var pen = new Pen(Theme.Gold, 2)) e.Graphics.DrawRectangle(pen, mapBounds.X, mapBounds.Y, mapBounds.Width, mapBounds.Height);

            var occupied = new HashSet<long>();
            foreach (ResourceGroup group in groups)
            {
                Color color = group.kind == "herb" ? Color.FromArgb(235, 85, 230, 120) : Color.FromArgb(235, 255, 205, 45);
                Image icon = Icon(group);
                foreach (ResourcePoint point in group.points)
                {
                    PointF p = ToScreen(point.x, point.z);
                    if (p.X < 0 || p.Y < 0 || p.X > Width || p.Y > Height) continue;
                    int cellSize = zoom < 1.7f ? 20 : (zoom < 3f ? 14 : 8);
                    int cellX = (int)p.X / cellSize, cellY = (int)p.Y / cellSize;
                    long key = ((long)cellX << 32) ^ (uint)cellY;
                    if (!occupied.Add(key)) continue;
                    var marker = new RectangleF(p.X - 10, p.Y - 10, 20, 20);
                    using (var back = new SolidBrush(Color.FromArgb(225, 8, 20, 24))) e.Graphics.FillRectangle(back, marker);
                    if (icon != null) e.Graphics.DrawImage(icon, marker);
                    else
                    {
                        using (var brush = new SolidBrush(color)) e.Graphics.FillRectangle(brush, marker.X + 3, marker.Y + 3, 14, 14);
                        TextRenderer.DrawText(e.Graphics, group.kind == "herb" ? "Т" : "Р", new Font(Font.FontFamily, 7, FontStyle.Bold), Rectangle.Round(marker), Color.White,
                            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                    }
                    using (var border = new Pen(Color.FromArgb(220, 235, 235, 230), 1)) e.Graphics.DrawRectangle(border, marker.X, marker.Y, marker.Width, marker.Height);
                }
            }

            popupBounds = RectangleF.Empty; autoButtonBounds = RectangleF.Empty;
            if (selected.X >= 0)
            {
                PointF p = ToScreen(selected.X, selected.Y);
                using (var pen = new Pen(Color.FromArgb(255, 255, 210, 45), 3)) e.Graphics.DrawEllipse(pen, p.X - 14, p.Y - 14, 28, 28);
                if (selectedResource != null)
                {
                    float popupWidth = 260, popupHeight = 92;
                    float popupX = p.X + 18, popupY = p.Y - popupHeight / 2;
                    if (popupX + popupWidth > Width - 4) popupX = p.X - popupWidth - 18;
                    popupY = Math.Max(4, Math.Min(Height - popupHeight - 4, popupY));
                    popupBounds = new RectangleF(popupX, popupY, popupWidth, popupHeight);
                    using (var back = new SolidBrush(Color.FromArgb(244, 27, 45, 43))) e.Graphics.FillRectangle(back, popupBounds);
                    using (var border = new Pen(Theme.GoldSoft, 1)) e.Graphics.DrawRectangle(border, popupBounds.X, popupBounds.Y, popupBounds.Width, popupBounds.Height);
                    var titleRect = new Rectangle((int)popupX + 10, (int)popupY + 7, 240, 20);
                    TextRenderer.DrawText(e.Graphics, "T" + selectedResource.Group.tier + " · " + selectedResource.Group.name,
                        new Font(Font.FontFamily, 8, FontStyle.Bold), titleRect, Theme.GoldSoft, TextFormatFlags.EndEllipsis | TextFormatFlags.VerticalCenter);
                    var coordRect = new Rectangle((int)popupX + 10, (int)popupY + 31, 145, 24);
                    TextRenderer.DrawText(e.Graphics, "📍 " + selected.X + " " + selected.Y + "   ↕ " + selectedResource.Point.h,
                        new Font(Font.FontFamily, 10, FontStyle.Bold), coordRect, Color.White, TextFormatFlags.VerticalCenter);
                    autoButtonBounds = new RectangleF(popupX + 157, popupY + 31, 94, 28);
                    using (var button = new SolidBrush(Theme.Gold)) e.Graphics.FillRectangle(button, autoButtonBounds);
                    TextRenderer.DrawText(e.Graphics, "АВТОВВІД", new Font(Font.FontFamily, 8, FontStyle.Bold), Rectangle.Round(autoButtonBounds), Theme.Ink,
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
                    var copiedRect = new Rectangle((int)popupX + 10, (int)popupY + 64, 240, 19);
                    TextRenderer.DrawText(e.Graphics, "Координати вже скопійовано в буфер", new Font(Font.FontFamily, 7), copiedRect, Theme.Cyan, TextFormatFlags.VerticalCenter);
                }
            }
        }

        void OnMapWheel(object sender, MouseEventArgs e)
        {
            float old = zoom;
            zoom = Math.Max(1f, Math.Min(6f, zoom * (e.Delta > 0 ? 1.25f : 0.8f)));
            if (Math.Abs(old - zoom) < 0.001f) return;
            float ratio = zoom / old;
            float centerX = ClientSize.Width / 2f, centerY = ClientSize.Height / 2f;
            pan = new PointF((1f - ratio) * (e.X - centerX) + ratio * pan.X,
                (1f - ratio) * (e.Y - centerY) + ratio * pan.Y);
            ClampPan(); Invalidate();
        }
        void OnMapDown(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            dragStart = e.Location; panStart = pan; dragging = false; Capture = true;
        }
        void OnMapMove(object sender, MouseEventArgs e)
        {
            if (!Capture || e.Button != MouseButtons.Left || zoom <= 1.001f) return;
            int dx = e.X - dragStart.X, dy = e.Y - dragStart.Y;
            if (Math.Abs(dx) + Math.Abs(dy) > 7) dragging = true;
            if (dragging) { pan = new PointF(panStart.X + dx, panStart.Y + dy); ClampPan(); Invalidate(); }
        }
        void OnMapUp(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left) return;
            Capture = false;
            if (dragging) return;
            if (!autoButtonBounds.IsEmpty && autoButtonBounds.Contains(e.Location))
            {
                var autoInput = AutoInputRequested; if (autoInput != null) autoInput();
                return;
            }
            mapBounds = CalculateBounds(); if (!mapBounds.Contains(e.Location)) return;
            ResourceSelection nearest = null; double distance = 14 * 14;
            foreach (ResourceGroup group in groups)
            foreach (ResourcePoint point in group.points)
            {
                PointF p = ToScreen(point.x, point.z);
                double d = (p.X - e.X) * (p.X - e.X) + (p.Y - e.Y) * (p.Y - e.Y);
                if (d < distance) { distance = d; nearest = new ResourceSelection { Group = group, Point = point }; }
            }
            if (nearest != null)
            {
                selectedResource = nearest; selected = new Point(nearest.Point.x, nearest.Point.z); Invalidate();
                var picked = ResourcePicked; if (picked != null) picked(nearest);
                return;
            }
            selectedResource = null;
            int x = (int)Math.Round((e.X - mapBounds.Left) * 800.0 / mapBounds.Width);
            int z = (int)Math.Round((mapBounds.Bottom - e.Y) * 1000.0 / mapBounds.Height);
            var handler = CoordinatePicked; if (handler != null) handler(x, z);
        }
    }
}
