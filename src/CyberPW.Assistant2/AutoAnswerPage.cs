using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class AutoAnswerPage : UserControl, IModulePage
    {
        public string Title { get { return "АВТОВІДПОВІДІ · SUPER BETA"; } }

        public AutoAnswerPage()
        {
            Dock = DockStyle.Fill;
        }

        public void OnActivated()
        {
        }
    }
}
