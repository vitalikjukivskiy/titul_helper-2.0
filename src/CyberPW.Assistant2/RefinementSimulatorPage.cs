using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal enum RefineMethod { Mirage, Underworld, Heaven, Creation, Dragon }

    internal sealed class RefineMaterial
    {
        public RefineMethod Method;
        public string Name;
        public string ShortName;
        public Color Color;
        public string IconFile;
        public override string ToString() { return Name; }
    }

    internal sealed class RefineEquipment
    {
        public int Index;
        public int Level;
        public string Name;
        public string IconFile;
    }

    internal sealed class RefinementSimulatorPage : UserControl, IModulePage
    {
        static readonly double[] BaseChance = { .50, .30, .30, .30, .30, .30, .30, .30, .25, .20, .12, .05 };
        static readonly int[] DragonScale = { 1, 4, 10, 25, 60, 130, 215, 405, 750, 1370, 2525, 4645 };
        readonly Random random = new Random();
        readonly List<RefineMaterial> materials = new List<RefineMaterial>();
        readonly Dictionary<RefineMethod, int> stock = new Dictionary<RefineMethod, int>();
        readonly List<MaterialSlot> slots = new List<MaterialSlot>();
        readonly List<RefineEquipment> equipment = new List<RefineEquipment>();
        readonly List<EquipmentInventorySlot> equipmentSlots = new List<EquipmentInventorySlot>();
        readonly NumericUpDown startLevel = new NumericUpDown(), targetLevel = new NumericUpDown(), stockEditor = new NumericUpDown();
        readonly ComboBox equipmentType = new ComboBox();
        readonly Label itemLevel, chanceLabel, methodLabel, stockName, statistics, resultLabel;
        readonly ListBox history = new ListBox();
        RefineMaterial selected;
        RefineEquipment selectedEquipment;
        bool changingEquipment;
        int current, attempts, successes, failures, miragesSpent;
        public string Title { get { return "Заточка"; } }

        public RefinementSimulatorPage()
        {
            BackColor = Color.FromArgb(21, 17, 11);
            materials.Add(new RefineMaterial { Method = RefineMethod.Mirage, Name = "Камінь безсмертних", ShortName = "М", Color = Color.FromArgb(55, 135, 255), IconFile = "mirage.png" });
            materials.Add(new RefineMaterial { Method = RefineMethod.Underworld, Name = "Підземний камінь", ShortName = "П", Color = Color.FromArgb(188, 60, 220), IconFile = "underworld.png" });
            materials.Add(new RefineMaterial { Method = RefineMethod.Heaven, Name = "Небесний камінь", ShortName = "Н", Color = Color.FromArgb(45, 195, 255), IconFile = "heaven.png" });
            materials.Add(new RefineMaterial { Method = RefineMethod.Creation, Name = "Камінь світобудови", ShortName = "С", Color = Color.FromArgb(90, 220, 135), IconFile = "creation.png" });
            materials.Add(new RefineMaterial { Method = RefineMethod.Dragon, Name = "Кулька дракона", ShortName = "Д", Color = Color.FromArgb(255, 180, 40), IconFile = "dragon.png" });
            foreach (RefineMaterial material in materials) stock[material.Method] = material.Method == RefineMethod.Mirage ? 9999 : 999;
            selected = materials[0];
            for (int i = 0; i < 10; i++) equipment.Add(new RefineEquipment { Index = i, Level = i == 0 ? 7 : 0, Name = i == 0 ? "Основна шмотка" : "Підмінна шмотка " + i, IconFile = "equipment-" + (i + 1).ToString("D2") + ".png" });
            selectedEquipment = equipment[0]; current = selectedEquipment.Level;

            var title = GameLabel("СИМУЛЯТОР ЗАТОЧКИ · BETA", 23, Color.FromArgb(242, 210, 114), FontStyle.Bold);
            title.SetBounds(22, 8, 520, 36); Controls.Add(title);
            var subtitle = GameLabel("Ігрова симуляція шансів +1…+12 · результати випадкові", 9, Color.FromArgb(184, 173, 142), FontStyle.Regular);
            subtitle.SetBounds(24, 42, 560, 24); Controls.Add(subtitle);

            var forge = PanelCard(22, 72, 405, 548);
            Controls.Add(forge);
            var forgeTitle = GameLabel("ПОКРАЩИТИ СПОРЯДЖЕННЯ", 15, Color.FromArgb(230, 205, 145), FontStyle.Bold);
            forgeTitle.SetBounds(38, 12, 330, 28); forge.Controls.Add(forgeTitle);

            var itemSlot = new EquipmentSlot(selectedEquipment); itemSlot.Name = "MainEquipmentSlot"; itemSlot.SetBounds(28, 54, 88, 88); forge.Controls.Add(itemSlot);
            var itemName = GameLabel(selectedEquipment.Name, 12, Color.FromArgb(244, 225, 163), FontStyle.Bold); itemName.Name = "RefineItemName";
            itemName.SetBounds(132, 60, 238, 24); forge.Controls.Add(itemName);
            itemLevel = GameLabel("Поточна заточка: +0", 15, Color.FromArgb(255, 201, 72), FontStyle.Bold);
            itemLevel.SetBounds(132, 88, 250, 28); forge.Controls.Add(itemLevel);
            resultLabel = GameLabel("Результат: здоров'я +40", 9, Color.FromArgb(120, 230, 125), FontStyle.Regular);
            resultLabel.SetBounds(132, 119, 250, 22); forge.Controls.Add(resultLabel);

            var typeText = GameLabel("СПОРЯДЖЕННЯ", 8, Color.FromArgb(196, 178, 128), FontStyle.Bold);
            typeText.SetBounds(28, 158, 160, 20); forge.Controls.Add(typeText);
            equipmentType.SetBounds(28, 180, 170, 28); SetupCombo(equipmentType);
            equipmentType.Items.AddRange(new object[] { "Броня / біжутерія", "Зброя" }); equipmentType.SelectedIndex = 0; forge.Controls.Add(equipmentType);
            var startText = GameLabel("СТАРТ", 8, Color.FromArgb(196, 178, 128), FontStyle.Bold); startText.SetBounds(216, 158, 70, 20); forge.Controls.Add(startText);
            SetupLevel(startLevel, 216, 180, 70); startLevel.Value = current; startLevel.ValueChanged += delegate { if (!changingEquipment) { current = (int)startLevel.Value; selectedEquipment.Level = current; UpdateUi(); } }; forge.Controls.Add(startLevel);
            var targetText = GameLabel("ЦІЛЬ", 8, Color.FromArgb(196, 178, 128), FontStyle.Bold); targetText.SetBounds(302, 158, 70, 20); forge.Controls.Add(targetText);
            SetupLevel(targetLevel, 302, 180, 70); targetLevel.Minimum = 1; targetLevel.Value = 12; forge.Controls.Add(targetLevel);

            var materialText = GameLabel("ОСОБЛИВИЙ МАТЕРІАЛ", 8, Color.FromArgb(196, 178, 128), FontStyle.Bold);
            materialText.SetBounds(28, 224, 220, 20); forge.Controls.Add(materialText);
            var selectedCrystal = new CrystalBadge(selected.Color, selected.ShortName, string.IsNullOrEmpty(selected.IconFile) ? null : AssetImages.Load("refinement-icons", selected.IconFile)); selectedCrystal.Name = "SelectedCrystal"; selectedCrystal.SetBounds(28, 249, 56, 56); forge.Controls.Add(selectedCrystal);
            methodLabel = GameLabel(selected.Name, 11, Color.White, FontStyle.Bold); methodLabel.SetBounds(98, 252, 275, 24); forge.Controls.Add(methodLabel);
            chanceLabel = GameLabel("Шанс наступного рівня: 50,00%", 9, Color.FromArgb(95, 235, 230), FontStyle.Bold);
            chanceLabel.SetBounds(98, 280, 275, 22); forge.Controls.Add(chanceLabel);

            history.SetBounds(28, 322, 344, 112); history.BackColor = Color.FromArgb(16, 14, 10); history.ForeColor = Color.FromArgb(222, 210, 175);
            history.BorderStyle = BorderStyle.FixedSingle; history.Font = new Font("Segoe UI", 8); forge.Controls.Add(history);
            var one = GameButton("ЗАТОЧИТИ"); one.SetBounds(28, 451, 162, 44); one.Click += delegate { Attempt(true); }; forge.Controls.Add(one);
            var toTarget = GameButton("ДО ЦІЛІ"); toTarget.SetBounds(210, 451, 162, 44); toTarget.Click += delegate { RunToTarget(); }; forge.Controls.Add(toTarget);
            var reset = GameButton("СКИНУТИ СПРОБИ"); reset.SetBounds(28, 505, 344, 32); reset.Click += delegate { ResetRun(); }; forge.Controls.Add(reset);

            var backpack = PanelCard(445, 72, 561, 338); Controls.Add(backpack);
            var bagTitle = GameLabel("РЮКЗАК", 16, Color.FromArgb(230, 205, 145), FontStyle.Bold); bagTitle.SetBounds(22, 10, 180, 28); backpack.Controls.Add(bagTitle);
            var bagHint = GameLabel("Міраж витрачається завжди · вибраний камінь — додатково", 8, Color.FromArgb(184, 173, 142), FontStyle.Regular);
            bagHint.SetBounds(205, 14, 330, 22); backpack.Controls.Add(bagHint);
            for (int i = 0; i < materials.Count; i++)
            {
                var slot = new MaterialSlot(materials[i]); slot.SetBounds(22 + i * 104, 54, 92, 104);
                slot.Click += MaterialClicked; slots.Add(slot); backpack.Controls.Add(slot);
            }
            stockName = GameLabel("ЗАПАС: " + selected.Name, 9, Color.FromArgb(230, 205, 145), FontStyle.Bold);
            stockName.SetBounds(22, 182, 310, 22); backpack.Controls.Add(stockName);
            stockEditor.SetBounds(22, 207, 150, 31); stockEditor.Minimum = 0; stockEditor.Maximum = 1000000; stockEditor.Value = stock[selected.Method];
            stockEditor.BackColor = Color.FromArgb(35, 30, 21); stockEditor.ForeColor = Color.White; stockEditor.ValueChanged += StockChanged; backpack.Controls.Add(stockEditor);
            var add100 = GameButton("+100"); add100.SetBounds(184, 204, 98, 36); add100.Click += delegate { stockEditor.Value = Math.Min(stockEditor.Maximum, stockEditor.Value + 100); }; backpack.Controls.Add(add100);
            var fill = GameButton("ЗАПОВНИТИ"); fill.SetBounds(294, 204, 132, 36); fill.Click += delegate { stockEditor.Value = 9999; }; backpack.Controls.Add(fill);
            var equipmentTitle = GameLabel("ШМОТКИ ДЛЯ ПІДМІНИ · ЛКМ ЩОБ ВСТАВИТИ", 8, Color.FromArgb(230, 205, 145), FontStyle.Bold);
            equipmentTitle.SetBounds(22, 249, 500, 18); backpack.Controls.Add(equipmentTitle);
            for (int i = 0; i < equipment.Count; i++)
            {
                var equipmentSlot = new EquipmentInventorySlot(equipment[i]); equipmentSlot.SetBounds(22 + i * 51, 271, 47, 58);
                equipmentSlot.Selected = equipment[i] == selectedEquipment; equipmentSlot.Click += EquipmentClicked;
                equipmentSlots.Add(equipmentSlot); backpack.Controls.Add(equipmentSlot);
            }

            var statsPanel = PanelCard(445, 426, 561, 194); Controls.Add(statsPanel);
            var statsTitle = GameLabel("СТАТИСТИКА СЕСІЇ", 13, Color.FromArgb(230, 205, 145), FontStyle.Bold); statsTitle.SetBounds(22, 12, 250, 26); statsPanel.Controls.Add(statsTitle);
            statistics = GameLabel("Спроб: 0\nУспіхів: 0   Невдач: 0\nВитрачено міражів: 0", 12, Color.White, FontStyle.Bold);
            statistics.SetBounds(22, 50, 285, 90); statistics.AutoSize = false; statsPanel.Controls.Add(statistics);
            var rules = GameLabel("ВИТРАТИ Й НЕВДАЧА\nМіраж: завжди 1 (зброя — 2)\nОсобливий камінь: додатково 1\nМіраж / небесний: скидання до +0\nПідземний: −1 · Світобудова: без втрат\nКулька дракона: 1 шт. · 100%", 8, Color.FromArgb(195, 224, 196), FontStyle.Regular);
            rules.SetBounds(310, 46, 230, 125); rules.AutoSize = false; statsPanel.Controls.Add(rules);

            foreach (MaterialSlot slot in slots) slot.Selected = slot.Material == selected;
            UpdateUi();
        }

        static Panel PanelCard(int x, int y, int width, int height)
        {
            var panel = new CardPanel { BackColor = Color.FromArgb(235, 40, 34, 23) }; panel.SetBounds(x, y, width, height); return panel;
        }
        static Label GameLabel(string text, float size, Color color, FontStyle style)
        {
            return new Label { Text = text, AutoSize = false, BackColor = Color.Transparent, ForeColor = color, Font = new Font("Segoe UI", size, style) };
        }
        static Button GameButton(string text)
        {
            var button = Theme.Button(text); button.BackColor = Color.FromArgb(95, 72, 28); button.ForeColor = Color.FromArgb(255, 224, 145); return button;
        }
        static void SetupCombo(ComboBox combo) { combo.DropDownStyle = ComboBoxStyle.DropDownList; combo.BackColor = Color.FromArgb(35, 30, 21); combo.ForeColor = Color.White; }
        static void SetupLevel(NumericUpDown box, int x, int y, int width)
        {
            box.SetBounds(x, y, width, 28); box.Minimum = 0; box.Maximum = 12; box.BackColor = Color.FromArgb(35, 30, 21); box.ForeColor = Color.White; box.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        }

        void MaterialClicked(object sender, EventArgs e)
        {
            var slot = sender as MaterialSlot; if (slot == null) return;
            selected = slot.Material;
            foreach (MaterialSlot item in slots) item.Selected = item == slot;
            stockEditor.ValueChanged -= StockChanged; stockEditor.Value = Math.Max(stockEditor.Minimum, Math.Min(stockEditor.Maximum, stock[selected.Method])); stockEditor.ValueChanged += StockChanged;
            stockName.Text = "ЗАПАС: " + selected.Name;
            var badge = Controls.Find("SelectedCrystal", true).FirstOrDefault() as CrystalBadge;
            if (badge != null) { badge.BadgeColor = selected.Color; badge.Letter = selected.ShortName; badge.IconImage = string.IsNullOrEmpty(selected.IconFile) ? null : AssetImages.Load("refinement-icons", selected.IconFile); badge.Invalidate(); }
            UpdateUi();
        }
        void StockChanged(object sender, EventArgs e) { stock[selected.Method] = (int)stockEditor.Value; RefreshSlots(); }
        void EquipmentClicked(object sender, EventArgs e)
        {
            var slot = sender as EquipmentInventorySlot; if (slot == null || slot.Equipment == selectedEquipment) return;
            selectedEquipment.Level = current; selectedEquipment = slot.Equipment; current = selectedEquipment.Level;
            changingEquipment = true; startLevel.Value = current; changingEquipment = false;
            foreach (EquipmentInventorySlot item in equipmentSlots) item.Selected = item == slot;
            var mainSlot = Controls.Find("MainEquipmentSlot", true).FirstOrDefault() as EquipmentSlot;
            if (mainSlot != null) mainSlot.SetEquipment(selectedEquipment);
            AddHistory("Вставлено: " + selectedEquipment.Name + " +" + current, Color.FromArgb(110, 220, 235)); UpdateUi();
        }

        int MirageCost() { return equipmentType.SelectedIndex == 1 ? 2 : 1; }
        double Chance(int level, RefineMethod method)
        {
            if (level < 0 || level >= 12) return 0;
            if (method == RefineMethod.Underworld) return Math.Min(1, BaseChance[level] + .035);
            if (method == RefineMethod.Heaven) return Math.Min(1, BaseChance[level] + .15);
            if (method == RefineMethod.Creation) return 1.0 / DragonScale[level];
            if (method == RefineMethod.Dragon) return 1;
            return BaseChance[level];
        }

        bool CanSpend()
        {
            int mirages = MirageCost();
            if (stock[RefineMethod.Mirage] < mirages) { AddHistory("Немає міражів для спроби.", Color.OrangeRed); return false; }
            if (selected.Method != RefineMethod.Mirage && stock[selected.Method] < 1) { AddHistory("Закінчився матеріал: " + selected.Name, Color.OrangeRed); return false; }
            return true;
        }

        bool Attempt(bool refresh)
        {
            if (current >= 12) { if (refresh) AddHistory("Досягнуто максимальної заточки +12.", Color.Gold); return false; }
            if (!CanSpend()) { if (refresh) UpdateUi(); return false; }
            int before = current, mirages = MirageCost();
            stock[RefineMethod.Mirage] -= mirages; miragesSpent += mirages;
            if (selected.Method != RefineMethod.Mirage) stock[selected.Method]--;
            attempts++;
            bool success = random.NextDouble() < Chance(before, selected.Method);
            if (success) { current++; successes++; }
            else
            {
                failures++;
                if (selected.Method == RefineMethod.Underworld) current = Math.Max(0, current - 1);
                else if (selected.Method != RefineMethod.Creation) current = 0;
            }
            selectedEquipment.Level = current;
            AddHistory("#" + (selectedEquipment.Index + 1) + "  +" + before + " → " + (success ? "УСПІХ" : "НЕВДАЧА") + " → +" + current, success ? Color.FromArgb(110, 245, 125) : Color.FromArgb(255, 120, 95));
            if (refresh) UpdateUi();
            return true;
        }

        void RunToTarget()
        {
            int target = (int)targetLevel.Value;
            if (target <= current) { AddHistory("Ціль повинна бути вищою за поточний рівень.", Color.Gold); return; }
            int guard = 0;
            while (current < target && guard++ < 100000)
            {
                if (!Attempt(false)) break;
            }
            if (guard >= 100000 && current < target) AddHistory("Зупинка після 100 000 спроб.", Color.OrangeRed);
            UpdateUi();
        }

        void ResetRun()
        {
            current = (int)startLevel.Value; selectedEquipment.Level = current; attempts = successes = failures = miragesSpent = 0; history.Items.Clear();
            AddHistory("Нова сесія зі стартової заточки +" + current + ".", Color.FromArgb(110, 220, 235)); UpdateUi();
        }

        void AddHistory(string text, Color color)
        {
            history.Items.Insert(0, text);
            while (history.Items.Count > 120) history.Items.RemoveAt(history.Items.Count - 1);
            history.ForeColor = Color.FromArgb(222, 210, 175);
        }

        void RefreshSlots()
        {
            foreach (MaterialSlot slot in slots) { slot.Count = stock[slot.Material.Method]; slot.Invalidate(); }
            foreach (EquipmentInventorySlot slot in equipmentSlots) slot.Invalidate();
        }
        void UpdateUi()
        {
            itemLevel.Text = "Поточна заточка: +" + current;
            var nameLabel = Controls.Find("RefineItemName", true).FirstOrDefault() as Label;
            if (nameLabel != null) nameLabel.Text = selectedEquipment.Name + "  [слот " + (selectedEquipment.Index + 1) + "]";
            resultLabel.Text = "Результат: здоров'я +" + (40 + current * 8) + "  (+" + current + ")";
            methodLabel.Text = selected.Name;
            chanceLabel.Text = current >= 12 ? "Максимальна заточка" : "Шанс наступного рівня: " + (Chance(current, selected.Method) * 100).ToString("N2") + "%";
            statistics.Text = "Спроб: " + attempts + "\nУспіхів: " + successes + "   Невдач: " + failures + "\nВитрачено міражів: " + miragesSpent;
            RefreshSlots();
        }
        public void OnActivated() { UpdateUi(); }
    }

    internal sealed class MaterialSlot : Control
    {
        public readonly RefineMaterial Material;
        public int Count;
        bool selected;
        public bool Selected { get { return selected; } set { selected = value; Invalidate(); } }
        public MaterialSlot(RefineMaterial material) { Material = material; DoubleBuffered = true; Cursor = Cursors.Hand; SetStyle(ControlStyles.SupportsTransparentBackColor, true); BackColor = Color.Transparent; }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); Color border = selected ? Color.FromArgb(255, 210, 70) : Color.FromArgb(132, 112, 67);
            using (var back = new SolidBrush(Color.FromArgb(230, 24, 22, 17))) e.Graphics.FillRectangle(back, 0, 0, Width - 1, Height - 1);
            using (var pen = new Pen(border, selected ? 3 : 1)) e.Graphics.DrawRectangle(pen, 1, 1, Width - 3, Height - 3);
            var badge = new Rectangle(22, 10, 48, 48);
            using (var glow = new SolidBrush(Color.FromArgb(80, Material.Color))) e.Graphics.FillEllipse(glow, badge.X - 5, badge.Y - 5, badge.Width + 10, badge.Height + 10);
            Image icon = string.IsNullOrEmpty(Material.IconFile) ? null : AssetImages.Load("refinement-icons", Material.IconFile);
            if (icon != null) e.Graphics.DrawImage(icon, badge);
            else { using (var brush = new SolidBrush(Material.Color)) e.Graphics.FillEllipse(brush, badge); TextRenderer.DrawText(e.Graphics, Material.ShortName, new Font("Segoe UI", 14, FontStyle.Bold), badge, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter); }
            TextRenderer.DrawText(e.Graphics, Material.Name, new Font("Segoe UI", 7, FontStyle.Bold), new Rectangle(5, 62, Width - 10, 25), Color.FromArgb(235, 220, 178), TextFormatFlags.HorizontalCenter | TextFormatFlags.WordBreak | TextFormatFlags.EndEllipsis);
            TextRenderer.DrawText(e.Graphics, "× " + Count, new Font("Segoe UI", 8, FontStyle.Bold), new Rectangle(5, 87, Width - 10, 15), Color.White, TextFormatFlags.Right);
        }
    }

    internal sealed class CrystalBadge : Control
    {
        public Color BadgeColor; public string Letter; public Image IconImage;
        public CrystalBadge(Color color, string letter, Image icon) { BadgeColor = color; Letter = letter; IconImage = icon; DoubleBuffered = true; SetStyle(ControlStyles.SupportsTransparentBackColor, true); BackColor = Color.Transparent; }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); using (var glow = new SolidBrush(Color.FromArgb(75, BadgeColor))) e.Graphics.FillEllipse(glow, 1, 1, Width - 2, Height - 2);
            Point[] crystal = { new Point(Width / 2, 4), new Point(Width - 7, Height / 3), new Point(Width - 13, Height - 7), new Point(13, Height - 7), new Point(7, Height / 3) };
            if (IconImage != null) e.Graphics.DrawImage(IconImage, new Rectangle(2, 2, Width - 4, Height - 4));
            else { using (var brush = new SolidBrush(BadgeColor)) e.Graphics.FillPolygon(brush, crystal); using (var pen = new Pen(Color.White, 1)) e.Graphics.DrawPolygon(pen, crystal); TextRenderer.DrawText(e.Graphics, Letter, new Font("Segoe UI", 14, FontStyle.Bold), ClientRectangle, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter); }
        }
    }

    internal sealed class EquipmentInventorySlot : Control
    {
        public readonly RefineEquipment Equipment;
        readonly Image equipmentIcon;
        bool selected;
        public bool Selected { get { return selected; } set { selected = value; Invalidate(); } }
        public EquipmentInventorySlot(RefineEquipment equipment) { Equipment = equipment; equipmentIcon = AssetImages.Load("refinement-icons", Equipment.IconFile); DoubleBuffered = true; Cursor = Cursors.Hand; SetStyle(ControlStyles.SupportsTransparentBackColor, true); BackColor = Color.Transparent; }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); Color border = selected ? Color.FromArgb(255, 210, 70) : Color.FromArgb(125, 105, 65);
            using (var back = new SolidBrush(Color.FromArgb(235, 18, 17, 13))) e.Graphics.FillRectangle(back, 0, 0, Width - 1, Height - 1);
            using (var pen = new Pen(border, selected ? 3 : 1)) e.Graphics.DrawRectangle(pen, 1, 1, Width - 3, Height - 3);
            if (equipmentIcon != null) e.Graphics.DrawImage(equipmentIcon, new Rectangle(7, 5, 34, 35));
            TextRenderer.DrawText(e.Graphics, "+" + Equipment.Level, new Font("Segoe UI", 8, FontStyle.Bold), new Rectangle(2, 43, Width - 4, 14), Equipment.Level > 0 ? Color.Gold : Color.White, TextFormatFlags.Right);
            TextRenderer.DrawText(e.Graphics, (Equipment.Index + 1).ToString(), new Font("Segoe UI", 7, FontStyle.Bold), new Rectangle(2, 2, 15, 13), Color.White, TextFormatFlags.Left);
        }
    }

    internal sealed class EquipmentSlot : Control
    {
        Image equipmentIcon;
        public EquipmentSlot(RefineEquipment equipment) { SetEquipment(equipment); DoubleBuffered = true; SetStyle(ControlStyles.SupportsTransparentBackColor, true); BackColor = Color.Transparent; }
        public void SetEquipment(RefineEquipment equipment) { equipmentIcon = equipment == null || string.IsNullOrEmpty(equipment.IconFile) ? null : AssetImages.Load("refinement-icons", equipment.IconFile); Invalidate(); }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e); using (var back = new SolidBrush(Color.FromArgb(235, 18, 17, 13))) e.Graphics.FillRectangle(back, 1, 1, Width - 3, Height - 3);
            using (var pen = new Pen(Color.FromArgb(185, 150, 70), 2)) e.Graphics.DrawRectangle(pen, 2, 2, Width - 5, Height - 5);
            if (equipmentIcon != null) e.Graphics.DrawImage(equipmentIcon, new Rectangle(14, 10, 60, 62));
        }
    }
}
