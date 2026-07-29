using System;
using System.Drawing;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class DashboardPage : UserControl, IModulePage
    {
        private readonly Action<string> _navigate;
        public string Title { get { return "Головна"; } }

        public DashboardPage(Action<string> navigate)
        {
            _navigate = navigate;
            BackColor = Theme.Ink;
            BackgroundImage = AssetImages.Load("main-summer.jpg");
            BackgroundImageLayout = ImageLayout.Stretch;
            AutoScroll = true;

            var title = Theme.Label("CyberPW Assistant 2.0 Alpha", 27F, Theme.GoldSoft, FontStyle.Bold);
            title.Location = new Point(22, 20);
            Controls.Add(title);
            var text = Theme.Label("Один швидкий C# процес · без запуску PowerShell між модулями", 11F, Theme.Muted, FontStyle.Regular);
            text.Location = new Point(25, 72);
            Controls.Add(text);

            string[,] cards =
            {
                { "TITULHELPER", "260 титулів · пошук · прогрес", "titles.jpg" },
                { "MULTILAUNCHER", "Профілі та запуск клієнтів", "multilauncher.jpg" },
                { "МАКРОСИ", "Клавіатура · миша · пікселі · умови", "macros.jpg" },
                { "СИМУЛЯТОР", "Скриня Тора", "simulator.jpg" },
                { "РОЗМОРОЗКА", "Фоновий рендер вікон", "unfreeze.jpg" },
                { "СВІТОВІ БОСИ", "Координати та розклад", "bosses.jpg" }
            };

            for (int i = 0; i < cards.GetLength(0); i++)
            {
                int column = i % 3;
                int row = i / 3;
                var card = new Panel
                {
                    BackColor = Theme.Panel,
                    BackgroundImage = AssetImages.Load("summer", cards[i, 2]),
                    BackgroundImageLayout = ImageLayout.Stretch,
                    Location = new Point(22 + column * 290, 125 + row * 160),
                    Size = new Size(270, 140)
                };
                string key = cards[i, 0];
                var cardTitle = Theme.Label(key, 11F, Theme.GoldSoft, FontStyle.Bold);
                cardTitle.Location = new Point(16, 15);
                card.Controls.Add(cardTitle);
                var description = Theme.Label(cards[i, 1], 9F, Theme.Text, FontStyle.Regular);
                description.Location = new Point(16, 47);
                card.Controls.Add(description);
                var open = Theme.Button("ВІДКРИТИ");
                open.SetBounds(14, 87, 242, 38);
                open.Click += delegate { _navigate(key); };
                card.Controls.Add(open);
                card.Resize += delegate { Theme.Round(card, 12); };
                Theme.Round(card, 12);
                Controls.Add(card);
            }
        }

        public void OnActivated() { }
    }
}
