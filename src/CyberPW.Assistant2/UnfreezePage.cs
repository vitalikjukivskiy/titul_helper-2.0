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
            BackColor = Theme.Ink;
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
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr h, int c);
        [DllImport("user32.dll")] static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
        [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint c, INPUT[] i, int s);
        [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public INPUTUNION data; }
        [StructLayout(LayoutKind.Explicit)] struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT keyboard; }
        [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort virtualKey, scanCode; public uint flags, time; public UIntPtr extraInfo; }
        public static void Activate(IntPtr h) { ShowWindowAsync(h, 9); if (!SetForegroundWindow(h)) throw new Win32Exception(Marshal.GetLastWin32Error()); }
        public static void OpenConsole() { keybd_event(16, 0, 0, UIntPtr.Zero); keybd_event(192, 0, 0, UIntPtr.Zero); keybd_event(192, 0, 2, UIntPtr.Zero); keybd_event(16, 0, 2, UIntPtr.Zero); }
        public static void SendUnicodeText(string text) { foreach (char c in text) { var a = new INPUT[2]; a[0].type = a[1].type = 1; a[0].data.keyboard.scanCode = a[1].data.keyboard.scanCode = c; a[0].data.keyboard.flags = 4; a[1].data.keyboard.flags = 6; if (SendInput(2, a, Marshal.SizeOf(typeof(INPUT))) != 2) throw new Win32Exception(); } }
        public static void PressEnter() { keybd_event(13, 0, 0, UIntPtr.Zero); keybd_event(13, 0, 2, UIntPtr.Zero); }
    }
}
