using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class UnfreezePage : UserControl, IModulePage
    {
        private readonly CheckedListBox _windows = new CheckedListBox();
        private readonly Label _status;
        public string Title { get { return "Розморозка"; } }
        public UnfreezePage()
        {
            BackColor = Theme.Ink; BackgroundImage = AssetImages.Load("summer","unfreeze.jpg"); BackgroundImageLayout = ImageLayout.Stretch;
            var title = Theme.Label("РОЗМОРОЗКА ВІКОН", 24F, Theme.GoldSoft, FontStyle.Bold); title.Location = new Point(24, 22); Controls.Add(title);
            _status = Theme.Label("", 10F, Theme.Muted, FontStyle.Regular); _status.Location = new Point(27, 70); Controls.Add(_status);
            _windows.SetBounds(26, 110, 720, 390); _windows.BackColor = Theme.Panel; _windows.ForeColor = Theme.Text; _windows.CheckOnClick = true; _windows.Font = new Font("Segoe UI", 10F); Controls.Add(_windows);
            var refresh = Theme.Button("ОНОВИТИ"); refresh.SetBounds(26, 525, 150, 44); refresh.Click += delegate { RefreshWindows(); }; Controls.Add(refresh);
            var all = Theme.Button("ВИБРАТИ ВСІ"); all.SetBounds(190, 525, 150, 44); all.Click += delegate { CheckAll(true); }; Controls.Add(all);
            var none = Theme.Button("ЗНЯТИ ВСІ"); none.SetBounds(354, 525, 150, 44); none.Click += delegate { CheckAll(false); }; Controls.Add(none);
            var run = Theme.Button("УВІМКНУТИ ФОНОВИЙ РЕНДЕР"); run.SetBounds(518, 525, 300, 44); run.Click += delegate { Apply(); }; Controls.Add(run);
            RefreshWindows();
        }
        private void RefreshWindows()
        {
            _windows.Items.Clear();
            foreach (Process p in Process.GetProcessesByName("ElementClient")) if (p.MainWindowHandle != IntPtr.Zero) _windows.Items.Add(new WindowItem(p));
            _status.Text = _windows.Items.Count == 0 ? "ElementClient не знайдено." : "Знайдено вікон: " + _windows.Items.Count;
        }
        private void CheckAll(bool value) { for (int i = 0; i < _windows.Items.Count; i++) _windows.SetItemChecked(i, value); }
        private void Apply()
        {
            int success = 0;
            for (int i = 0; i < _windows.Items.Count; i++) if (_windows.GetItemChecked(i))
            {
                var item = (WindowItem)_windows.Items[i];
                try { NativeInput.Activate(item.Process.MainWindowHandle); Thread.Sleep(300); NativeInput.OpenConsole(); Thread.Sleep(220); NativeInput.SendUnicodeText("d_rendernofocus 1"); NativeInput.PressEnter(); success++; }
                catch (Exception e) { MessageBox.Show(item + "\n" + e.Message, "Розморозка"); }
            }
            _status.Text = success > 0 ? "Готово. Оброблено: " + success : "Позначте хоча б одне вікно.";
        }
        public void OnActivated() { RefreshWindows(); }
    }
    internal sealed class WindowItem
    {
        public Process Process { get; private set; }
        public WindowItem(Process p) { Process = p; }
        public override string ToString() { return (string.IsNullOrWhiteSpace(Process.MainWindowTitle) ? "ElementClient" : Process.MainWindowTitle) + " · PID " + Process.Id; }
    }
    internal static class NativeInput
    {
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr handle);
        [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr handle, int command);

        public static void Activate(IntPtr handle)
        {
            if (handle == IntPtr.Zero) throw new InvalidOperationException("Вікно клієнта вже закрите.");
            ShowWindowAsync(handle, 9);
            SetForegroundWindow(handle);
            Thread.Sleep(120);
        }

        public static void OpenConsole()
        {
            MacroNative.Key((ushort)Keys.ShiftKey, false);
            MacroNative.Key((ushort)Keys.Oemtilde, false);
            MacroNative.Key((ushort)Keys.Oemtilde, true);
            MacroNative.Key((ushort)Keys.ShiftKey, true);
        }

        public static void SendUnicodeText(string text) { MacroNative.Text(text); }
        public static void PressEnter()
        {
            MacroNative.Key((ushort)Keys.Enter, false);
            MacroNative.Key((ushort)Keys.Enter, true);
        }
    }
}