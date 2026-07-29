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

        public static Image LoadSized(int width, int height, params string[] parts)
        {
            string key = "sized:" + width + "x" + height + ":" + string.Join("\\", parts);
            Image cached;
            if (Cache.TryGetValue(key, out cached)) return cached;
            Image source = Load(parts);
            if (source == null) return null;
            var result = new Bitmap(width, height);
            using (Graphics graphics = Graphics.FromImage(result))
            {
                graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                graphics.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                graphics.DrawImage(source, new Rectangle(0, 0, width, height));
            }
            Cache[key] = result;
            return result;
        }
        public static void DisposeAll()
        {
            foreach (Image image in Cache.Values) image.Dispose();
            Cache.Clear();
        }
    }
}
