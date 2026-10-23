Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinHelper {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsHungAppWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public const uint WM_CLOSE = 0x0010;

    public static List<IntPtr> GetProcessWindows(uint pid) {
        var list = new List<IntPtr>();
        EnumWindows((hWnd, lParam) => {
            uint windowPid;
            GetWindowThreadProcessId(hWnd, out windowPid);
            if (windowPid == pid) {
                list.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
"@

$probeDir = Join-Path $env:LOCALAPPDATA "PilotwingsRunProbe"
$exePath = Join-Path $probeDir "PilotwingsSNESRecomp.exe"
$romPath = "D:\Project\GameRecomp\PilotwingsRecomp\Pilotwings (USA).sfc"

Write-Host "=== Phase E1.1: Interactive Window Launch & Enumeration ===" -ForegroundColor Cyan

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$windows = [WinHelper]::GetProcessWindows($proc.Id)
Write-Host "Found $($windows.Count) windows for PID $($proc.Id)"

$gameHwnd = [IntPtr]::Zero

foreach ($w in $windows) {
    $sbTitle = New-Object System.Text.StringBuilder 256
    [WinHelper]::GetWindowText($w, $sbTitle, 256) | Out-Null
    $sbClass = New-Object System.Text.StringBuilder 256
    [WinHelper]::GetClassName($w, $sbClass, 256) | Out-Null
    $vis = [WinHelper]::IsWindowVisible($w)
    $hung = [WinHelper]::IsHungAppWindow($w)
    $rect = New-Object WinHelper+RECT
    [WinHelper]::GetWindowRect($w, [ref]$rect) | Out-Null
    $w_w = $rect.Right - $rect.Left
    $w_h = $rect.Bottom - $rect.Top
    $title = $sbTitle.ToString()
    $cls = $sbClass.ToString()
    Write-Host "  HWND: $w | Class: '$cls' | Title: '$title' | Vis: $vis | Hung: $hung | Size: ${w_w}x${w_h}"
    if ($title -match "Pilotwings" -or $cls -match "SDL_app") {
        $gameHwnd = $w
    }
}

if ($gameHwnd -ne [IntPtr]::Zero) {
    Write-Host "`nTarget SDL Game Window Identified: HWND $gameHwnd" -ForegroundColor Green
    
    # Focus
    [WinHelper]::SetForegroundWindow($gameHwnd) | Out-Null
    Start-Sleep -Milliseconds 500
    $fg = [WinHelper]::GetForegroundWindow()
    Write-Host "Window Focus Activated: $($fg -eq $gameHwnd)"
    
    # Clean shutdown via WM_CLOSE on game window
    Write-Host "Closing game window via WM_CLOSE..."
    [WinHelper]::PostMessage($gameHwnd, [WinHelper]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    $finished = $proc.WaitForExit(5000)
    Write-Host "Process Cleanly Exited: $finished (ExitCode=$($proc.ExitCode))"
    if ($finished -and $proc.ExitCode -eq 0) {
        Write-Host "WINDOW_INTERACTIVE_PASS: SUCCESS!" -ForegroundColor Green
        exit 0
    }
}

if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force
}
Write-Host "WINDOW_INTERACTIVE_PASS: FAILED!" -ForegroundColor Red
exit 1
