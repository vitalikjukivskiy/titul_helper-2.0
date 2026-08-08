using System;
using System.Net;

namespace CyberPW.Assistant2
{
    internal sealed class WebClient : System.Net.WebClient
    {
        const string BrokenMannheimUrl = "https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-setup-5.4.0.20240606.exe";
        const string GitHubReleaseUrl = "https://github.com/UB-Mannheim/tesseract/releases/download/v5.4.0.20240606/tesseract-ocr-w64-setup-5.4.0.20240606.exe";

        public new void DownloadFile(string address, string fileName)
        {
            string actual = string.Equals(address, BrokenMannheimUrl, StringComparison.OrdinalIgnoreCase)
                ? GitHubReleaseUrl
                : address;
            base.DownloadFile(actual, fileName);
        }
    }
}
