using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace CyberPW.Assistant2
{
    internal sealed class CharacterProfile
    {
        public string Nick { get; set; }
        public string Class { get; set; }
        public bool Selected { get; set; }
        public string LoginProtected { get; set; }
        public string PasswordProtected { get; set; }
    }
    internal sealed class LauncherConfig
    {
        public string GamePath { get; set; }
        public int DelaySeconds { get; set; }
        public Dictionary<string, CharacterProfile> Characters { get; set; }
        public LauncherConfig(){GamePath="";DelaySeconds=4;Characters=new Dictionary<string,CharacterProfile>();}
    }
    internal static class MultiLauncherStore
    {
        public static string PathName { get { return Path.Combine(AppPaths.Root,"characters.json"); } }
        public static LauncherConfig Load(){try{var c=File.Exists(PathName)?JsonFiles.Read<LauncherConfig>(PathName):new LauncherConfig();if(c.Characters==null)c.Characters=new Dictionary<string,CharacterProfile>();if(c.DelaySeconds<1)c.DelaySeconds=4;return c;}catch{return new LauncherConfig();}}
        public static void Save(LauncherConfig config){JsonFiles.Write(PathName,config);}
        public static string Protect(string value){if(string.IsNullOrEmpty(value))return "";byte[] raw=Encoding.UTF8.GetBytes(value);return Convert.ToBase64String(ProtectedData.Protect(raw,null,DataProtectionScope.CurrentUser));}
        public static string Unprotect(string value){if(string.IsNullOrEmpty(value))return "";try{return Encoding.UTF8.GetString(ProtectedData.Unprotect(Convert.FromBase64String(value),null,DataProtectionScope.CurrentUser));}catch{return "";}}
        public static string ResolveGamePath(string requested){foreach(string candidate in new[]{requested,Load().GamePath,AppPaths.Root,Directory.GetParent(AppPaths.Root.TrimEnd('\\')).FullName}){if(string.IsNullOrWhiteSpace(candidate))continue;try{string full=Path.GetFullPath(candidate);if(File.Exists(Path.Combine(full,"ElementClient.exe"))||File.Exists(Path.Combine(full,"elementclient.exe")))return full.TrimEnd('\\');}catch{}}return "";}
    }
}
