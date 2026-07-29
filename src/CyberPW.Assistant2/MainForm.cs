using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class MainForm : Form
    {
        private readonly Panel _navigation;
        private readonly Panel _content;
        private readonly Label _pageTitle;
        private readonly Dictionary<string, Control> _pages = new Dictionary<string, Control>();

        public MainForm()
        {
            Text = "CyberPW Assistant 2.0 Alpha";
            StartPosition = FormStartPosition.CenterScreen;
            MinimumSize = new Size(1080, 720);
            Size = new Size(1280, 800);
            BackColor = Theme.Ink;
            ForeColor = Theme.Text;
            Font = new Font("Segoe UI", 9F);
            Icon = LoadIcon();

            _navigation = new Panel { Dock = DockStyle.Left, Width = 230, BackColor = Color.FromArgb(0, 42, 36) };
            var header = new Panel { Dock = DockStyle.Top, Height = 74, BackColor = Color.FromArgb(0, 25, 22) };
            _pageTitle = Theme.Label("ГОЛОВНА", 15F, Theme.GoldSoft, FontStyle.Bold);
            _pageTitle.Location = new Point(22, 23);
            header.Controls.Add(_pageTitle);

            _content = new Panel { Dock = DockStyle.Fill, Padding = new Padding(18), BackColor = Theme.Ink };
            Controls.Add(_content);
            Controls.Add(_navigation);
            Controls.Add(header);
            header.BringToFront();

            BuildNavigation();
            RegisterPage("ГОЛОВНА", new DashboardPage(ShowPage));
            RegisterPage("TITULHELPER", new TitlesPage());
            RegisterPage("MULTILAUNCHER", new MultiLauncherPage());
            RegisterPage("МАКРОСИ", new MacroStudioPage());
            RegisterPage("СИМУЛЯТОР", new SimulatorPage());
            RegisterPage("РОЗМОРОЗКА", new UnfreezePage());
            RegisterPage("СВІТОВІ БОСИ", new BossesPage());

            ShowPage("ГОЛОВНА");
        }

        private Icon LoadIcon()
        {
            string path = Path.Combine(AppPaths.Root, "cyberpw-logo.ico");
            try { return File.Exists(path) ? new Icon(path) : null; }
            catch { return null; }
        }

        private void BuildNavigation()
        {
            var brand = Theme.Label("CyberPW Assistant", 14F, Theme.GoldSoft, FontStyle.Bold);
            brand.Location = new Point(22, 24);
            _navigation.Controls.Add(brand);
            var version = Theme.Label("2.0 ALPHA · C#", 9F, Theme.Cyan, FontStyle.Bold);
            version.Location = new Point(23, 54);
            _navigation.Controls.Add(version);

            string[] names = { "ГОЛОВНА", "TITULHELPER", "MULTILAUNCHER", "МАКРОСИ", "СИМУЛЯТОР", "РОЗМОРОЗКА", "СВІТОВІ БОСИ" };
            int top = 96;
            foreach (string name in names)
            {
                var button = Theme.Button(name);
                button.SetBounds(16, top, 198, 43);
                button.TextAlign = ContentAlignment.MiddleLeft;
                button.Padding = new Padding(12, 0, 0, 0);
                string captured = name;
                button.Click += delegate { ShowPage(captured); };
                _navigation.Controls.Add(button);
                top += 50;
            }
        }

        private void RegisterPage(string key, Control page)
        {
            page.Dock = DockStyle.Fill;
            page.Visible = false;
            _pages[key] = page;
            _content.Controls.Add(page);
        }

        private void ShowPage(string key)
        {
            Control page;
            if (!_pages.TryGetValue(key, out page)) return;
            foreach (Control item in _pages.Values) item.Visible = false;
            page.Visible = true;
            page.BringToFront();
            _pageTitle.Text = key;
            var module = page as IModulePage;
            if (module != null) module.OnActivated();
        }
    }
}
