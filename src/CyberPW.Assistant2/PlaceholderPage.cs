using System.Drawing;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class PlaceholderPage : UserControl, IModulePage
    {
        public string Title { get; private set; }

        public PlaceholderPage(string title, string message)
        {
            Title = title;
            BackColor = Theme.Ink; BackgroundImage = AssetImages.Load("main-summer.jpg"); BackgroundImageLayout = ImageLayout.Stretch;
            var heading = Theme.Label(title + " · 2.0 Alpha", 24F, Theme.GoldSoft, FontStyle.Bold);
            heading.Location = new Point(24, 25);
            Controls.Add(heading);
            var info = Theme.Label(message, 11F, Theme.Muted, FontStyle.Regular);
            info.Location = new Point(27, 82);
            Controls.Add(info);
        }

        public void OnActivated() { }
    }
}
