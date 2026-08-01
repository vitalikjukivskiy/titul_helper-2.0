using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace CyberPW.Assistant2
{
    internal sealed class UpdateInfo
    {
        public string Version;
        public string Tag;
        public string Name;
        public string Notes;
        public string DownloadUrl;
        public string Sha256;
    }

    internal static class UpdateService
    {
        const string ReleasesApi = "https://api.github.com/repos/vitalikjukivskiy/titul_helper-2.0/releases?per_page=20";
        const string AssetName = "CyberPW-Assistant-2.0-Beta-Portable.zip";

        sealed class ReleaseDto
        {
            public string tag_name { get; set; }
            public string name { get; set; }
            public string body { get; set; }
            public bool draft { get; set; }
            public bool prerelease { get; set; }
            public List<AssetDto> assets { get; set; }
        }
        sealed class AssetDto
        {
            public string name { get; set; }
            public string browser_download_url { get; set; }
            public string digest { get; set; }
        }

        public static async Task<UpdateInfo> CheckAsync(bool force)
        {
            string stamp = Path.Combine(AppPaths.Root, ".update-check");
            if (!force && File.Exists(stamp) && DateTime.UtcNow - File.GetLastWriteTimeUtc(stamp) < TimeSpan.FromHours(6)) return null;
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;
            string json;
            using (var client = Client()) json = await client.DownloadStringTaskAsync(ReleasesApi);
            try { File.WriteAllText(stamp, DateTime.UtcNow.ToString("O")); } catch { }
            var releases = new JavaScriptSerializer().Deserialize<List<ReleaseDto>>(json) ?? new List<ReleaseDto>();
            ReleaseDto release = releases.FirstOrDefault(r => !r.draft && r.prerelease && !string.IsNullOrEmpty(r.tag_name) && r.tag_name.StartsWith("v2.", StringComparison.OrdinalIgnoreCase));
            if (release == null || Compare(ParseVersion(release.tag_name), ParseVersion(CurrentVersion())) <= 0) return null;
            AssetDto asset = (release.assets ?? new List<AssetDto>()).FirstOrDefault(a => string.Equals(a.name, AssetName, StringComparison.OrdinalIgnoreCase));
            if (asset == null) throw new InvalidOperationException("У релізі " + release.tag_name + " немає " + AssetName + ".");
            if (string.IsNullOrWhiteSpace(asset.digest) || !asset.digest.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("GitHub не повернув SHA-256 для архіву оновлення.");
            return new UpdateInfo { Version = ParseVersion(release.tag_name), Tag = release.tag_name, Name = release.name, Notes = release.body, DownloadUrl = asset.browser_download_url, Sha256 = asset.digest.Substring(7).ToUpperInvariant() };
        }

        public static async Task DownloadAndStartAsync(UpdateInfo update)
        {
            string tempRoot = Path.Combine(Path.GetTempPath(), "CyberPW-Update-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempRoot);
            string zip = Path.Combine(tempRoot, AssetName);
            using (var client = Client()) await client.DownloadFileTaskAsync(update.DownloadUrl, zip);
            string actual;
            using (var stream = File.OpenRead(zip)) using (var sha = SHA256.Create()) actual = BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
            if (!string.Equals(actual, update.Sha256, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("SHA-256 оновлення не збігається. Файл видалено.");
            string installedUpdater = Path.Combine(AppPaths.Root, "CyberPW Updater.exe");
            if (!File.Exists(installedUpdater)) throw new FileNotFoundException("Не знайдено CyberPW Updater.exe.", installedUpdater);
            string tempUpdater = Path.Combine(tempRoot, "CyberPW Updater.exe");
            File.Copy(installedUpdater, tempUpdater, true);

            // A request file avoids Windows/shortcut argument parsing issues with paths containing spaces or Cyrillic.
            string request = Path.Combine(tempRoot, "update-request.txt");
            File.WriteAllLines(request, new[] {
                Process.GetCurrentProcess().Id.ToString(),
                zip,
                AppPaths.Root,
                Path.GetFileName(ApplicationExecutable())
            }, new UTF8Encoding(false));
            Process.Start(new ProcessStartInfo
            {
                FileName = tempUpdater,
                Arguments = Quote(request),
                WorkingDirectory = tempRoot,
                UseShellExecute = false
            });
        }

        static WebClient Client()
        {
            var client = new WebClient();
            client.Encoding = Encoding.UTF8;
            client.Headers[HttpRequestHeader.UserAgent] = "CyberPW-Assistant-Updater/2.0";
            client.Headers[HttpRequestHeader.Accept] = "application/vnd.github+json";
            client.Headers["X-GitHub-Api-Version"] = "2022-11-28";
            return client;
        }
        static string CurrentVersion(){try{return File.ReadAllText(Path.Combine(AppPaths.Root,"VERSION")).Trim();}catch{return "0.0.0";}}
        static string ParseVersion(string value){var digits=new string((value??"").SkipWhile(c=>!char.IsDigit(c)).TakeWhile(c=>char.IsDigit(c)||c=='.').ToArray()).Trim('.');var p=digits.Split('.');return string.Join(".",p.Concat(new[]{"0","0","0"}).Take(3));}
        static int Compare(string left,string right){Version a,b;if(!Version.TryParse(left,out a))a=new Version(0,0,0);if(!Version.TryParse(right,out b))b=new Version(0,0,0);return a.CompareTo(b);}
        static string ApplicationExecutable(){return Process.GetCurrentProcess().MainModule.FileName;}
        static string Quote(string value){return "\""+(value??"").Replace("\"","\\\"")+"\"";}
    }
}