using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;

namespace CyberPW.Assistant2
{
    internal static class AssetImages
    {
        private static readonly Dictionary<string, Image> Cache =
            new Dictionary<string, Image>(StringComparer.OrdinalIgnoreCase);

        public static Image Load(params string[] parts)
        {
            string path = AppPaths.Assets;
            foreach (string part in parts) path = Path.Combine(path, part);
            Image image;
            if (Cache.TryGetValue(path, out image)) return image;
            if (!File.Exists(path)) return null;
            using (var source = Image.FromFile(path)) image = new Bitmap(source);
            Cache[path] = image;
            return image;
        }

        public static void DisposeAll()
        {
            foreach (Image image in Cache.Values) image.Dispose();
            Cache.Clear();
        }
    }
}
