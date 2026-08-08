using System;
using System.Drawing;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class AutoAnswerPage : UserControl, IModulePage
    {
        readonly Label status;

        public AutoAnswerPage()
        {
            Dock = DockStyle.Fill;
            BackColor = Theme.Ink;
            ForeColor = Theme.Text;
            Font = new Font("Segoe UI", 9);

            var title = Theme.Label("АВТОВІДПОВІДІ · СУПЕР БЕТА", 22, Theme.GoldSoft, FontStyle.Bold);
            title.SetBounds(24, 18, 760, 42);
            Controls.Add(title);

            var sub = Theme.Label("Чон-Пон + КХ · OCR-помічник · без автокліків", 10, Theme.Cyan, FontStyle.Bold);
            sub.SetBounds(26, 66, 760, 26);
            Controls.Add(sub);

            var card = new CardPanel();
            card.SetBounds(24, 118, 820, 260);
            Controls.Add(card);

            var info = Theme.Label(
                "Модуль інтегровано у CyberPW Assistant.\r\n\r\n" +
                "База Чон-Пон: " + QuizData.LoadChonPon().Count + " питань.\r\n" +
                "База КХ: " + QuizData.LoadKh().Count + " питань.\r\n\r\n" +
                "Автокліки вимкнено. OCR та налаштування області додаються у цю ж вкладку.",
                11, Theme.Text, FontStyle.Regular);
            info.AutoSize = false;
            info.SetBounds(24, 24, 760, 180);
            card.Controls.Add(info);

            status = Theme.Label("SUPER BETA · модуль завантажено", 10, Theme.Cyan, FontStyle.Bold);
            status.SetBounds(26, 404, 760, 30);
            Controls.Add(status);
        }

        public void OnActivated()
        {
            status.Text = "SUPER BETA · модуль завантажено";
        }
    }
}
