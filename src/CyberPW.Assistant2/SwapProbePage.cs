using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class SwapProbePage : UserControl, IModulePage
    {
        const uint PROCESS_QUERY_INFORMATION = 0x0400;
        const uint PROCESS_VM_READ = 0x0010;
        const uint MEM_COMMIT = 0x1000;
        const uint PAGE_GUARD = 0x100;
        const uint PAGE_NOACCESS = 0x01;

        [StructLayout(LayoutKind.Sequential)]
        struct MEMORY_BASIC_INFORMATION
        {
            public IntPtr BaseAddress;
            public IntPtr AllocationBase;
            public uint AllocationProtect;
            public UIntPtr RegionSize;
            public uint State;
            public uint Protect;
            public uint Type;
        }

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] buffer, int size, out IntPtr read);
        [DllImport("kernel32.dll")]
        static extern int VirtualQueryEx(IntPtr process, IntPtr address, out MEMORY_BASIC_INFORMATION mbi, int length);
        [DllImport("kernel32.dll")]
        static extern bool CloseHandle(IntPtr handle);

        sealed class ClientItem
        {
            public int Pid;
            public string Text;
            public override string ToString(){return Text;}
        }
        sealed class RegionDump
        {
            public long Base;
            public byte[] Data;
        }
        sealed class DiffRow
        {
            public long Address;
            public int Before;
            public int After;
            public long RegionBase;
        }

        readonly ComboBox clients = new ComboBox();
        readonly Button refreshButton;
        readonly Button snapAButton;
        readonly Button snapBButton;
        readonly Button compareButton;
        readonly Button saveButton;
        readonly Button clearButton;
        readonly Label status;
        readonly TextBox instructions;
        readonly DataGridView grid;
        readonly BackgroundWorker worker = new BackgroundWorker();
        List<RegionDump> snapshotA;
        List<RegionDump> snapshotB;
        List<DiffRow> lastDiff = new List<DiffRow>();
        string pendingAction = "";

        public string Title { get { return "SWAP PROBE · SUPER BETA"; } }

        public SwapProbePage()
        {
            Dock=DockStyle.Fill;
            BackColor=Theme.Ink;
            ForeColor=Theme.Text;
            Font=new Font("Segoe UI",9);

            var title=Theme.Label("SWAP PROBE · СУПЕР БЕТА",21,Theme.GoldSoft,FontStyle.Bold);
            title.SetBounds(22,12,650,38); Controls.Add(title);
            var sub=Theme.Label("READ ONLY · пошук структури інвентарю та екіпіровки",9,Theme.Cyan,FontStyle.Bold);
            sub.SetBounds(24,49,700,24); Controls.Add(sub);

            clients.DropDownStyle=ComboBoxStyle.DropDownList;
            clients.SetBounds(22,82,300,30); Controls.Add(clients);
            refreshButton=Theme.Button("ОНОВИТИ КЛІЄНТИ"); refreshButton.SetBounds(334,80,160,34);
            refreshButton.Click+=delegate{RefreshClients();}; Controls.Add(refreshButton);

            snapAButton=Theme.Button("1 · SNAPSHOT A"); snapAButton.SetBounds(22,126,155,38);
            snapAButton.Click+=delegate{StartSnapshot("A");}; Controls.Add(snapAButton);
            snapBButton=Theme.Button("2 · SNAPSHOT B"); snapBButton.SetBounds(189,126,155,38);
            snapBButton.Click+=delegate{StartSnapshot("B");}; Controls.Add(snapBButton);
            compareButton=Theme.Button("3 · ПОРІВНЯТИ"); compareButton.SetBounds(356,126,155,38);
            compareButton.Click+=delegate{Compare();}; Controls.Add(compareButton);
            saveButton=Theme.Button("ЗБЕРЕГТИ CSV"); saveButton.SetBounds(523,126,150,38);
            saveButton.Click+=delegate{SaveCsv();}; Controls.Add(saveButton);
            clearButton=Theme.Button("СКИНУТИ"); clearButton.SetBounds(685,126,130,38);
            clearButton.Click+=delegate{ResetAll();}; Controls.Add(clearButton);

            status=Theme.Label("Готово. Пам'ять НЕ змінюється.",9,Theme.Cyan,FontStyle.Bold);
            status.SetBounds(22,174,810,25); Controls.Add(status);

            instructions=new TextBox(); instructions.Multiline=true; instructions.ReadOnly=true;
            instructions.BackColor=Color.FromArgb(14,27,25); instructions.ForeColor=Theme.Text; instructions.BorderStyle=BorderStyle.FixedSingle;
            instructions.Font=new Font("Segoe UI",9); instructions.SetBounds(22,207,820,92);
            instructions.Text="ЯК ТЕСТУВАТИ:\r\n1) Відкрий інвентар і нічого не рухай → SNAPSHOT A.\r\n2) Перетягни ОДНУ шмотку з однієї комірки в іншу (або одягни/зніми одну річ).\r\n3) SNAPSHOT B → ПОРІВНЯТИ. Чим менше інших дій між A/B, тим чистіший результат.";
            Controls.Add(instructions);

            grid=new DataGridView(); grid.SetBounds(22,313,820,305); grid.ReadOnly=true; grid.AllowUserToAddRows=false; grid.AllowUserToDeleteRows=false;
            grid.AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill; grid.BackgroundColor=Color.FromArgb(14,27,25); grid.ForeColor=Color.White;
            grid.DefaultCellStyle.BackColor=Color.FromArgb(14,27,25); grid.DefaultCellStyle.ForeColor=Color.White;
            grid.ColumnHeadersDefaultCellStyle.BackColor=Color.FromArgb(6,55,47); grid.ColumnHeadersDefaultCellStyle.ForeColor=Theme.GoldSoft;
            grid.EnableHeadersVisualStyles=false;
            grid.Columns.Add("address","АДРЕСА"); grid.Columns.Add("before","A · INT32"); grid.Columns.Add("after","B · INT32"); grid.Columns.Add("delta","Δ"); grid.Columns.Add("region","REGION");
            Controls.Add(grid);

            worker.DoWork+=WorkerDoWork;
            worker.RunWorkerCompleted+=WorkerDone;
            RefreshClients();
        }

        public void OnActivated(){RefreshClients();}

        void RefreshClients()
        {
            int oldPid=0; var old=clients.SelectedItem as ClientItem; if(old!=null)oldPid=old.Pid;
            clients.Items.Clear();
            try
            {
                foreach(var p in Process.GetProcessesByName("elementclient").OrderBy(x=>x.Id))
                {
                    var item=new ClientItem{Pid=p.Id,Text="PID "+p.Id+" — CyberPW"}; clients.Items.Add(item);
                    if(p.Id==oldPid)clients.SelectedItem=item;
                }
            }catch{}
            if(clients.SelectedIndex<0&&clients.Items.Count>0)clients.SelectedIndex=0;
            if(clients.Items.Count==0)status.Text="CyberPW не знайдено. Запусти гру.";
        }

        void SetBusy(bool busy)
        {
            refreshButton.Enabled=!busy; snapAButton.Enabled=!busy; snapBButton.Enabled=!busy; compareButton.Enabled=!busy; clients.Enabled=!busy;
        }

        void StartSnapshot(string which)
        {
            if(worker.IsBusy)return;
            var c=clients.SelectedItem as ClientItem; if(c==null){status.Text="Вибери ElementClient.";return;}
            pendingAction=which; SetBusy(true); status.Text="Читаю committed memory regions для Snapshot "+which+"...";
            worker.RunWorkerAsync(c.Pid);
        }

        void WorkerDoWork(object sender,DoWorkEventArgs e)
        {
            e.Result=Capture((int)e.Argument);
        }

        void WorkerDone(object sender,RunWorkerCompletedEventArgs e)
        {
            SetBusy(false);
            if(e.Error!=null){status.Text="Помилка: "+e.Error.Message;return;}
            var data=e.Result as List<RegionDump>; if(data==null){status.Text="Snapshot не створено.";return;}
            if(pendingAction=="A")snapshotA=data; else snapshotB=data;
            long bytes=data.Sum(x=>(long)x.Data.Length);
            status.Text="Snapshot "+pendingAction+" готовий · regions: "+data.Count+" · "+Math.Round(bytes/1024d/1024d,1)+" MB.";
        }

        List<RegionDump> Capture(int pid)
        {
            var output=new List<RegionDump>();
            IntPtr h=OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,false,pid);
            if(h==IntPtr.Zero)throw new InvalidOperationException("OpenProcess failed: "+Marshal.GetLastWin32Error());
            try
            {
                long addr=0; int mbiSize=Marshal.SizeOf(typeof(MEMORY_BASIC_INFORMATION));
                while(addr<0x7FFF0000L)
                {
                    MEMORY_BASIC_INFORMATION mbi;
                    int q=VirtualQueryEx(h,new IntPtr(addr),out mbi,mbiSize); if(q==0)break;
                    long baseAddr=mbi.BaseAddress.ToInt64(); long size=(long)mbi.RegionSize.ToUInt64();
                    bool readable=mbi.State==MEM_COMMIT && (mbi.Protect&PAGE_GUARD)==0 && (mbi.Protect&PAGE_NOACCESS)==0;
                    if(readable && size>0 && size<=32*1024*1024)
                    {
                        int len=(int)size; var buf=new byte[len]; IntPtr got;
                        if(ReadProcessMemory(h,mbi.BaseAddress,buf,len,out got) && got.ToInt64()>0)
                        {
                            int n=(int)Math.Min(got.ToInt64(),len);
                            if(n!=buf.Length)Array.Resize(ref buf,n);
                            output.Add(new RegionDump{Base=baseAddr,Data=buf});
                        }
                    }
                    long next=baseAddr+Math.Max(size,0x1000); if(next<=addr)break; addr=next;
                }
            }
            finally{CloseHandle(h);}
            return output;
        }

        void Compare()
        {
            grid.Rows.Clear(); lastDiff.Clear();
            if(snapshotA==null||snapshotB==null){status.Text="Спочатку зроби Snapshot A і B.";return;}
            var mapB=snapshotB.ToDictionary(x=>x.Base,x=>x);
            foreach(var a in snapshotA)
            {
                RegionDump b; if(!mapB.TryGetValue(a.Base,out b))continue;
                int len=Math.Min(a.Data.Length,b.Data.Length);
                for(int i=0;i+4<=len;i+=4)
                {
                    int va=BitConverter.ToInt32(a.Data,i), vb=BitConverter.ToInt32(b.Data,i);
                    if(va==vb)continue;
                    bool plausible=(Math.Abs((long)va)<=2000000000L && Math.Abs((long)vb)<=2000000000L);
                    if(!plausible)continue;
                    lastDiff.Add(new DiffRow{Address=a.Base+i,Before=va,After=vb,RegionBase=a.Base});
                    if(lastDiff.Count>=20000)break;
                }
                if(lastDiff.Count>=20000)break;
            }
            var ranked=lastDiff.OrderBy(x=>Rank(x)).Take(600).ToList();
            foreach(var d in ranked)
                grid.Rows.Add("0x"+d.Address.ToString("X8"),d.Before,d.After,d.After-d.Before,"0x"+d.RegionBase.ToString("X8"));
            status.Text="Змін INT32: "+lastDiff.Count+" · показано топ "+ranked.Count+". Збережи CSV після чистого A/B тесту.";
        }

        int Rank(DiffRow x)
        {
            int r=0; int a=Math.Abs(x.Before),b=Math.Abs(x.After);
            if((a==0&&b>0)||(b==0&&a>0))r+=100;
            if(a<1000&&b<1000)r+=70;
            if(a<100000&&b<100000)r+=40;
            if(Math.Abs((long)x.After-x.Before)<100)r+=25;
            return -r;
        }

        void SaveCsv()
        {
            if(grid.Rows.Count==0){status.Text="Немає результатів для збереження.";return;}
            try
            {
                string dir=Path.Combine(AppPaths.Data,"swap-probe"); Directory.CreateDirectory(dir);
                string path=Path.Combine(dir,"swap-probe-"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+".csv");
                var sb=new StringBuilder(); sb.AppendLine("address,before,after,delta,region");
                foreach(DataGridViewRow row in grid.Rows)
                    sb.AppendLine(string.Join(",",Enumerable.Range(0,5).Select(i=>Convert.ToString(row.Cells[i].Value))));
                File.WriteAllText(path,sb.ToString(),Encoding.UTF8);
                status.Text="Збережено: "+path;
                try{Process.Start(new ProcessStartInfo(dir){UseShellExecute=true});}catch{}
            }catch(Exception ex){status.Text="Не вдалося зберегти CSV: "+ex.Message;}
        }

        void ResetAll()
        {
            snapshotA=null;snapshotB=null;lastDiff.Clear();grid.Rows.Clear();status.Text="Скинуто. Готово до нового чистого A/B тесту.";
        }
    }
}
