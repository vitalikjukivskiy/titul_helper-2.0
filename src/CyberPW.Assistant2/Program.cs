using System;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            bool created;
            using (var mutex = new Mutex(true, @"Local\CyberPW-Assistant-2-Alpha", out created))
            {
                if (!created)
                {
                    MessageBox.Show("CyberPW Assistant 2.0 (BETA) уже запущено.", "CyberPW Assistant");
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                try { Application.Run(new MainForm()); }
                finally { AssetImages.DisposeAll(); }
            }
        }
    }
}
