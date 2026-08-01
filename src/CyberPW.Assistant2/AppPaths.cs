using System;
using System.IO;

namespace CyberPW.Assistant2
{
    internal static class AppPaths
    {
        public static readonly string Root = AppDomain.CurrentDomain.BaseDirectory;
        public static readonly string Data = Path.Combine(Root, "data");
        public static readonly string Assets = Path.Combine(Root, "ui-assets");
        public static readonly string Titles = Path.Combine(Data, "titles.json");
        public static readonly string Offsets = Path.Combine(Data, "memory-offsets.json");
        public static readonly string State = Path.Combine(Data, "state.json");
        public static readonly string Macros = Path.Combine(Root, "macros");
        public static readonly string DefaultMacros = Path.Combine(Root, "default-macros");
        public static readonly string LootIcons = Path.Combine(Root, "loot-icons");

        static AppPaths()
        {
            EnsureWritableFolders();
            SeedDefaultMacros();
        }

        public static void EnsureWritableFolders()
        {
            Directory.CreateDirectory(Data);
            Directory.CreateDirectory(Macros);
        }

        static void SeedDefaultMacros()
        {
            try
            {
                if (!Directory.Exists(DefaultMacros)) return;
                foreach (string source in Directory.GetFiles(DefaultMacros, "*.macro", SearchOption.TopDirectoryOnly))
                {
                    string destination = Path.Combine(Macros, Path.GetFileName(source));
                    if (!File.Exists(destination)) File.Copy(source, destination, false);
                }
            }
            catch
            {
                // A read-only portable folder must not prevent Assistant from starting.
            }
        }
    }
}
