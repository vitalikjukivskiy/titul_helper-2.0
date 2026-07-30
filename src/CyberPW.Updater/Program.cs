using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Updater
{
    internal static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                if (args.Length != 4)
                {
                    MessageBox.Show("CyberPW Updater запускається автоматично.\n\nВідкрийте CyberPW Assistant 2 Beta.exe і натисніть кнопку «ОНОВЛЕННЯ».", "CyberPW Updater", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                int pid = int.Parse(args[0]); string zip = Path.GetFullPath(args[1]); string target = EnsureSlash(Path.GetFullPath(args[2])); string exeName = args[3];
                WaitForExit(pid);
                string work = Path.Combine(Path.GetTempPath(), "CyberPW-Stage-" + Guid.NewGuid().ToString("N"));
                string stage = Path.Combine(work, "stage"), backup = Path.Combine(work, "backup");
                Directory.CreateDirectory(stage); Directory.CreateDirectory(backup);
                ExtractSafe(zip, stage);
                var copied = new List<string>();
                try
                {
                    foreach (string source in Directory.GetFiles(stage, "*", SearchOption.AllDirectories))
                    {
                        string relative = source.Substring(EnsureSlash(stage).Length).Replace('/', '\\');
                        if (IsUserData(relative)) continue;
                        string destination = Path.GetFullPath(Path.Combine(target, relative));
                        if (!destination.StartsWith(target, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Небезпечний шлях в архіві.");
                        Directory.CreateDirectory(Path.GetDirectoryName(destination));
                        if (File.Exists(destination)) { string saved = Path.Combine(backup, relative); Directory.CreateDirectory(Path.GetDirectoryName(saved)); File.Copy(destination, saved, true); }
                        CopyRetry(source, destination); copied.Add(relative);
                    }
                }
                catch
                {
                    foreach (string relative in copied.AsEnumerable().Reverse()) { string saved=Path.Combine(backup,relative), destination=Path.Combine(target,relative); if(File.Exists(saved))File.Copy(saved,destination,true);else if(File.Exists(destination))File.Delete(destination); }
                    throw;
                }
                Process.Start(new ProcessStartInfo(Path.Combine(target, exeName)){UseShellExecute=true});
            }
            catch (Exception e)
            {
                MessageBox.Show("Не вдалося встановити оновлення. Старі дані збережено.\n\n" + e.Message, "CyberPW Updater", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        static void WaitForExit(int pid){try{var p=Process.GetProcessById(pid);if(!p.WaitForExit(30000))throw new TimeoutException("Assistant не закрився за 30 секунд.");}catch(ArgumentException){}}
        static void ExtractSafe(string zip,string stage){string root=EnsureSlash(Path.GetFullPath(stage));using(var archive=ZipFile.OpenRead(zip))foreach(var entry in archive.Entries){string path=Path.GetFullPath(Path.Combine(root,entry.FullName.Replace('/','\\')));if(!path.StartsWith(root,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Небезпечний шлях у ZIP.");if(string.IsNullOrEmpty(entry.Name)){Directory.CreateDirectory(path);continue;}Directory.CreateDirectory(Path.GetDirectoryName(path));entry.ExtractToFile(path,true);}}
        static bool IsUserData(string p){p=p.Replace('/','\\');return p.Equals("data\\state.json",StringComparison.OrdinalIgnoreCase)||p.Equals("characters.json",StringComparison.OrdinalIgnoreCase)||p.Equals("launcher-theme.json",StringComparison.OrdinalIgnoreCase)||p.Equals("territories.json",StringComparison.OrdinalIgnoreCase)||p.StartsWith("macros\\",StringComparison.OrdinalIgnoreCase);}
        static void CopyRetry(string source,string destination){Exception last=null;for(int i=0;i<20;i++){try{File.Copy(source,destination,true);return;}catch(Exception e){last=e;Thread.Sleep(150);}}throw last;}
        static string EnsureSlash(string p){return p.TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;}
    }
}