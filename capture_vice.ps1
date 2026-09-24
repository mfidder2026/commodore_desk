Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
public class WinCapture {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    // Flag 3 = PW_RENDERFULLCONTENT (needed for DWM-composited / hw-accelerated windows like VICE/SDL)
    public static Bitmap Capture(IntPtr hWnd) {
        SetForegroundWindow(hWnd);
        System.Threading.Thread.Sleep(150);   // give DWM time to render a fresh frame
        RECT rc;
        GetWindowRect(hWnd, out rc);
        int w = rc.Right - rc.Left;
        int h = rc.Bottom - rc.Top;
        if (w <= 0 || h <= 0) return null;
        Bitmap bmp = new Bitmap(w, h);
        using (Graphics g = Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            PrintWindow(hWnd, hdc, 3);
            g.ReleaseHdc(hdc);
        }
        return bmp;
    }
}
"@

$p = Get-Process x64sc -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$p) { $p = Get-Process x64sc.exe -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (!$p) { Write-Host 'no x64sc process'; exit 1 }
$h = $p.MainWindowHandle
if ($h -eq 0) { Write-Host 'no main window handle'; exit 1 }

$bmp = [WinCapture]::Capture($h)
if (!$bmp) { Write-Host 'capture failed (zero-size rect)'; exit 1 }
$out = 'C:\Users\aegwh\OneDrive\dev\kelda\kelda\vice_window.png'
$bmp.Save($out)
$bmp.Dispose()
Write-Host "captured -> $out"
