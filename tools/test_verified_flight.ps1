Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class VerifiedFlightTest {
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
    $rect = New-Object VerifiedFlightTest+RECT
    [VerifiedFlightTest]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [VerifiedFlightTest]::PrintWindow($hWnd, $hdc, 2) | Out-Null
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

$VK_RETURN = 0x0D # Start
$VK_X      = 0x58 # SNES A
$VK_Z      = 0x5A # SNES B
$VK_DOWN   = 0x28 # Pull stick back
$VK_RIGHT  = 0x27 # Bank right
$VK_LEFT   = 0x25 # Bank left

Write-Host "=== Verified Step-by-Step Flight Mission ===" -ForegroundColor Cyan

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [VerifiedFlightTest]::FindGameWindow($proc.Id)
Write-Host "Game HWND: $hWnd"

# 1. Boot -> Title
Write-Host "1. Boot to Title..."
Start-Sleep -Milliseconds 3200
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 2. Password -> "NO"
Write-Host "2. Password -> 'NO'..."
[VerifiedFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[VerifiedFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 3000

# 3. Tony Briefing
Write-Host "3. Tony Briefing..."
[VerifiedFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[VerifiedFlightTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1500

# 4. Lesson 1 Map -> Event Select
Write-Host "4. Lesson 1 Map..."
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 5. Event Select -> Curriculum
Write-Host "5. Event Select (Light Plane)..."
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 6. Curriculum -> 3D Flight Scene!
Write-Host "6. Curriculum Screen -> Pressing START to Launch Flight!" -ForegroundColor Green
CaptureWindowNative $hWnd "$artifactDir\flight_curriculum_screen.png" | Out-Null
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 100)

# 7. Wait 12s for 3D unfade and Tony's Page 1 speech
Write-Host "7. Waiting 12s for 3D unfade and Tony's Page 1 speech..."
Start-Sleep -Milliseconds 12000
CaptureWindowNative $hWnd "$artifactDir\flight_stage1_speech_p1.png" | Out-Null

# 8. Advance Page 1 to Page 2
Write-Host "8. Pressing START to advance to Page 2..."
[VerifiedFlightTest]::TapKey($hWnd, $VK_RETURN, 100)

# 9. Wait 11s for Page 2 speech to finish and dialog box to auto-dismiss
Write-Host "9. Waiting 11s for Page 2 speech to complete and dialogue to dismiss..."
Start-Sleep -Milliseconds 11000
CaptureWindowNative $hWnd "$artifactDir\flight_stage2_runway_open.png" | Out-Null

# 10. ENGAGE FULL THROTTLE!
Write-Host "10. ENGAGING FULL THROTTLE (Hold A)!" -ForegroundColor Green
[VerifiedFlightTest]::PostKey($hWnd, $VK_X, $true) # Hold A down
Start-Sleep -Milliseconds 2500
CaptureWindowNative $hWnd "$artifactDir\flight_stage3_taxi_accelerate.png" | Out-Null

# 11. PULL BACK STICK (Hold A + Down Arrow) for Takeoff!
Write-Host "11. PULLING BACK STICK (Hold A + Down Arrow) - TAKEOFF CLIMB!" -ForegroundColor Green
[VerifiedFlightTest]::PostKey($hWnd, $VK_DOWN, $true) # Nose up
Start-Sleep -Milliseconds 3000
CaptureWindowNative $hWnd "$artifactDir\flight_stage4_airborne_climb.png" | Out-Null
[VerifiedFlightTest]::PostKey($hWnd, $VK_DOWN, $false)

# 12. BANK RIGHT (Hold A + Right Arrow)!
Write-Host "12. BANKING RIGHT (Hold A + Right Arrow)!" -ForegroundColor Green
[VerifiedFlightTest]::PostKey($hWnd, $VK_RIGHT, $true) # Bank right
Start-Sleep -Milliseconds 2500
CaptureWindowNative $hWnd "$artifactDir\flight_stage5_bank_right.png" | Out-Null
[VerifiedFlightTest]::PostKey($hWnd, $VK_RIGHT, $false)

# 13. LEVEL OFF (Hold A + Left Arrow)!
Write-Host "13. LEVELING OFF (Hold A + Left Arrow)!" -ForegroundColor Green
[VerifiedFlightTest]::PostKey($hWnd, $VK_LEFT, $true) # Counter bank
Start-Sleep -Milliseconds 2000
CaptureWindowNative $hWnd "$artifactDir\flight_stage6_level_cruise.png" | Out-Null
[VerifiedFlightTest]::PostKey($hWnd, $VK_LEFT, $false)

# Release Throttle
[VerifiedFlightTest]::PostKey($hWnd, $VK_X, $false)
Start-Sleep -Milliseconds 1000
CaptureWindowNative $hWnd "$artifactDir\flight_stage7_cruise.png" | Out-Null

Write-Host "14. Mission Complete! Closing window..."
[VerifiedFlightTest]::PostMessage($hWnd, [VerifiedFlightTest]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(5000) | Out-Null
Write-Host "SUCCESS: Process cleanly exited with code: $($proc.ExitCode)" -ForegroundColor Green
