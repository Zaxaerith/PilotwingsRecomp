Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class ActiveFlightTest {
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
    $rect = New-Object ActiveFlightTest+RECT
    [ActiveFlightTest]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [ActiveFlightTest]::PrintWindow($hWnd, $hdc, 2) | Out-Null
    $g.ReleaseHdc($hdc)
    $g.Dispose()
    $bmp.Save($savePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $true
}

$probeDir = Join-Path $env:LOCALAPPDATA "PilotwingsRunProbe"
$exePath = Join-Path $probeDir "PilotwingsSNESRecomp.exe"
$romPath = "$PSScriptRoot\..\Pilotwings (USA).sfc"
$artifactDir = "$PSScriptRoot\..\diagnostics\artifacts"

Write-Host "=== Pilotwings Active Flight Real-Time Control Probe ===" -ForegroundColor Cyan

# Virtual Keys
$VK_RETURN = 0x0D # Start
$VK_X      = 0x58 # SNES A (Throttle)
$VK_Z      = 0x5A # SNES B
$VK_DOWN   = 0x28 # Pull stick back (climb)
$VK_UP     = 0x26 # Push stick forward (dive)
$VK_RIGHT  = 0x27 # Bank right
$VK_LEFT   = 0x25 # Bank left

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [ActiveFlightTest]::FindGameWindow($proc.Id)
Write-Host "Game HWND: $hWnd"

# 1. Boot -> Title Screen
Write-Host "1. Title Screen..."
Start-Sleep -Milliseconds 3200
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 2. Password -> "NO"
Write-Host "2. Password Screen -> 'NO'..."
[ActiveFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 3000

# 3. Tony Briefing
Write-Host "3. Tony Briefing..."
[ActiveFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000

# 4. Light Plane Select
Write-Host "4. Select Light Plane..."
[ActiveFlightTest]::TapKey($hWnd, $VK_Z, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 5. Controls screens -> Curriculum
Write-Host "5. Stepping through Controls..."
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_Z, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[ActiveFlightTest]::TapKey($hWnd, $VK_Z, 80)
Start-Sleep -Milliseconds 1000

# On Curriculum screen: Launch the flight!
Write-Host "6. Launching Flight from Curriculum..."
Start-Sleep -Milliseconds 1500
CaptureWindowNative $hWnd "$artifactDir\live_curriculum_ready.png" | Out-Null
[ActiveFlightTest]::TapKey($hWnd, $VK_RETURN, 100)

# Scene loads & unfades in ~3 seconds
Write-Host "7. Waiting 3.5s for 3D flight scene to un-fade..."
Start-Sleep -Milliseconds 3500
CaptureWindowNative $hWnd "$artifactDir\live_cockpit_approach.png" | Out-Null

# IMMEDIATELY engage Throttle (A) and pull Nose Up (Down Arrow)!
Write-Host "8. ENGAGING THROTTLE (Hold A) & PULLING NOSE UP (Down Arrow)!" -ForegroundColor Green
[ActiveFlightTest]::PostKey($hWnd, $VK_X, $true)    # Throttle A down
[ActiveFlightTest]::PostKey($hWnd, $VK_DOWN, $true) # Elevator up

# Climb for 3 seconds
Start-Sleep -Milliseconds 3000
CaptureWindowNative $hWnd "$artifactDir\live_airborne_climbing.png" | Out-Null

# Bank Right in Mid-Air
Write-Host "9. BANKING RIGHT (Hold A + Right Arrow)..." -ForegroundColor Green
[ActiveFlightTest]::PostKey($hWnd, $VK_DOWN, $false)
[ActiveFlightTest]::PostKey($hWnd, $VK_RIGHT, $true) # Bank right
Start-Sleep -Milliseconds 3000
CaptureWindowNative $hWnd "$artifactDir\live_banking_right.png" | Out-Null

# Level Off
Write-Host "10. LEVELING OFF (Hold A + Left Arrow)..." -ForegroundColor Green
[ActiveFlightTest]::PostKey($hWnd, $VK_RIGHT, $false)
[ActiveFlightTest]::PostKey($hWnd, $VK_LEFT, $true) # Counter-bank
Start-Sleep -Milliseconds 2500
CaptureWindowNative $hWnd "$artifactDir\live_level_flight.png" | Out-Null

# Cruise
[ActiveFlightTest]::PostKey($hWnd, $VK_LEFT, $false)
Write-Host "11. Cruising in Mid-Air..." -ForegroundColor Green
Start-Sleep -Milliseconds 3000
CaptureWindowNative $hWnd "$artifactDir\live_cruising.png" | Out-Null

# Release Throttle
[ActiveFlightTest]::PostKey($hWnd, $VK_X, $false)

# Clean exit
Write-Host "12. Mission completed. Closing window..."
[ActiveFlightTest]::PostMessage($hWnd, [ActiveFlightTest]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(5000) | Out-Null
Write-Host "SUCCESS: Process exited cleanly with code: $($proc.ExitCode)" -ForegroundColor Green
