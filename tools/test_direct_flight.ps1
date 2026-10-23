Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class DirectFlightTest {
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
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBmp, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint MapVirtualKey(uint uCode, uint uMapType);

    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP = 0x0101;
    public const uint WM_CLOSE = 0x0010;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static IntPtr FindGameWindow(uint pid) {
        IntPtr target = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            uint windowPid;
            GetWindowThreadProcessId(hWnd, out windowPid);
            if (windowPid == pid) {
                var sbClass = new StringBuilder(256);
                GetClassName(hWnd, sbClass, 256);
                var sbTitle = new StringBuilder(256);
                GetWindowText(hWnd, sbTitle, 256);
                if (sbTitle.ToString().Contains("Pilotwings") || sbClass.ToString().Contains("SDL_app")) {
                    target = hWnd;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return target;
    }

    public static void PostKey(IntPtr hWnd, ushort vk, bool down) {
        uint scan = MapVirtualKey(vk, 0);
        uint lParam = 1 | (scan << 16);
        if (vk >= 0x21 && vk <= 0x28) {
            lParam |= (1u << 24); // extended key
        }
        if (!down) {
            lParam |= (1u << 30) | (1u << 31);
            PostMessage(hWnd, WM_KEYUP, (IntPtr)vk, (IntPtr)lParam);
        } else {
            PostMessage(hWnd, WM_KEYDOWN, (IntPtr)vk, (IntPtr)lParam);
        }
    }

    public static void TapKey(IntPtr hWnd, ushort vk, int holdMs) {
        PostKey(hWnd, vk, true);
        Thread.Sleep(holdMs);
        PostKey(hWnd, vk, false);
    }
}
"@

function CaptureWindowNative([IntPtr]$hWnd, [string]$savePath) {
    $rect = New-Object DirectFlightTest+RECT
    [DirectFlightTest]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [DirectFlightTest]::PrintWindow($hWnd, $hdc, 2) | Out-Null
    $g.ReleaseHdc($hdc)
    $g.Dispose()
    $bmp.Save($savePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $true
}

$probeDir = Join-Path $env:LOCALAPPDATA "PilotwingsRunProbe"
$exePath = Join-Path $probeDir "PilotwingsSNESRecomp.exe"
$romPath = "D:\Project\GameRecomp\PilotwingsRecomp\Pilotwings (USA).sfc"
$artifactDir = "C:\Users\KEPLER\.gemini\antigravity\brain\1f146d3d-74a4-40b0-8454-09f7e8be3fe8"

$VK_RETURN = 0x0D # Start
$VK_X      = 0x58 # SNES A
$VK_Z      = 0x5A # SNES B

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [DirectFlightTest]::FindGameWindow($proc.Id)
Write-Host "Game HWND: $hWnd"

# 1. Boot -> Title
Write-Host "1. Boot to Title..."
Start-Sleep -Milliseconds 3200
[DirectFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 2. Password -> "NO"
Write-Host "2. Password -> 'NO'..."
[DirectFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DirectFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DirectFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 3000

# 3. Tony Briefing
Write-Host "3. Tony Briefing..."
[DirectFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DirectFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[DirectFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DirectFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1500

# 4. Lesson 1 Map
Write-Host "4. Lesson 1 Map..."
CaptureWindowNative $hWnd "$artifactDir\step4_map.png" | Out-Null
[DirectFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 5. Curriculum Screen
Write-Host "5. Curriculum Screen..."
CaptureWindowNative $hWnd "$artifactDir\step5_curriculum.png" | Out-Null
[DirectFlightTest]::TapKey($hWnd, $VK_RETURN, 100)
Write-Host "Pressed START on Curriculum! Waiting 4.5s for 3D flight scene..."
Start-Sleep -Milliseconds 4500

# 6. In-Cockpit 3D Scene!
CaptureWindowNative $hWnd "$artifactDir\step6_flight_scene.png" | Out-Null
Write-Host "Captured step6_flight_scene.png!"

[DirectFlightTest]::PostMessage($hWnd, [DirectFlightTest]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(3000) | Out-Null
