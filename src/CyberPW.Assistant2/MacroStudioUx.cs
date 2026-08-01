using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class SmoothDataGridView : DataGridView
    {
        public SmoothDataGridView()
        {
            DoubleBuffered = true;
            RowTemplate.Height = 32;
            AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.None;
        }
    }

    internal static class MacroGridUx
    {
        static int dragIndex = -1;
        static Point dragOrigin;

        public static void Attach(DataGridView grid, Action editSelected)
        {
            grid.AllowDrop = true;
            grid.MouseDown += delegate(object sender, MouseEventArgs e)
            {
                DataGridView.HitTestInfo hit = grid.HitTest(e.X, e.Y);
                dragIndex = hit.RowIndex;
                dragOrigin = e.Location;
                if (e.Button == MouseButtons.Right && hit.RowIndex >= 0)
                {
                    grid.ClearSelection(); grid.Rows[hit.RowIndex].Selected = true; grid.CurrentCell = grid.Rows[hit.RowIndex].Cells[1];
                }
            };
            grid.MouseMove += delegate(object sender, MouseEventArgs e)
            {
                if (e.Button != MouseButtons.Left || dragIndex < 0) return;
                Size threshold = SystemInformation.DragSize;
                if (Math.Abs(e.X - dragOrigin.X) < threshold.Width / 2 && Math.Abs(e.Y - dragOrigin.Y) < threshold.Height / 2) return;
                grid.DoDragDrop(dragIndex, DragDropEffects.Move);
            };
            grid.DragOver += delegate(object sender, DragEventArgs e)
            {
                e.Effect = e.Data.GetDataPresent(typeof(int)) ? DragDropEffects.Move : DragDropEffects.None;
                Point client = grid.PointToClient(new Point(e.X, e.Y));
                if (client.Y < grid.ColumnHeadersHeight + 24 && grid.FirstDisplayedScrollingRowIndex > 0)
                    grid.FirstDisplayedScrollingRowIndex--;
                else if (client.Y > grid.ClientSize.Height - 24 && grid.Rows.Count > 0)
                    grid.FirstDisplayedScrollingRowIndex = Math.Min(grid.Rows.Count - 1, grid.FirstDisplayedScrollingRowIndex + 1);
            };
            grid.DragDrop += delegate(object sender, DragEventArgs e)
            {
                if (!e.Data.GetDataPresent(typeof(int))) return;
                int source = (int)e.Data.GetData(typeof(int));
                Point client = grid.PointToClient(new Point(e.X, e.Y));
                int target = grid.HitTest(client.X, client.Y).RowIndex;
                if (target < 0) target = grid.Rows.Count - 1;
                Move(grid, source, target);
                dragIndex = -1;
            };
            grid.DoubleClick += delegate { editSelected(); };
            grid.KeyDown += delegate(object sender, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Enter) { editSelected(); e.Handled = true; }
                else if (e.Control && e.KeyCode == Keys.D) { Duplicate(grid); e.Handled = true; }
                else if (e.KeyCode == Keys.Delete && grid.CurrentRow != null) { grid.Rows.Remove(grid.CurrentRow); e.Handled = true; }
            };

            var menu = new ContextMenuStrip();
            var edit = new ToolStripMenuItem("Змінити дію…"); edit.Click += delegate { editSelected(); };
            var duplicate = new ToolStripMenuItem("Дублювати"); duplicate.Click += delegate { Duplicate(grid); };
            var remove = new ToolStripMenuItem("Видалити"); remove.Click += delegate { if (grid.CurrentRow != null) grid.Rows.Remove(grid.CurrentRow); };
            menu.Items.Add(edit); menu.Items.Add(duplicate); menu.Items.Add(new ToolStripSeparator()); menu.Items.Add(remove);
            grid.ContextMenuStrip = menu;
        }

        static void Move(DataGridView grid, int source, int target)
        {
            if (source < 0 || source >= grid.Rows.Count || target < 0 || source == target) return;
            object[] values = Values(grid.Rows[source]);
            grid.SuspendLayout();
            try
            {
                grid.Rows.RemoveAt(source);
                if (target > source) target--;
                target = Math.Max(0, Math.Min(target, grid.Rows.Count));
                grid.Rows.Insert(target, values);
                grid.ClearSelection(); grid.Rows[target].Selected = true; grid.CurrentCell = grid.Rows[target].Cells[1];
            }
            finally { grid.ResumeLayout(); }
        }

        static void Duplicate(DataGridView grid)
        {
            if (grid.CurrentRow == null) return;
            int target = grid.CurrentRow.Index + 1;
            grid.Rows.Insert(target, Values(grid.CurrentRow));
            grid.ClearSelection(); grid.Rows[target].Selected = true; grid.CurrentCell = grid.Rows[target].Cells[1];
        }

        static object[] Values(DataGridViewRow row)
        { return new[] { row.Cells[0].Value, row.Cells[1].Value, row.Cells[2].Value }; }
    }

    internal sealed class MacroActionDialog : Form
    {
        readonly ComboBox command = new ComboBox();
        readonly TextBox argument = new TextBox();
        readonly Label help = new Label();
        public string Command { get { return Convert.ToString(command.SelectedItem); } }
        public string Argument { get { return argument.Text.Trim(); } }
        public string Description { get { return Describe(Command); } }

        static readonly string[] Commands = { "KEY", "KEYDOWN", "KEYUP", "WAIT", "TEXT", "CLICK", "MOVE", "WHEEL", "WAITCOLOR", "IFCOLOR", "IFNOTCOLOR", "ENDIF", "WHILECOLOR", "WHILENOTCOLOR", "ENDWHILE", "FOREVER", "ENDFOREVER", "REPEAT", "END" };

        public MacroActionDialog(string currentCommand, string currentArgument)
        {
            Text = "Змінити дію макросу"; ClientSize = new Size(520, 260); MinimumSize = new Size(520, 260);
            StartPosition = FormStartPosition.CenterParent; BackColor = Theme.Ink; ForeColor = Theme.Text; Font = new Font("Segoe UI", 10);
            var title = Theme.Label("ВЛАСТИВОСТІ ДІЇ", 16, Theme.GoldSoft, FontStyle.Bold); title.SetBounds(20, 15, 470, 34); Controls.Add(title);
            var commandLabel = Theme.Label("Команда", 9, Theme.Muted, FontStyle.Bold); commandLabel.SetBounds(22, 60, 120, 22); Controls.Add(commandLabel);
            command.SetBounds(20, 84, 185, 31); command.DropDownStyle = ComboBoxStyle.DropDownList; command.BackColor = Theme.Panel2; command.ForeColor = Theme.Text;
            command.Items.AddRange(Commands); command.SelectedItem = Array.IndexOf(Commands, (currentCommand ?? "").ToUpperInvariant()) >= 0 ? currentCommand.ToUpperInvariant() : "WAIT"; Controls.Add(command);
            var argumentLabel = Theme.Label("Значення", 9, Theme.Muted, FontStyle.Bold); argumentLabel.SetBounds(225, 60, 270, 22); Controls.Add(argumentLabel);
            argument.SetBounds(223, 84, 275, 31); argument.Text = currentArgument ?? ""; argument.BackColor = Theme.Panel2; argument.ForeColor = Theme.Text; Controls.Add(argument);
            help.SetBounds(20, 130, 478, 52); help.ForeColor = Theme.Muted; help.BackColor = Color.Transparent; Controls.Add(help);
            var ok = Theme.Button("ЗБЕРЕГТИ"); ok.SetBounds(278, 202, 105, 38); ok.DialogResult = DialogResult.OK; Controls.Add(ok);
            var cancel = Theme.Button("СКАСУВАТИ"); cancel.SetBounds(393, 202, 105, 38); cancel.DialogResult = DialogResult.Cancel; Controls.Add(cancel);
            AcceptButton = ok; CancelButton = cancel; command.SelectedIndexChanged += delegate { RefreshHelp(); }; RefreshHelp();
        }

        void RefreshHelp()
        {
            string c = Command;
            help.Text = Format(c);
            if (c == "ENDIF" || c == "ENDWHILE" || c == "ENDFOREVER" || c == "FOREVER" || c == "END") { argument.Text = ""; argument.Enabled = false; }
            else argument.Enabled = true;
        }

        static string Format(string c)
        {
            switch (c)
            {
                case "KEY": case "KEYDOWN": case "KEYUP": return "Клавіша: Tab, F3, Y, D5, Space тощо.";
                case "WAIT": return "Пауза у мілісекундах, наприклад 200.";
                case "TEXT": return "Текст, який потрібно ввести.";
                case "CLICK": return "LEFT, RIGHT або MIDDLE.";
                case "MOVE": return "Координати курсора: X Y.";
                case "WHEEL": return "Прокрутка: 120 вгору або -120 вниз.";
                case "WAITCOLOR": return "X Y колір допуск тайм-аут: 700 30 2785376 2 10000.";
                case "IFCOLOR": case "IFNOTCOLOR": case "WHILECOLOR": case "WHILENOTCOLOR": return "X Y колір [допуск]: 700 30 2785376 2.";
                case "FOREVER": return "Runs until Stop is pressed."; case "REPEAT": return "Кількість повторів від 1 до 1000.";
                default: return "Завершальна команда не має значення.";
            }
        }

        internal static string Describe(string c)
        {
            switch (c)
            {
                case "KEY": return "Натиснути клавішу"; case "KEYDOWN": return "Затиснути клавішу"; case "KEYUP": return "Відпустити клавішу";
                case "WAIT": return "Пауза, мс"; case "TEXT": return "Ввести текст"; case "CLICK": return "Клік миші"; case "MOVE": return "Перемістити курсор"; case "WHEEL": return "Прокрутити колесо";
                case "WAITCOLOR": return "Чекати появи кольору"; case "IFCOLOR": return "Якщо колір збігається"; case "IFNOTCOLOR": return "Якщо колір НЕ збігається";
                case "WHILECOLOR": return "Поки колір збігається"; case "WHILENOTCOLOR": return "Поки колір НЕ збігається"; case "ENDWHILE": return "Кінець WHILE";
                case "FOREVER": return "Infinite loop start"; case "ENDFOREVER": return "Infinite loop end"; case "ENDIF": return "End IF"; case "REPEAT": return "Початок повтору"; case "END": return "Кінець повтору"; default: return c;
            }
        }
    }
}
