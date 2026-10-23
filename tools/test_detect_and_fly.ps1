Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class DetectAndFly {
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

    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, [Out] byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);

    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP = 0x0101;
    public const uint WM_CLOSE = 0x0010;
    public const int PROCESS_VM_READ = 0x0010;

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
    $rect = New-Object DetectAndFly+RECT
    [DetectAndFly]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [DetectAndFly]::PrintWindow($hWnd, $hdc, 2) | Out-Null
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
$VK_X      = 0x58 # SNES A (Throttle)
$VK_Z      = 0x5A # SNES B
$VK_DOWN   = 0x28 # Pull stick back (Nose Up / Climb)
$VK_UP     = 0x26 # Push stick forward
$VK_RIGHT  = 0x27 # Bank right
$VK_LEFT   = 0x25 # Bank left

Write-Host "=== Pilotwings Memory-Synchronized Flight Control Mission ===" -ForegroundColor Cyan

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [DetectAndFly]::FindGameWindow($proc.Id)
Write-Host "Game HWND: $hWnd"

$baseAddr = $proc.MainModule.BaseAddress
$hProc = [DetectAndFly]::OpenProcess([DetectAndFly]::PROCESS_VM_READ, $false, $proc.Id)
$gRamAddr = [IntPtr]($baseAddr.ToInt64() + 0x1295e0)

function ReadRam {
    $buf = New-Object byte[] 0x2000
    $len = [IntPtr]::Zero
    [DetectAndFly]::ReadProcessMemory($hProc, $gRamAddr, $buf, 0x2000, [ref]$len) | Out-Null
    return @{
        Alt   = [BitConverter]::ToInt16($buf, 0x64)
        Coord = [BitConverter]::ToUInt16($buf, 0x1FE4)
        Speed = [BitConverter]::ToUInt16($buf, 0x1FAC)
        Mode  = $buf[0xB0]
    }
}

# 1. Boot to Title
Write-Host "1. Booting..."
Start-Sleep -Milliseconds 3200
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 2. Password -> "NO"
Write-Host "2. Password -> 'NO'..."
[DetectAndFly]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DetectAndFly]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 3000

# 3. Tony Briefing
Write-Host "3. Tony Briefing..."
[DetectAndFly]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[DetectAndFly]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1500

# 4. Lesson 1 Map -> Event Select
Write-Host "4. Lesson 1 Map..."
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 5. Event Select -> Curriculum
Write-Host "5. Event Select..."
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# 6. Curriculum -> Launch Flight
Write-Host "6. Curriculum Screen: Pressing START..." -ForegroundColor Green
CaptureWindowNative $hWnd "$artifactDir\e1_step0_curriculum.png" | Out-Null
[DetectAndFly]::TapKey($hWnd, $VK_RETURN, 100)

# Poll for 3D flight scene activation:
# In Curriculum, Alt is 0. In 3D flight, Alt becomes 540!
Write-Host "Polling for 3D flight scene activation (waiting for Alt > 100)..." -ForegroundColor Cyan
$flightActive = $false
$pollSw = [System.Diagnostics.Stopwatch]::StartNew()

while ($pollSw.ElapsedMilliseconds -lt 15000) {
    Start-Sleep -Milliseconds 200
    $ram = ReadRam
    if ($ram.Alt -gt 100) {
        $flightActive = $true
        Write-Host ">>> 3D FLIGHT SCENE ACTIVATED at $($pollSw.ElapsedMilliseconds)ms! Alt=$($ram.Alt) Mode=$($ram.Mode) <<<" -ForegroundColor Green
        break
    }
}

if (-not $flightActive) {
    Write-Host "WARNING: Polling timed out. Alt did not exceed 100. Current Alt = $($ram.Alt)" -ForegroundColor Yellow
}

# Capture initial flight cockpit view
CaptureWindowNative $hWnd "$artifactDir\e1_step1_cockpit_approach.png" | Out-Null

# 7. ENGAGE CONTROLS IMMEDIATELY!
Write-Host "7. Engaging Full Throttle (A) and Pulling Stick Back (Down Arrow)!" -ForegroundColor Green
[DetectAndFly]::PostKey($hWnd, $VK_X, $true)    # Throttle A down
[DetectAndFly]::PostKey($hWnd, $VK_DOWN, $true) # Elevator up

# Sample and capture every 500ms for 4 seconds
for ($i = 1; $i -le 8; $i++) {
    Start-Sleep -Milliseconds 500
    $ram = ReadRam
    Write-Host ("  [Climb {0}] Elapsed={1}ms Alt={2} Speed={3} Coord={4}" -f $i, $pollSw.ElapsedMilliseconds, $ram.Alt, $ram.Speed, $ram.Coord)
}
CaptureWindowNative $hWnd "$artifactDir\e1_step2_airborne_climb.png" | Out-Null

# 8. Bank Right in Mid-Air!
Write-Host "8. Banking Right (Hold A + Right Arrow)!" -ForegroundColor Green
[DetectAndFly]::PostKey($hWnd, $VK_DOWN, $false)
[DetectAndFly]::PostKey($hWnd, $VK_RIGHT, $true) # Bank right

for ($i = 1; $i -le 6; $i++) {
    Start-Sleep -Milliseconds 500
    $ram = ReadRam
    Write-Host ("  [Bank {0}] Elapsed={1}ms Alt={2} Speed={3} Coord={4}" -f $i, $pollSw.ElapsedMilliseconds, $ram.Alt, $ram.Speed, $ram.Coord)
}
CaptureWindowNative $hWnd "$artifactDir\e1_step3_banking_right.png" | Out-Null

# 9. Counter-Bank Left to Level Off
Write-Host "9. Leveling Off (Hold A + Left Arrow)!" -ForegroundColor Green
[DetectAndFly]::PostKey($hWnd, $VK_RIGHT, $false)
[DetectAndFly]::PostKey($hWnd, $VK_LEFT, $true)

for ($i = 1; $i -le 5; $i++) {
    Start-Sleep -Milliseconds 500
    $ram = ReadRam
    Write-Host ("  [Level {0}] Elapsed={1}ms Alt={2} Speed={3} Coord={4}" -f $i, $pollSw.ElapsedMilliseconds, $ram.Alt, $ram.Speed, $ram.Coord)
}
CaptureWindowNative $hWnd "$artifactDir\e1_step4_level_flight.png" | Out-Null
[DetectAndFly]::PostKey($hWnd, $VK_LEFT, $false)

# 10. Cruise
Write-Host "10. Level Cruise..." -ForegroundColor Green
for ($i = 1; $i -le 6; $i++) {
    Start-Sleep -Milliseconds 500
    $ram = ReadRam
    Write-Host ("  [Cruise {0}] Elapsed={1}ms Alt={2} Speed={3} Coord={4}" -f $i, $pollSw.ElapsedMilliseconds, $ram.Alt, $ram.Speed, $ram.Coord)
}
CaptureWindowNative $hWnd "$artifactDir\e1_step5_cruising_flight.png" | Out-Null

# Release Throttle
[DetectAndFly]::PostKey($hWnd, $VK_X, $false)

# Clean exit
Write-Host "11. Mission Complete. Closing window..." -ForegroundColor Cyan
[DetectAndFly]::CloseHandle($hProc)
[DetectAndFly]::PostMessage($hWnd, [DetectAndFly]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(5000) | Out-Null
Write-Host "SUCCESS: Process cleanly exited with code: $($proc.ExitCode)" -ForegroundColor Green
