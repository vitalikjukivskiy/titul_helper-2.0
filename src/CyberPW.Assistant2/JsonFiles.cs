using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

namespace CyberPW.Assistant2
{
    internal static class JsonFiles
    {
        private static readonly JavaScriptSerializer Serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };

        public static T Read<T>(string path)
        {
            string json = File.ReadAllText(path, Encoding.UTF8);
            return Serializer.Deserialize<T>(json);
        }

        public static void Write<T>(string path, T value)
        {
            string temporary = path + ".tmp";
            string json = Serializer.Serialize(value);
            File.WriteAllText(temporary, json, new UTF8Encoding(true));
            if (File.Exists(path))
            {
                string backup = path + ".bak";
                File.Replace(temporary, path, backup, true);
                if (File.Exists(backup)) File.Delete(backup);
            }
            else
            {
                File.Move(temporary, path);
            }
        }
    }

    internal sealed class TitleRecord
    {
        public string id { get; set; }
        public string name { get; set; }
        public int x { get; set; }
        public int y { get; set; }
        public string note { get; set; }
        public string chain { get; set; }
        public string task { get; set; }
        public int clientTitleId { get; set; }

        public override string ToString()
        {
            return name;
        }
    }

    internal sealed class TitleState
    {
        public Dictionary<string, bool> done { get; set; }
        public Dictionary<string, object> config { get; set; }

        public TitleState()
        {
            done = new Dictionary<string, bool>();
            config = new Dictionary<string, object>();
        }
    }
}
