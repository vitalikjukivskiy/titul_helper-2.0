using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class AutoAnswerPage : UserControl, IModulePage
    {
        [StructLayout(LayoutKind.Sequential)]
        struct RECT { public int Left, Top, Right, Bottom; }

        [DllImport("user32.dll")]
        static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        sealed class ClientItem
        {
            public int Pid;
            public IntPtr Handle;
            public string Text;
            public override string ToString() { return Text; }
        }

        sealed class ScanRegion
        {
            public int X, Y, W, H;
        }

        sealed class MatchResult
        {
            public QuizRecord Item;
            public double Score;
            public string Fragment;
        }

        readonly ComboBox clients = new ComboBox();
        readonly Button refreshButton;
        readonly Button scanButton;
        readonly Button regionButton;
        readonly Button autoRegionButton;
        readonly Button ocrButton;
        readonly Button helpButton;
        readonly CheckBox autoCheck = new CheckBox();
        readonly Label status;
        readonly TextBox question;
        readonly TextBox answer;
        readonly TextBox matches;
        readonly Timer autoTimer = new Timer();
        readonly BackgroundWorker scanWorker = new BackgroundWorker();
        readonly List<QuizRecord> database = new List<QuizRecord>();
        readonly Dictionary<QuizRecord,string> normalizedQuestions = new Dictionary<QuizRecord,string>();
        bool busy;

        string ModuleData { get { return Path.Combine(AppPaths.Data, "autoanswer"); } }
        string RegionPath { get { return Path.Combine(ModuleData, "scan-region.txt"); } }
        string LocalTessRoot { get { return Path.Combine(ModuleData, "tesseract"); } }
        string LocalTessExe { get { return Path.Combine(LocalTessRoot, "tesseract.exe"); } }
        string LocalTessData { get { return Path.Combine(LocalTessRoot, "tessdata"); } }

        public string Title { get { return "АВТОВІДПОВІДІ · SUPER BETA"; } }

        public AutoAnswerPage()
        {
            Dock = DockStyle.Fill;
            BackColor = Theme.Ink;
            ForeColor = Theme.Text;
            Font = new Font("Segoe UI", 9);
            Directory.CreateDirectory(ModuleData);

            var title = Theme.Label("АВТОВІДПОВІДІ · СУПЕР БЕТА", 21, Theme.GoldSoft, FontStyle.Bold);
            title.SetBounds(22, 12, 650, 38); Controls.Add(title);
            var subtitle = Theme.Label("Чон-Пон + КХ · OCR-помічник · без автокліків", 9, Theme.Cyan, FontStyle.Bold);
            subtitle.SetBounds(24, 49, 650, 24); Controls.Add(subtitle);

            clients.DropDownStyle = ComboBoxStyle.DropDownList;
            clients.SetBounds(22, 82, 330, 30);
            clients.BackColor = Color.FromArgb(20,35,32);
            clients.ForeColor = Color.White;
            Controls.Add(clients);

            refreshButton = Theme.Button("ОНОВИТИ КЛІЄНТИ");
            refreshButton.SetBounds(364, 80, 158, 34);
            refreshButton.Click += delegate { RefreshClients(); };
            Controls.Add(refreshButton);

            scanButton = Theme.Button("СКАНУВАТИ");
            scanButton.SetBounds(534, 80, 132, 34);
            scanButton.Click += delegate { StartScan(); };
            Controls.Add(scanButton);

            autoCheck.Text = "АВТО 1.5 с";
            autoCheck.ForeColor = Theme.Text;
            autoCheck.BackColor = Color.Transparent;
            autoCheck.AutoSize = true;
            autoCheck.SetBounds(680, 87, 110, 24);
            autoCheck.CheckedChanged += delegate { autoTimer.Enabled = autoCheck.Checked; };
            Controls.Add(autoCheck);

            regionButton = Theme.Button("НАЛАШТУВАТИ ОБЛАСТЬ");
            regionButton.SetBounds(22, 126, 215, 34);
            regionButton.Click += delegate { SelectRegion(); };
            Controls.Add(regionButton);

            autoRegionButton = Theme.Button("АВТО-ОБЛАСТЬ");
            autoRegionButton.SetBounds(249, 126, 150, 34);
            autoRegionButton.Click += delegate { ResetRegion(); };
            Controls.Add(autoRegionButton);

            ocrButton = Theme.Button("ПІДГОТУВАТИ OCR");
            ocrButton.SetBounds(411, 126, 180, 34);
            ocrButton.Click += delegate { SetupOcr(); };
            Controls.Add(ocrButton);

            helpButton = Theme.Button("ІНСТРУКЦІЯ");
            helpButton.SetBounds(603, 126, 140, 34);
            helpButton.Click += delegate { ShowHelp(); };
            Controls.Add(helpButton);

            status = Theme.Label("Готово.", 9, Theme.Cyan, FontStyle.Bold);
            status.SetBounds(22, 171, 820, 25); Controls.Add(status);

            var ql = Theme.Label("ПИТАННЯ", 9, Theme.GoldSoft, FontStyle.Bold);
            ql.SetBounds(22, 205, 150, 22); Controls.Add(ql);
            question = CreateBox(false, 11, false);
            question.SetBounds(22, 229, 820, 86); Controls.Add(question);

            var al = Theme.Label("ПРАВИЛЬНА ВІДПОВІДЬ", 9, Theme.Cyan, FontStyle.Bold);
            al.SetBounds(22, 326, 220, 22); Controls.Add(al);
            answer = CreateBox(true, 14, true);
            answer.SetBounds(22, 351, 820, 76); Controls.Add(answer);

            var ml = Theme.Label("НАЙКРАЩІ ЗБІГИ", 9, Theme.Muted, FontStyle.Bold);
            ml.SetBounds(22, 439, 220, 22); Controls.Add(ml);
            matches = CreateBox(false, 9, false);
            matches.SetBounds(22, 463, 820, 150); Controls.Add(matches);

            autoTimer.Interval = 1500;
            autoTimer.Tick += delegate { if (!busy) StartScan(); };

            scanWorker.DoWork += ScanWorkerDoWork;
            scanWorker.RunWorkerCompleted += ScanWorkerCompleted;

            LoadDatabase();
            RefreshClients();
            UpdateOcrStatus();
        }

        TextBox CreateBox(bool answerBox, int size, bool bold)
        {
            var b = new TextBox();
            b.Multiline = true; b.ReadOnly = true; b.ScrollBars = ScrollBars.Vertical;
            b.BackColor = answerBox ? Color.FromArgb(8,48,42) : Color.FromArgb(14,27,25);
            b.ForeColor = answerBox ? Color.FromArgb(160,245,210) : Color.White;
            b.BorderStyle = BorderStyle.FixedSingle;
            b.Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular);
            return b;
        }

        public void OnActivated()
        {
            RefreshClients();
            UpdateOcrStatus();
        }

        void LoadDatabase()
        {
            database.Clear();
            normalizedQuestions.Clear();
            try
            {
                database.AddRange(QuizData.LoadChonPon());
                database.AddRange(QuizData.LoadKh());
                foreach (var q in database) normalizedQuestions[q] = Normalize(q.question);
            }
            catch (Exception ex)
            {
                status.Text = "Помилка бази: " + ex.Message;
            }
        }

        void RefreshClients()
        {
            int oldPid = 0;
            var old = clients.SelectedItem as ClientItem;
            if (old != null) oldPid = old.Pid;
            clients.Items.Clear();
            try
            {
                foreach (var p in Process.GetProcessesByName("elementclient").OrderBy(x => x.Id))
                {
                    if (p.MainWindowHandle == IntPtr.Zero) continue;
                    var item = new ClientItem();
                    item.Pid = p.Id; item.Handle = p.MainWindowHandle;
                    item.Text = "PID " + p.Id + " — CyberPW";
                    clients.Items.Add(item);
                    if (p.Id == oldPid) clients.SelectedItem = item;
                }
            }
            catch { }
            if (clients.SelectedIndex < 0 && clients.Items.Count > 0) clients.SelectedIndex = 0;
            if (clients.Items.Count == 0) status.Text = "CyberPW не знайдено. Запусти гру та натисни «ОНОВИТИ КЛІЄНТИ».";
        }

        void StartScan()
        {
            if (busy || scanWorker.IsBusy) return;
            var client = clients.SelectedItem as ClientItem;
            if (client == null) { status.Text = "Спочатку вибери клієнт CyberPW."; return; }
            if (!OcrReady())
            {
                status.Text = "OCR не готовий. Натисни «ПІДГОТУВАТИ OCR».";
                return;
            }
            busy = true;
            scanButton.Enabled = false;
            question.Text = "";
            answer.Text = "";
            matches.Text = "";
            status.Text = "Сканую екран...";
            scanWorker.RunWorkerAsync(client);
        }

        void ScanWorkerDoWork(object sender, DoWorkEventArgs e)
        {
            var client = (ClientItem)e.Argument;
            e.Result = Scan(client);
        }

        sealed class ScanOutcome
        {
            public string Error;
            public string Ocr;
            public List<MatchResult> Top = new List<MatchResult>();
        }

        ScanOutcome Scan(ClientItem client)
        {
            var result = new ScanOutcome();
            try
            {
                RECT r;
                if (!GetWindowRect(client.Handle, out r)) throw new InvalidOperationException("Не вдалося отримати координати вікна CyberPW.");
                int ww = r.Right - r.Left, wh = r.Bottom - r.Top;
                if (ww < 300 || wh < 300) throw new InvalidOperationException("Вікно CyberPW занадто мале.");

                ScanRegion region = LoadRegion();
                if (region == null)
                {
                    region = new ScanRegion();
                    region.X = 0;
                    region.Y = Math.Max(0, (int)(wh * 0.04));
                    region.W = Math.Max(260, (int)(ww * 0.28));
                    region.H = Math.Max(360, (int)(wh * 0.82));
                }
                region.X = Math.Max(0, Math.Min(ww - 1, region.X));
                region.Y = Math.Max(0, Math.Min(wh - 1, region.Y));
                region.W = Math.Max(120, Math.Min(ww - region.X, region.W));
                region.H = Math.Max(120, Math.Min(wh - region.Y, region.H));

                string imagePath = Path.Combine(ModuleData, "ocr-input.png");
                using (var raw = new Bitmap(region.W, region.H))
                using (var g = Graphics.FromImage(raw))
                {
                    g.CopyFromScreen(r.Left + region.X, r.Top + region.Y, 0, 0, raw.Size, CopyPixelOperation.SourceCopy);
                    int scale = 2;
                    using (var scaled = new Bitmap(region.W * scale, region.H * scale))
                    using (var sg = Graphics.FromImage(scaled))
                    {
                        sg.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        sg.DrawImage(raw, 0, 0, scaled.Width, scaled.Height);
                        scaled.Save(imagePath, System.Drawing.Imaging.ImageFormat.Png);
                    }
                }

                result.Ocr = RunTesseract(imagePath);
                result.Top = Match(result.Ocr).Take(3).ToList();
            }
            catch (Exception ex) { result.Error = ex.Message; }
            return result;
        }

        void ScanWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            busy = false;
            scanButton.Enabled = true;
            if (e.Error != null) { status.Text = "Помилка сканування: " + e.Error.Message; return; }
            var outcome = e.Result as ScanOutcome;
            if (outcome == null) { status.Text = "Сканування не повернуло результат."; return; }
            if (!string.IsNullOrEmpty(outcome.Error)) { status.Text = "Помилка: " + outcome.Error; return; }
            if (outcome.Top.Count == 0)
            {
                status.Text = "Не знайшов надійного збігу. Спробуй налаштувати область.";
                return;
            }

            var best = outcome.Top[0];
            var second = outcome.Top.Count > 1 ? outcome.Top[1] : null;
            double margin = second == null ? 1.0 : best.Score - second.Score;
            question.Text = best.Item.question ?? "";

            var sb = new StringBuilder();
            for (int i = 0; i < outcome.Top.Count; i++)
            {
                var c = outcome.Top[i];
                sb.Append("#").Append(i + 1).Append(" · ")
                  .Append(Math.Round(c.Score * 100)).Append("% · ")
                  .Append(c.Item.level).Append("\r\n")
                  .Append(c.Item.question).Append("\r\n")
                  .Append("→ ").Append(c.Item.answer).Append("\r\n\r\n");
            }
            matches.Text = sb.ToString();

            bool confident = (best.Score >= 0.72 && margin >= 0.07) || best.Score >= 0.86;
            if (confident)
            {
                answer.Text = best.Item.answer ?? "";
                status.Text = "Впевнений збіг: " + Math.Round(best.Score * 100) + "% · запас " + Math.Round(margin * 100) + "%.";
            }
            else
            {
                answer.Text = "";
                status.Text = "Є схожий збіг, але впевненості недостатньо. Відповідь не показую.";
            }
        }

        IEnumerable<MatchResult> Match(string ocr)
        {
            var fragments = BuildFragments(ocr);
            var list = new List<MatchResult>();
            foreach (var q in database)
            {
                string nq = normalizedQuestions[q];
                double best = 0;
                string bestFragment = "";
                foreach (string f in fragments)
                {
                    double s = Similarity(Normalize(f), nq);
                    if (s > best) { best = s; bestFragment = f; }
                }
                if (best >= 0.28)
                {
                    var m = new MatchResult();
                    m.Item = q; m.Score = best; m.Fragment = bestFragment;
                    list.Add(m);
                }
            }
            return list.OrderByDescending(x => x.Score);
        }

        List<string> BuildFragments(string text)
        {
            var lines = (text ?? "").Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries)
                .Select(x => x.Trim()).Where(x => x.Length >= 4 && x.Length <= 240).ToList();
            var fragments = new List<string>();
            for (int i = 0; i < lines.Count; i++)
            {
                fragments.Add(lines[i]);
                if (i + 1 < lines.Count) fragments.Add(lines[i] + " " + lines[i + 1]);
                if (i + 2 < lines.Count && lines[i].Length + lines[i + 1].Length < 190)
                    fragments.Add(lines[i] + " " + lines[i + 1] + " " + lines[i + 2]);
            }
            if (fragments.Count == 0 && !string.IsNullOrWhiteSpace(text)) fragments.Add(text);
            return fragments.Take(80).ToList();
        }

        static string Normalize(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            s = s.ToLowerInvariant().Replace('ё','е').Replace('ґ','г');
            s = Regex.Replace(s, @"[^\p{L}\p{Nd}]+", " ");
            return Regex.Replace(s, @"\s+", " ").Trim();
        }

        static double Similarity(string seen, string expected)
        {
            if (seen.Length == 0 || expected.Length == 0) return 0;
            if (seen.Contains(expected) || expected.Contains(seen))
            {
                int a = Math.Min(seen.Length, expected.Length), b = Math.Max(seen.Length, expected.Length);
                return Math.Min(1.0, 0.82 + 0.18 * ((double)a / b));
            }

            var st = seen.Split(' ').Where(x => x.Length >= 2).ToArray();
            var et = expected.Split(' ').Where(x => x.Length >= 2).ToArray();
            if (et.Length == 0) return 0;
            double hit = 0, total = 0;
            foreach (string e in et)
            {
                double w = Math.Min(12, Math.Max(2, e.Length));
                total += w;
                bool found = st.Any(x => TokenLike(x, e));
                if (found) hit += w;
            }
            double coverage = total > 0 ? hit / total : 0;
            double lengthPenalty = Math.Min(1.0, (double)Math.Min(seen.Length, expected.Length) / Math.Max(seen.Length, expected.Length));
            return Math.Min(1.0, coverage * 0.88 + lengthPenalty * 0.12);
        }

        static bool TokenLike(string a, string b)
        {
            if (a == b) return true;
            int n = Math.Min(5, Math.Min(a.Length, b.Length));
            if (n >= 4 && a.Substring(0,n) == b.Substring(0,n)) return true;
            return false;
        }

        string RunTesseract(string imagePath)
        {
            string exe, tessdata;
            ResolveTesseract(out exe, out tessdata);
            string outputBase = Path.Combine(ModuleData, "ocr-result");
            string txt = outputBase + ".txt";
            try { if (File.Exists(txt)) File.Delete(txt); } catch { }

            var psi = new ProcessStartInfo();
            psi.FileName = exe;
            psi.Arguments = "\"" + imagePath + "\" \"" + outputBase + "\" --tessdata-dir \"" + tessdata + "\" -l ukr+rus --oem 1 --psm 6";
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardError = true;
            using (var p = Process.Start(psi))
            {
                if (p == null) throw new InvalidOperationException("Не вдалося запустити Tesseract.");
                if (!p.WaitForExit(15000))
                {
                    try { p.Kill(); } catch { }
                    throw new TimeoutException("Tesseract не завершив OCR за 15 секунд.");
                }
                string err = p.StandardError.ReadToEnd();
                if (p.ExitCode != 0) throw new InvalidOperationException("Tesseract exit " + p.ExitCode + ": " + err);
            }
            if (!File.Exists(txt)) throw new FileNotFoundException("Tesseract не створив OCR-результат.");
            return File.ReadAllText(txt, Encoding.UTF8);
        }

        bool OcrReady()
        {
            string exe, data;
            try { ResolveTesseract(out exe, out data); return File.Exists(exe) && File.Exists(Path.Combine(data,"ukr.traineddata")) && File.Exists(Path.Combine(data,"rus.traineddata")); }
            catch { return false; }
        }

        void ResolveTesseract(out string exe, out string data)
        {
            var roots = new List<string>();
            roots.Add(LocalTessRoot);
            string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            if (!string.IsNullOrEmpty(pf)) roots.Add(Path.Combine(pf, "Tesseract-OCR"));
            if (!string.IsNullOrEmpty(pf86)) roots.Add(Path.Combine(pf86, "Tesseract-OCR"));

            foreach (string root in roots.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                string e = Path.Combine(root, "tesseract.exe");
                string d = Path.Combine(root, "tessdata");
                if (File.Exists(e) && Directory.Exists(d) &&
                    File.Exists(Path.Combine(d,"ukr.traineddata")) && File.Exists(Path.Combine(d,"rus.traineddata")))
                { exe = e; data = d; return; }
            }
            throw new FileNotFoundException("Не знайдено Tesseract з мовами ukr+rus.");
        }

        void UpdateOcrStatus()
        {
            if (OcrReady()) status.Text = "OCR готовий · база: Чон-Пон " + QuizData.LoadChonPon().Count + " + КХ " + QuizData.LoadKh().Count + ".";
        }

        void SetupOcr()
        {
            if (busy) return;
            Cursor old = Cursor.Current;
            Cursor.Current = Cursors.WaitCursor;
            ocrButton.Enabled = false;
            try
            {
                Directory.CreateDirectory(LocalTessRoot);
                Directory.CreateDirectory(LocalTessData);

                if (!File.Exists(LocalTessExe))
                {
                    status.Text = "Завантажую Tesseract OCR...";
                    Application.DoEvents();
                    string installer = Path.Combine(Path.GetTempPath(), "CyberPW-Tesseract-Setup.exe");
                    using (var wc = NewWebClient())
                        wc.DownloadFile("https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-setup-5.4.0.20240606.exe", installer);
                    if (!File.Exists(installer) || new FileInfo(installer).Length < 20000000)
                        throw new InvalidDataException("Інсталятор Tesseract завантажився некоректно.");

                    var psi = new ProcessStartInfo(installer);
                    psi.Arguments = "/S /D=" + LocalTessRoot;
                    psi.UseShellExecute = true;
                    var p = Process.Start(psi);
                    if (p == null) throw new InvalidOperationException("Не вдалося запустити інсталятор OCR.");
                    p.WaitForExit();
                    try { File.Delete(installer); } catch { }
                    if (!File.Exists(LocalTessExe)) throw new FileNotFoundException("Після встановлення не знайдено tesseract.exe.");
                }

                DownloadLanguage("ukr");
                DownloadLanguage("rus");
                if (!OcrReady()) throw new InvalidOperationException("OCR встановлено, але мовні файли ukr/rus не знайдено.");
                status.Text = "OCR готовий до роботи.";
                MessageBox.Show("OCR готовий.\r\n\r\nТепер відкрий питання в CyberPW і натисни «СКАНУВАТИ».",
                    "Автовідповіді", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                status.Text = "Не вдалося підготувати OCR.";
                MessageBox.Show("Помилка підготовки OCR:\r\n\r\n" + ex.Message,
                    "Автовідповіді", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            finally { ocrButton.Enabled = true; Cursor.Current = old; }
        }

        WebClient NewWebClient()
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            var wc = new WebClient();
            wc.Headers[HttpRequestHeader.UserAgent] = "CyberPW-Assistant/2";
            return wc;
        }

        void DownloadLanguage(string lang)
        {
            string dest = Path.Combine(LocalTessData, lang + ".traineddata");
            if (File.Exists(dest) && new FileInfo(dest).Length > 500000) return;
            status.Text = "Завантажую OCR-мову: " + lang + "...";
            Application.DoEvents();
            using (var wc = NewWebClient())
                wc.DownloadFile("https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/" + lang + ".traineddata", dest);
            if (!File.Exists(dest) || new FileInfo(dest).Length < 500000)
                throw new InvalidDataException(lang + ".traineddata завантажився некоректно.");
        }

        void SelectRegion()
        {
            var client = clients.SelectedItem as ClientItem;
            if (client == null) { status.Text = "Спочатку вибери клієнт CyberPW."; return; }
            RECT wr;
            if (!GetWindowRect(client.Handle, out wr)) { status.Text = "Не вдалося отримати координати CyberPW."; return; }

            Form host = FindForm();
            bool wasVisible = host != null && host.Visible;
            if (host != null) host.Hide();
            Thread.Sleep(120);
            try
            {
                using (var selector = new RegionSelector(wr))
                {
                    if (selector.ShowDialog() == DialogResult.OK && selector.Selected != null)
                    {
                        SaveRegion(selector.Selected);
                        status.Text = "Область сканування збережено.";
                    }
                    else status.Text = "Налаштування області скасовано.";
                }
            }
            finally
            {
                if (host != null && wasVisible) { host.Show(); host.Activate(); }
            }
        }

        void ResetRegion()
        {
            try { if (File.Exists(RegionPath)) File.Delete(RegionPath); } catch { }
            status.Text = "Увімкнено автоматичну область.";
        }

        void SaveRegion(ScanRegion r)
        {
            Directory.CreateDirectory(ModuleData);
            File.WriteAllText(RegionPath, r.X + ";" + r.Y + ";" + r.W + ";" + r.H, Encoding.UTF8);
        }

        ScanRegion LoadRegion()
        {
            try
            {
                if (!File.Exists(RegionPath)) return null;
                string[] p = File.ReadAllText(RegionPath, Encoding.UTF8).Trim().Split(';');
                if (p.Length != 4) return null;
                var r = new ScanRegion();
                r.X = int.Parse(p[0]); r.Y = int.Parse(p[1]); r.W = int.Parse(p[2]); r.H = int.Parse(p[3]);
                if (r.W < 120 || r.H < 120) return null;
                return r;
            }
            catch { return null; }
        }

        void ShowHelp()
        {
            string text =
                "АВТОВІДПОВІДІ — СУПЕР БЕТА\r\n\r\n" +
                "1. Запусти CyberPW та відкрий персонажа.\r\n" +
                "2. Вибери потрібний PID у верхньому списку.\r\n" +
                "3. На новому ПК один раз натисни «ПІДГОТУВАТИ OCR».\r\n" +
                "4. Натисни «НАЛАШТУВАТИ ОБЛАСТЬ» і виділи тільки коричневе вікно вікторини: питання + всі варіанти відповіді.\r\n" +
                "5. Не захоплюй чат, мінікарту та список квестів.\r\n" +
                "6. Відкрий питання та натисни «СКАНУВАТИ».\r\n\r\n" +
                "Програма показує відповідь лише при достатній впевненості. Якщо збіг сумнівний — поле відповіді лишається порожнім.\r\n\r\n" +
                "«АВТО 1.5 с» повторює сканування, але НІЧОГО не натискає в грі.\r\n" +
                "«АВТО-ОБЛАСТЬ» повертає стандартну область.";
            MessageBox.Show(text, "Автовідповіді — інструкція", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        sealed class RegionSelector : Form
        {
            Point start, current;
            bool dragging;
            public ScanRegion Selected;

            public RegionSelector(RECT wr)
            {
                FormBorderStyle = FormBorderStyle.None;
                StartPosition = FormStartPosition.Manual;
                Bounds = new Rectangle(wr.Left, wr.Top, wr.Right - wr.Left, wr.Bottom - wr.Top);
                TopMost = true;
                ShowInTaskbar = false;
                BackColor = Color.Black;
                Opacity = 0.38;
                Cursor = Cursors.Cross;
                KeyPreview = true;

                var hint = new Label();
                hint.Text = "Затисни ЛКМ у першому куті вікторини та протягни до другого · ESC — скасувати";
                hint.AutoSize = true;
                hint.ForeColor = Color.White;
                hint.BackColor = Color.Black;
                hint.Font = new Font("Segoe UI", 12, FontStyle.Bold);
                hint.Location = new Point(18,18);
                Controls.Add(hint);

                MouseDown += OnDown;
                MouseMove += OnMove;
                MouseUp += OnUp;
                Paint += OnPaintRegion;
                KeyDown += OnKey;
            }

            void OnDown(object sender, MouseEventArgs e)
            {
                if (e.Button != MouseButtons.Left) return;
                start = current = e.Location; dragging = true; Invalidate();
            }

            void OnMove(object sender, MouseEventArgs e)
            {
                if (!dragging) return;
                current = e.Location; Invalidate();
            }

            void OnUp(object sender, MouseEventArgs e)
            {
                if (!dragging || e.Button != MouseButtons.Left) return;
                current = e.Location; dragging = false;
                int x = Math.Min(start.X,current.X), y = Math.Min(start.Y,current.Y);
                int w = Math.Abs(current.X-start.X), h = Math.Abs(current.Y-start.Y);
                if (w < 120 || h < 120)
                {
                    MessageBox.Show("Область замала. Виділи все вікно питання разом із варіантами.", "Автовідповіді");
                    Invalidate(); return;
                }
                Selected = new ScanRegion();
                Selected.X = x; Selected.Y = y; Selected.W = w; Selected.H = h;
                DialogResult = DialogResult.OK;
                Close();
            }

            void OnPaintRegion(object sender, PaintEventArgs e)
            {
                if (!dragging) return;
                int x = Math.Min(start.X,current.X), y = Math.Min(start.Y,current.Y);
                int w = Math.Abs(current.X-start.X), h = Math.Abs(current.Y-start.Y);
                using (var pen = new Pen(Color.Lime,3)) e.Graphics.DrawRectangle(pen,x,y,w,h);
            }

            void OnKey(object sender, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Escape) { DialogResult = DialogResult.Cancel; Close(); }
            }
        }
    }
}
