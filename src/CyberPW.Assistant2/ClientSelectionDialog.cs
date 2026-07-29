using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class ClientSelectionDialog : Form
    {
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(System.IntPtr handle);

        [DllImport("user32.dll")]
        private static extern bool ShowWindowAsync(System.IntPtr handle, int command);

        private readonly ListBox _list;

        public Process SelectedProcess
        {
            get
            {
                var item = _list.SelectedItem as ClientProcessItem;
                return item == null ? null : item.Process;
            }
        }

        public ClientSelectionDialog(IList<Process> processes)
        {
            Text = "TitulHelper — вибір персонажа";
            ClientSize = new Size(600, 350);
            StartPosition = FormStartPosition.CenterParent;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            ShowInTaskbar = false;
            BackColor = Theme.Ink;
            ForeColor = Theme.Text;

            var title = Theme.Label(
                "ВІДКРИТО КІЛЬКА КЛІЄНТІВ\nОберіть вікно персонажа для синхронізації.",
                11F, Theme.GoldSoft, FontStyle.Bold);
            title.Location = new Point(22, 18);
            Controls.Add(title);

            _list = new ListBox
            {
                Location = new Point(22, 78),
                Size = new Size(555, 175),
                BackColor = Theme.Panel,
                ForeColor = Theme.Text,
                BorderStyle = BorderStyle.FixedSingle,
                Font = new Font("Segoe UI", 10F)
            };
            for (int index = 0; index < processes.Count; index++)
                _list.Items.Add(new ClientProcessItem(processes[index], index + 1));
            if (_list.Items.Count > 0) _list.SelectedIndex = 0;
            _list.DoubleClick += delegate
            {
                if (_list.SelectedItem != null)
                {
                    DialogResult = DialogResult.OK;
                    Close();
                }
            };
            Controls.Add(_list);

            var show = Theme.Button("ПОКАЗАТИ ВІКНО");
            show.SetBounds(22, 275, 175, 42);
            show.Click += delegate
            {
                Process selected = SelectedProcess;
                if (selected == null) return;
                ShowWindowAsync(selected.MainWindowHandle, 9);
                SetForegroundWindow(selected.MainWindowHandle);
            };
            Controls.Add(show);

            var choose = Theme.Button("ВИБРАТИ");
            choose.SetBounds(325, 275, 120, 42);
            choose.DialogResult = DialogResult.OK;
            Controls.Add(choose);

            var cancel = Theme.Button("СКАСУВАТИ");
            cancel.SetBounds(457, 275, 120, 42);
            cancel.DialogResult = DialogResult.Cancel;
            Controls.Add(cancel);
            AcceptButton = choose;
            CancelButton = cancel;
        }
    }
}
