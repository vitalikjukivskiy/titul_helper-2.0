using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class TitlesPage : UserControl, IModulePage
    {
        private readonly TextBox _search;
        private readonly ListBox _list;
        private readonly Label _name;
        private readonly Label _chain;
        private readonly Label _coordinates;
        private readonly TextBox _details;
        private readonly CheckBox _received;
        private readonly Label _progress;
        private readonly Button _sync;
        private List<TitleRecord> _titles = new List<TitleRecord>();
        private List<TitleRecord> _filtered = new List<TitleRecord>();
        private TitleState _state = new TitleState();
        private bool _updating;

        public string Title { get { return "TitulHelper"; } }

        public TitlesPage()
        {
            BackColor = Theme.Ink;
            BackgroundImage = AssetImages.Load("main-summer.jpg");
            BackgroundImageLayout = ImageLayout.Stretch;

            var left = new Panel { Dock = DockStyle.Left, Width = 410, Padding = new Padding(12), BackColor = Theme.Panel };
            var right = new Panel { Dock = DockStyle.Fill, Padding = new Padding(24), BackColor = Theme.Ink };
            Controls.Add(right);
            Controls.Add(left);

            var searchLabel = Theme.Label("ПОШУК ТИТУЛУ", 9F, Theme.GoldSoft, FontStyle.Bold);
            searchLabel.Location = new Point(12, 12);
            left.Controls.Add(searchLabel);
            _search = new TextBox
            {
                Location = new Point(12, 39),
                Width = 374,
                Height = 30,
                BackColor = Theme.Panel2,
                ForeColor = Theme.Text,
                BorderStyle = BorderStyle.FixedSingle,
                Font = new Font("Segoe UI", 10F)
            };
            _search.TextChanged += delegate { RefreshList(); };
            left.Controls.Add(_search);

            _list = new ListBox
            {
                Location = new Point(12, 80),
                Size = new Size(374, 530),
                Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right,
                BackColor = Theme.Panel2,
                ForeColor = Theme.Text,
                BorderStyle = BorderStyle.FixedSingle,
                Font = new Font("Segoe UI", 10F),
                IntegralHeight = false
            };
            _list.SelectedIndexChanged += delegate { UpdateSelection(); };
            left.Controls.Add(_list);

            _progress = Theme.Label("Отримано: 0 / 0", 10F, Theme.GoldSoft, FontStyle.Bold);
            _progress.Location = new Point(12, 625);
            _progress.Anchor = AnchorStyles.Left | AnchorStyles.Bottom;
            left.Controls.Add(_progress);

            _name = Theme.Label("Оберіть титул", 23F, Theme.GoldSoft, FontStyle.Bold);
            _name.Location = new Point(24, 20);
            right.Controls.Add(_name);
            _chain = Theme.Label("", 10F, Theme.Cyan, FontStyle.Bold);
            _chain.Location = new Point(27, 70);
            right.Controls.Add(_chain);
            _coordinates = Theme.Label("", 13F, Theme.GoldSoft, FontStyle.Bold);
            _coordinates.Location = new Point(27, 104);
            right.Controls.Add(_coordinates);

            _received = new CheckBox
            {
                Text = "Титул уже отримано",
                Location = new Point(28, 145),
                AutoSize = true,
                ForeColor = Theme.Text,
                BackColor = Color.Transparent,
                Font = new Font("Segoe UI", 10F)
            };
            _received.CheckedChanged += ReceivedChanged;
            right.Controls.Add(_received);

            _details = new TextBox
            {
                Location = new Point(27, 188),
                Size = new Size(610, 250),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right,
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                BackColor = Theme.Panel,
                ForeColor = Theme.Text,
                BorderStyle = BorderStyle.FixedSingle,
                Font = new Font("Segoe UI", 10F)
            };
            right.Controls.Add(_details);

            var copy = Theme.Button("СКОПІЮВАТИ КООРДИНАТИ");
            copy.SetBounds(27, 458, 190, 46);
            copy.Click += delegate
            {
                TitleRecord selected = Selected;
                if (selected != null) Clipboard.SetText(selected.x + " " + selected.y);
            };
            right.Controls.Add(copy);

            var inject = Theme.Button("ПОСТАВИТИ МІТКУ В CYBERPW");
            inject.SetBounds(230, 458, 407, 46);
            inject.Click += delegate { try { TitleCoordinateService.Inject(FindForm(), Selected, _state.config); } catch (Exception exception) { MessageBox.Show(exception.Message, "TitulHelper"); } finally { FindForm().WindowState=FormWindowState.Normal;FindForm().Activate(); } };
            right.Controls.Add(inject);
            var setup = Theme.Button("⚙ НАЛАШТУВАТИ КООРДИНАТИ");
            setup.SetBounds(27, 518, 610, 46);
            setup.Click += delegate { using(var dialog=new CoordinateSetupDialog(_state.config)) if(dialog.ShowDialog(FindForm())==DialogResult.OK) JsonFiles.Write(AppPaths.State,_state); };
            right.Controls.Add(setup);

            _sync = Theme.Button("СИНХРОНІЗУВАТИ З КЛІЄНТОМ");
            _sync.SetBounds(27, 578, 610, 46);
            _sync.Click += delegate { SynchronizeWithClient(); };
            right.Controls.Add(_sync);

            var status = Theme.Label("2.0 (BETA) · СУМІСНО З ДАНИМИ 1.07", 9F, Theme.Muted, FontStyle.Bold);
            status.Location = new Point(29, 642);
            right.Controls.Add(status);

            LoadData();
        }

        private TitleRecord Selected
        {
            get
            {
                int index = _list.SelectedIndex;
                return index >= 0 && index < _filtered.Count ? _filtered[index] : null;
            }
        }

        private void LoadData()
        {
            try
            {
                _titles = JsonFiles.Read<List<TitleRecord>>(AppPaths.Titles) ?? new List<TitleRecord>();
                if (File.Exists(AppPaths.State))
                    _state = JsonFiles.Read<TitleState>(AppPaths.State) ?? new TitleState();
                if (_state.done == null) _state.done = new Dictionary<string, bool>();
                if (_state.config == null) _state.config = new Dictionary<string, object>();
                RefreshList();
            }
            catch (Exception exception)
            {
                MessageBox.Show("Не вдалося завантажити TitulHelper:\n" + exception.Message, "CyberPW Assistant");
            }
        }

        private void RefreshList()
        {
            string query = _search.Text.Trim();
            _filtered = string.IsNullOrEmpty(query)
                ? new List<TitleRecord>(_titles)
                : _titles.Where(t =>
                    Contains(t.name, query) ||
                    Contains(t.chain, query) ||
                    Contains(t.task, query) ||
                    Contains(t.note, query)).ToList();

            int selectedId = Selected == null ? -1 : Selected.clientTitleId;
            _list.BeginUpdate();
            _list.Items.Clear();
            foreach (TitleRecord title in _filtered)
            {
                bool done;
                _state.done.TryGetValue(title.id, out done);
                _list.Items.Add((done ? "✓  " : "   ") + title.name);
            }
            _list.EndUpdate();
            int restore = _filtered.FindIndex(t => t.clientTitleId == selectedId);
            if (_filtered.Count > 0) _list.SelectedIndex = restore >= 0 ? restore : 0;
            UpdateProgress();
        }

        private static bool Contains(string source, string query)
        {
            return !string.IsNullOrEmpty(source) && source.IndexOf(query, StringComparison.CurrentCultureIgnoreCase) >= 0;
        }

        private void UpdateSelection()
        {
            TitleRecord selected = Selected;
            _updating = true;
            try
            {
                if (selected == null)
                {
                    _name.Text = "Нічого не знайдено";
                    _chain.Text = "";
                    _coordinates.Text = "";
                    _details.Text = "";
                    _received.Checked = false;
                    return;
                }

                bool done;
                _state.done.TryGetValue(selected.id, out done);
                _name.Text = selected.name;
                _chain.Text = selected.chain ?? "";
                _coordinates.Text = "Координати: " + selected.x + " " + selected.y;
                _details.Text = (selected.task ?? "") + Environment.NewLine + Environment.NewLine + (selected.note ?? "");
                _received.Checked = done;
            }
            finally { _updating = false; }
        }

        private void ReceivedChanged(object sender, EventArgs eventArgs)
        {
            if (_updating) return;
            TitleRecord selected = Selected;
            if (selected == null) return;
            _state.done[selected.id] = _received.Checked;
            try
            {
                JsonFiles.Write(AppPaths.State, _state);
                int index = _list.SelectedIndex;
                RefreshList();
                if (index >= 0 && index < _list.Items.Count) _list.SelectedIndex = index;
            }
            catch (Exception exception)
            {
                MessageBox.Show("Не вдалося зберегти прогрес:\n" + exception.Message, "CyberPW Assistant");
            }
        }

        private void UpdateProgress()
        {
            int done = _titles.Count(t =>
            {
                bool value;
                return _state.done.TryGetValue(t.id, out value) && value;
            });
            _progress.Text = "Отримано: " + done + " / " + _titles.Count;
        }

        private void SynchronizeWithClient()
        {
            _sync.Enabled = false;
            try
            {
                List<System.Diagnostics.Process> clients = TitleMemoryService.FindClients("ElementClient");
                if (clients.Count == 0)
                    throw new InvalidOperationException("ElementClient не знайдено. Запустіть гру та зайдіть персонажем.");

                System.Diagnostics.Process selected;
                if (clients.Count == 1)
                {
                    selected = clients[0];
                }
                else
                {
                    using (var dialog = new ClientSelectionDialog(clients))
                    {
                        if (dialog.ShowDialog(FindForm()) != DialogResult.OK) return;
                        selected = dialog.SelectedProcess;
                    }
                }
                if (selected == null) return;

                OwnedTitlesResult result = TitleMemoryService.Read(selected);
                int matched = 0;
                foreach (TitleRecord title in _titles)
                {
                    if (title.clientTitleId <= 0) continue;
                    bool owned = result.Ids.Contains(title.clientTitleId);
                    _state.done[title.id] = owned;
                    if (owned) matched++;
                }
                JsonFiles.Write(AppPaths.State, _state);
                RefreshList();
                MessageBox.Show(
                    "Синхронізацію завершено.\n\n" +
                    "Знайдено у базі: " + matched + "\n" +
                    "ID у клієнті: " + result.RawCount + "\n" +
                    "ElementClient PID: " + result.ProcessId,
                    "TitulHelper — готово",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
            catch (Exception exception)
            {
                MessageBox.Show(
                    "Не вдалося синхронізувати титули.\n\n" + exception.Message +
                    "\n\nПереконайтеся, що персонаж уже зайшов у світ.",
                    "TitulHelper",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
            }
            finally
            {
                _sync.Enabled = true;
            }
        }

        public void OnActivated()
        {
            UpdateProgress();
        }
    }
}
