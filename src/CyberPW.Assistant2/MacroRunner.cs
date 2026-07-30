using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.Threading;
using System.Windows.Forms;

namespace CyberPW.Assistant2
{
    internal sealed class MacroRunner
    {
        volatile bool stop;
        readonly HashSet<ushort> held=new HashSet<ushort>();
        public void Stop(){stop=true;foreach(ushort key in held)MacroNative.Key(key,true);held.Clear();}
        public void Run(List<MacroInstruction> steps,string processName,bool focus)
        {
            stop=false;Process target=null;foreach(Process p in Process.GetProcessesByName(processName))if(p.MainWindowHandle!=IntPtr.Zero){target=p;break;}
            if(target==null)throw new InvalidOperationException("Не знайдено вікно "+processName+".");
            if(focus){MacroNative.ShowWindowAsync(target.MainWindowHandle,9);MacroNative.SetForegroundWindow(target.MainWindowHandle);}
            for(int index=0;index<steps.Count&&!stop;index++)
            {
                MacroInstruction step=steps[index];string[] parts=(step.Argument??"").Split(new[]{' ',','},StringSplitOptions.RemoveEmptyEntries);
                switch(step.Command)
                {
                    case "WAIT": Thread.Sleep(ParseInt(step.Argument,1,3600000)); break;
                    case "TEXT": MacroNative.Text(step.Argument??""); break;
                    case "KEY": Tap((ushort)(Keys)Enum.Parse(typeof(Keys),step.Argument,true)); break;
                    case "KEYDOWN": {ushort k=(ushort)(Keys)Enum.Parse(typeof(Keys),step.Argument,true);MacroNative.Key(k,false);held.Add(k);break;}
                    case "KEYUP": {ushort k=(ushort)(Keys)Enum.Parse(typeof(Keys),step.Argument,true);MacroNative.Key(k,true);held.Remove(k);break;}
                    case "CLICK": if(parts.Length>0&&parts[0].Equals("RIGHT",StringComparison.OrdinalIgnoreCase)){MacroNative.MouseButton(true,false);MacroNative.MouseButton(true,true);}else if(parts.Length>0&&parts[0].Equals("MIDDLE",StringComparison.OrdinalIgnoreCase)){MacroNative.MiddleButton(false);MacroNative.MiddleButton(true);}else{MacroNative.MouseButton(false,false);MacroNative.MouseButton(false,true);}break;
                    case "RCLICK": MacroNative.MouseButton(true,false);MacroNative.MouseButton(true,true);break;
                    case "MOVE": MacroNative.SetCursorPos(ParseInt(parts[0],-100000,100000),ParseInt(parts[1],-100000,100000));break;
                    case "WHEEL": MacroNative.Wheel(ParseInt(step.Argument,-12000,12000));break;
                    case "IFCOLOR": if(!PixelMatches(parts))index=step.Jump-1;break;
                    case "IFNOTCOLOR": if(PixelMatches(parts))index=step.Jump-1;break;
                    case "WAITCOLOR": WaitColor(parts);break;
                }
            }
            Stop();
        }
        void Tap(ushort key){MacroNative.Key(key,false);Thread.Sleep(20);MacroNative.Key(key,true);}
        void WaitColor(string[] p){if(p.Length<5)throw new InvalidOperationException("WAITCOLOR: X Y #RRGGBB допуск тайм-аут");DateTime until=DateTime.UtcNow.AddMilliseconds(ParseInt(p[4],100,3600000));while(!stop&&!PixelMatches(p)){if(DateTime.UtcNow>=until)throw new TimeoutException("Час очікування кольору вичерпано.");Thread.Sleep(20);}}
        bool PixelMatches(string[] p){if(p.Length<3)throw new InvalidOperationException("Піксель: X Y #RRGGBB [допуск]");Color actual=MacroNative.Pixel(ParseInt(p[0],-100000,100000),ParseInt(p[1],-100000,100000));Color expected=ColorTranslator.FromHtml(p[2].Trim());int tolerance=p.Length>3?ParseInt(p[3],0,255):0;return Math.Abs(actual.R-expected.R)<=tolerance&&Math.Abs(actual.G-expected.G)<=tolerance&&Math.Abs(actual.B-expected.B)<=tolerance;}
        static int ParseInt(string value,int min,int max){int n;if(!int.TryParse(value.Trim(),NumberStyles.Integer,CultureInfo.InvariantCulture,out n)||n<min||n>max)throw new InvalidOperationException("Некоректне число: "+value);return n;}
    }
}
