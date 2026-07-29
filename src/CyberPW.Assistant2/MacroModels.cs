using System;
using System.Collections.Generic;

namespace CyberPW.Assistant2
{
    internal sealed class MacroFile
    {
        public int schemaVersion { get; set; }
        public string name { get; set; }
        public string targetProcess { get; set; }
        public string startHotkey { get; set; }
        public string stopHotkey { get; set; }
        public List<MacroRow> steps { get; set; }
    }
    internal sealed class MacroRow
    {
        public string command { get; set; }
        public string argument { get; set; }
        public string description { get; set; }
    }
    internal sealed class MacroInstruction
    {
        public string Command;
        public string Argument;
        public int Jump = -1;
    }
    internal static class MacroCompiler
    {
        public static List<MacroInstruction> Compile(IEnumerable<MacroRow> rows)
        {
            var result = new List<MacroInstruction>();
            var conditions = new Stack<int>();
            foreach (MacroRow row in rows)
            {
                string command = (row.command ?? "").Trim().ToUpperInvariant();
                if (command == "") continue;
                var instruction = new MacroInstruction { Command = command, Argument = row.argument ?? "" };
                if (command == "IFCOLOR" || command == "IFNOTCOLOR") conditions.Push(result.Count);
                else if (command == "ENDIF")
                {
                    if (conditions.Count == 0) throw new InvalidOperationException("КІНЕЦЬ IF без початку IF.");
                    int start = conditions.Pop();
                    result[start].Jump = result.Count + 1;
                }
                result.Add(instruction);
            }
            if (conditions.Count > 0) throw new InvalidOperationException("Є незакритий блок IF.");
            return result;
        }
    }
}
