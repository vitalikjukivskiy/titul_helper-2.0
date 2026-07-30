using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal static class Theme
    {
        public static readonly Color Ink = Color.FromArgb(0, 31, 27);
        public static readonly Color Panel = Color.FromArgb(5, 54, 45);
        public static readonly Color Panel2 = Color.FromArgb(8, 70, 58);
        public static readonly Color Gold = Color.FromArgb(216, 174, 45);
        public static readonly Color GoldSoft = Color.FromArgb(255, 220, 125);
        public static readonly Color Text = Color.FromArgb(232, 245, 240);
        public static readonly Color Muted = Color.FromArgb(158, 197, 187);
        public static readonly Color Cyan = Color.FromArgb(44, 226, 194);
        public static readonly Color Danger = Color.FromArgb(220, 78, 78);

        public static Button Button(string text)
        {
            var button = new CyberButton();
            button.Text = text;
            button.Height = 42;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = Gold;
            button.FlatAppearance.BorderSize = 0;
            button.BackColor = Panel2;
            button.ForeColor = GoldSoft;
            button.Font = new Font("Segoe UI", 9.5F, FontStyle.Bold);
            button.Cursor = Cursors.Hand;
            return button;
        }

        public static Label Label(string text, float size, Color color, FontStyle style)
        {
            return new Label
            {
                Text = text,
                AutoSize = true,
                ForeColor = color,
                BackColor = Color.Transparent,
                Font = new Font("Segoe UI", size, style)
            };
        }

        public static void Round(Control control, int radius)
        {
            if (control.Width <= 0 || control.Height <= 0) return;
            using (var path = new GraphicsPath())
            {
                int d = radius * 2;
                path.AddArc(0, 0, d, d, 180, 90);
                path.AddArc(control.Width - d - 1, 0, d, d, 270, 90);
                path.AddArc(control.Width - d - 1, control.Height - d - 1, d, d, 0, 90);
                path.AddArc(0, control.Height - d - 1, d, d, 90, 90);
                path.CloseFigure();
                control.Region = new Region(path);
            }
        }
    }
}
