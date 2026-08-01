using System;
using System.ComponentModel;
using System.Drawing;
using System.Runtime.InteropServices;

namespace CyberPW.Assistant2
{
    internal static class MacroNative
    {
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
        [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr handle, int command);
        [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
        [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT point);
        [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr handle);
        [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr handle, IntPtr dc);
        [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc, int x, int y);
        [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint mapType);
        [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, INPUT[] inputs, int size);

        [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
        [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public INPUTUNION data; }
        [StructLayout(LayoutKind.Explicit)] struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mouse; [FieldOffset(0)] public KEYBDINPUT keyboard; }
        [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx,dy; public uint mouseData,flags,time; public UIntPtr extra; }
        [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort virtualKey,scanCode; public uint flags,time; public UIntPtr extra; }

        static void Send(INPUT[] inputs)
        {
            if(SendInput((uint)inputs.Length,inputs,Marshal.SizeOf(typeof(INPUT)))!=(uint)inputs.Length)
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        public static void Key(ushort key,bool up)
        {
            uint scan=MapVirtualKey(key,0);if(scan==0)throw new InvalidOperationException("No scan code for key: "+key);
            var input=new INPUT();input.type=1;input.data.keyboard.scanCode=(ushort)scan;
            input.data.keyboard.flags=0x8u|(up?0x2u:0u)|(IsExtended(key)?0x1u:0u);Send(new[]{input});
        }
        static bool IsExtended(ushort key)
        {
            return key==0x21||key==0x22||key==0x23||key==0x24||key==0x25||key==0x26||key==0x27||key==0x28||key==0x2D||key==0x2E||key==0x6F||key==0x90||key==0xA3||key==0xA5;
        }
        public static void Text(string text)
        {
            foreach(char c in text){var down=new INPUT();down.type=1;down.data.keyboard.scanCode=c;down.data.keyboard.flags=4;var up=down;up.data.keyboard.flags=6;Send(new[]{down,up});}
        }
        public static void MouseButton(bool right,bool up)
        {
            var input=new INPUT();input.type=0;input.data.mouse.flags=right?(up?0x10u:0x8u):(up?0x4u:0x2u);Send(new[]{input});
        }
        public static void MiddleButton(bool up)
        {
            var input=new INPUT();input.type=0;input.data.mouse.flags=up?0x40u:0x20u;Send(new[]{input});
        }
        public static void Wheel(int delta)
        {
            var input=new INPUT();input.type=0;input.data.mouse.flags=0x800;input.data.mouse.mouseData=unchecked((uint)delta);Send(new[]{input});
        }
        public static Point Cursor()
        {
            POINT point;if(!GetCursorPos(out point))throw new Win32Exception();return new Point(point.X,point.Y);
        }
        public static Color Pixel(int x,int y)
        {
            IntPtr dc=GetDC(IntPtr.Zero);if(dc==IntPtr.Zero)throw new Win32Exception();
            try{uint value=GetPixel(dc,x,y);if(value==0xFFFFFFFF)throw new Win32Exception();return Color.FromArgb((int)(value&255),(int)((value>>8)&255),(int)((value>>16)&255));}
            finally{ReleaseDC(IntPtr.Zero,dc);}
        }
    }
}
