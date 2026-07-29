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
        sealed class Block { public string Type; public int Start; public int Count; }
        public static List<MacroInstruction> Compile(IEnumerable<MacroRow> rows)
        {
            var result=new List<MacroInstruction>();var blocks=new Stack<Block>();
            foreach(MacroRow row in rows)
            {
                string command=(row.command??"").Trim().ToUpperInvariant();if(command=="")continue;
                if(command=="REPEAT") { int count;if(!int.TryParse(row.argument,out count)||count<1||count>1000)throw new InvalidOperationException("REPEAT: 1–1000.");blocks.Push(new Block{Type="REPEAT",Start=result.Count,Count=count});continue; }
                if(command=="END") { if(blocks.Count==0||blocks.Peek().Type!="REPEAT")throw new InvalidOperationException("END без REPEAT.");Block b=blocks.Pop();var body=result.GetRange(b.Start,result.Count-b.Start);for(int c=1;c<b.Count;c++)foreach(var item in body)result.Add(new MacroInstruction{Command=item.Command,Argument=item.Argument});if(result.Count>10000)throw new InvalidOperationException("Максимум 10000 команд.");continue; }
                if(command=="IFCOLOR"||command=="IFNOTCOLOR")blocks.Push(new Block{Type="IF"});
                else if(command=="ENDIF") { if(blocks.Count==0||blocks.Peek().Type!="IF")throw new InvalidOperationException("ENDIF без IF.");blocks.Pop(); }
                result.Add(new MacroInstruction{Command=command,Argument=row.argument??""});
            }
            if(blocks.Count>0)throw new InvalidOperationException("Не закрито "+blocks.Peek().Type+".");
            var conditions=new Stack<int>();for(int i=0;i<result.Count;i++){if(result[i].Command=="IFCOLOR"||result[i].Command=="IFNOTCOLOR")conditions.Push(i);else if(result[i].Command=="ENDIF"){int open=conditions.Pop();result[open].Jump=i+1;}}
            return result;
        }
    }
}