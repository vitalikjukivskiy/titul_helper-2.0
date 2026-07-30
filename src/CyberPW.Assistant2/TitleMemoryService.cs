using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace CyberPW.Assistant2
{
    internal sealed class MemoryOffsetsConfig
    {
        public int schemaVersion { get; set; }
        public List<MemoryProfile> profiles { get; set; }
    }

    internal sealed class MemoryProfile
    {
        public string name { get; set; }
        public long fileSize { get; set; }
        public string sha256 { get; set; }
        public int pointerSize { get; set; }
        public string rootOffset { get; set; }
        public List<string> characterPointerChain { get; set; }
        public CharacterIdentityProfile character { get; set; }
        public TitleVectorProfile titles { get; set; }
    }

    internal sealed class CharacterIdentityProfile
    {
        public string namePointerOffset { get; set; }
        public int nameMaxLength { get; set; }
        public string classIdOffset { get; set; }
    }
    internal sealed class TitleVectorProfile
    {
        public string beginOffset { get; set; }
        public string endOffset { get; set; }
        public int entryStride { get; set; }
        public int idSize { get; set; }
        public int maxCount { get; set; }
    }

    internal sealed class OwnedTitlesResult
    {
        public int ProcessId { get; set; }
        public string Profile { get; set; }
        public HashSet<int> Ids { get; set; }
        public int RawCount { get; set; }
    }

    internal sealed class DetectedCharacter
    {
        public int ProcessId { get; set; }
        public string Nick { get; set; }
        public int ClassId { get; set; }
        public string ClassName { get; set; }
    }
    internal static class TitleMemoryService
    {
        private const uint ProcessVmRead = 0x0010;
        private const uint ProcessQueryInformation = 0x0400;

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint access, bool inherit, int processId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool ReadProcessMemory(
            IntPtr process, IntPtr address, [Out] byte[] buffer, UIntPtr size, out UIntPtr read);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr handle);

        public static List<Process> FindClients(string processName)
        {
            return Process.GetProcessesByName(processName)
                .Where(p =>
                {
                    try { return p.MainWindowHandle != IntPtr.Zero; }
                    catch { return false; }
                })
                .OrderBy(p =>
                {
                    try { return p.StartTime; }
                    catch { return DateTime.MaxValue; }
                })
                .ToList();
        }

        public static OwnedTitlesResult Read(Process process)
        {
            if (process == null) throw new ArgumentNullException("process");
            string clientPath = GetClientPath(process);
            MemoryProfile profile = FindProfile(clientPath);
            IntPtr handle = OpenProcess(ProcessVmRead | ProcessQueryInformation, false, process.Id);
            if (handle == IntPtr.Zero)
                throw new InvalidOperationException("Windows не дозволила читання ElementClient (код: " + Marshal.GetLastWin32Error() + ").");

            try
            {
                ulong moduleBase;
                try { moduleBase = unchecked((ulong)process.MainModule.BaseAddress.ToInt64()); }
                catch
                {
                    throw new InvalidOperationException(
                        "Не вдалося визначити базову адресу ElementClient. Запустіть Assistant із такими самими правами, що й гра.");
                }

                ulong context = ResolvePointerChain(handle, moduleBase, profile);
                ulong begin = ReadUnsigned(handle, context + ParseOffset(profile.titles.beginOffset), profile.pointerSize);
                ulong end = ReadUnsigned(handle, context + ParseOffset(profile.titles.endOffset), profile.pointerSize);
                int stride = profile.titles.entryStride;
                if (stride < 1 || end < begin || ((end - begin) % (ulong)stride) != 0)
                    throw new InvalidOperationException("Клієнт повернув пошкоджену структуру титулів.");

                ulong rawCount = (end - begin) / (ulong)stride;
                if (rawCount > (ulong)profile.titles.maxCount)
                    throw new InvalidOperationException("Некоректна кількість титулів: " + rawCount + ".");

                var ids = new HashSet<int>();
                for (ulong index = 0; index < rawCount; index++)
                {
                    int id = checked((int)ReadUnsigned(
                        handle, begin + index * (ulong)stride, profile.titles.idSize));
                    if (id > 0) ids.Add(id);
                }

                return new OwnedTitlesResult
                {
                    ProcessId = process.Id,
                    Profile = profile.name,
                    Ids = ids,
                    RawCount = checked((int)rawCount)
                };
            }
            finally { CloseHandle(handle); }
        }

        public static DetectedCharacter ReadCharacter(Process process)
        {
            if (process == null) throw new ArgumentNullException("process");
            MemoryProfile profile = FindProfile(GetClientPath(process));
            if (profile.character == null) throw new InvalidOperationException("Профіль клієнта не містить даних персонажа.");
            IntPtr handle = OpenProcess(ProcessVmRead | ProcessQueryInformation, false, process.Id);
            if (handle == IntPtr.Zero) throw new InvalidOperationException("Windows не дозволила прочитати ElementClient.");
            try
            {
                ulong moduleBase = unchecked((ulong)process.MainModule.BaseAddress.ToInt64());
                ulong context = ResolvePointerChain(handle, moduleBase, profile);
                ulong nameAddress = ReadUnsigned(handle, context + ParseOffset(profile.character.namePointerOffset), profile.pointerSize);
                string nick = ReadUnicodeString(handle, nameAddress, Math.Max(4, profile.character.nameMaxLength));
                if (string.IsNullOrWhiteSpace(nick)) throw new InvalidOperationException("Персонаж ще не увійшов у світ.");
                int classId = checked((int)ReadUnsigned(handle, context + ParseOffset(profile.character.classIdOffset), 4));
                return new DetectedCharacter { ProcessId = process.Id, Nick = nick, ClassId = classId, ClassName = ClassNameFromId(classId) };
            }
            finally { CloseHandle(handle); }
        }
        private static string GetClientPath(Process process)
        {
            try
            {
                string path = process.MainModule.FileName;
                if (!string.IsNullOrWhiteSpace(path) && File.Exists(path)) return path;
            }
            catch { }
            throw new InvalidOperationException(
                "Не вдалося визначити шлях до ElementClient.exe. Запустіть Assistant із такими самими правами, що й гра.");
        }

        private static MemoryProfile FindProfile(string clientPath)
        {
            if (!File.Exists(AppPaths.Offsets))
                throw new FileNotFoundException("Не знайдено memory-offsets.json.", AppPaths.Offsets);
            MemoryOffsetsConfig config = JsonFiles.Read<MemoryOffsetsConfig>(AppPaths.Offsets);
            if (config == null || config.schemaVersion != 1 || config.profiles == null)
                throw new InvalidOperationException("Непідтримувана версія memory-offsets.json.");

            long size = new FileInfo(clientPath).Length;
            List<MemoryProfile> sameSize = config.profiles.Where(p => p.fileSize == size).ToList();
            if (sameSize.Count == 0)
                throw new InvalidOperationException("Ця версія ElementClient ще не підтримується (інший розмір файлу).");

            string hash;
            using (var stream = File.OpenRead(clientPath))
            using (var sha = SHA256.Create())
                hash = BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");

            MemoryProfile profile = sameSize.FirstOrDefault(
                p => string.Equals(p.sha256, hash, StringComparison.OrdinalIgnoreCase));
            if (profile == null)
                throw new InvalidOperationException("Ця версія ElementClient ще не підтримується (SHA256 не збігається).");
            if (profile.pointerSize != 8)
                throw new InvalidOperationException("Профіль клієнта має непідтримуваний розмір вказівника.");
            return profile;
        }

        private static ulong ResolvePointerChain(IntPtr handle, ulong moduleBase, MemoryProfile profile)
        {
            ulong pointer = ReadUnsigned(handle, moduleBase + ParseOffset(profile.rootOffset), profile.pointerSize);
            if (pointer == 0) throw new InvalidOperationException("Персонаж ще не завантажений.");
            foreach (string offset in profile.characterPointerChain)
            {
                pointer = ReadUnsigned(handle, pointer + ParseOffset(offset), profile.pointerSize);
                if (pointer == 0)
                    throw new InvalidOperationException("Структура персонажа ще не готова (offset " + offset + ").");
            }
            return pointer;
        }

        private static ulong ReadUnsigned(IntPtr handle, ulong address, int size)
        {
            if (size != 2 && size != 4 && size != 8)
                throw new InvalidOperationException("Непідтримуваний розмір читання.");
            var buffer = new byte[size];
            UIntPtr read;
            if (!ReadProcessMemory(handle, new IntPtr(unchecked((long)address)), buffer, new UIntPtr((uint)size), out read) ||
                read.ToUInt64() != (ulong)size)
                throw new InvalidOperationException(
                    "Не вдалося прочитати дані клієнта (код Windows: " + Marshal.GetLastWin32Error() + ").");
            if (size == 8) return BitConverter.ToUInt64(buffer, 0);
            if (size == 4) return BitConverter.ToUInt32(buffer, 0);
            return BitConverter.ToUInt16(buffer, 0);
        }

        private static string ReadUnicodeString(IntPtr handle, ulong address, int maxLength)
        {
            if (address == 0) return "";
            int bytes = checked(maxLength * 2);
            var buffer = new byte[bytes];
            UIntPtr read;
            if (!ReadProcessMemory(handle, new IntPtr(unchecked((long)address)), buffer, new UIntPtr((uint)bytes), out read) || read.ToUInt64() < 2) return "";
            int length = 0, available = checked((int)read.ToUInt64());
            while (length + 1 < available && (buffer[length] != 0 || buffer[length + 1] != 0)) length += 2;
            string value = Encoding.Unicode.GetString(buffer, 0, length).Trim();
            if (value.Length < 2 || value.Any(ch => char.IsControl(ch))) return "";
            return value;
        }

        private static string ClassNameFromId(int id)
        {
            switch (id)
            {
                case 0: return "Воїн"; case 1: return "Маг"; case 2: return "Лучник"; case 3: return "Жрець";
                case 4: return "Танк"; case 5: return "Друїд"; case 6: return "Асасин"; case 7: return "Шаман";
                case 8: return "Страж"; case 9: return "Містик"; default: return "Не визначено";
            }
        }
        private static ulong ParseOffset(string value)
        {
            if (string.IsNullOrWhiteSpace(value) || !value.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Некоректний offset у профілі: " + value);
            ulong result;
            if (!ulong.TryParse(value.Substring(2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out result))
                throw new InvalidOperationException("Некоректний offset у профілі: " + value);
            return result;
        }
    }

    internal sealed class ClientProcessItem
    {
        public Process Process { get; private set; }
        public string Label { get; private set; }

        public ClientProcessItem(Process process, int number)
        {
            Process = process;
            string title;
            try { title = process.MainWindowTitle; }
            catch { title = ""; }
            if (string.IsNullOrWhiteSpace(title)) title = "ElementClient";
            string started;
            try { started = process.StartTime.ToString("HH:mm:ss"); }
            catch { started = "—"; }
            Label = "Вікно " + number + " · " + title + " · PID " + process.Id + " · " + started;
        }

        public override string ToString() { return Label; }
    }
}
