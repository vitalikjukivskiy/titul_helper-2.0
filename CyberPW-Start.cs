using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

[assembly: AssemblyTitle("CyberPW Assistant")]
[assembly: AssemblyProduct("CyberPW Assistant")]
[assembly: AssemblyDescription("CyberPW Assistant launcher without console window")]
[assembly: AssemblyCompany("CyberPW Community")]
[assembly: AssemblyVersion("1.7.2.0")]
[assembly: AssemblyFileVersion("1.7.2.0")]

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        string appFolder = AppDomain.CurrentDomain.BaseDirectory;
        string script = args.Length > 0 ? args[0] : Path.Combine(appFolder, "CyberPW-Launcher.ps1");
        if (!Path.IsPathRooted(script)) script = Path.Combine(appFolder, script);
        script = Path.GetFullPath(script);
        if (!File.Exists(script)) return 2;

        var command = new StringBuilder();
        command.Append("-NoProfile -STA -ExecutionPolicy Bypass -File ").Append(Quote(script));
        for (int i = 1; i < args.Length; i++) command.Append(" ").Append(Quote(args[i]));

        Process.Start(new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = command.ToString(),
            WorkingDirectory = Path.GetDirectoryName(script),
            UseShellExecute = false,
            CreateNoWindow = true
        });
        return 0;
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
