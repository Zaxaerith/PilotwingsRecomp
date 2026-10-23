Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class PitchTest {
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
    $rect = New-Object PitchTest+RECT
    [PitchTest]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [PitchTest]::PrintWindow($hWnd, $hdc, 2) | Out-Null
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
$VK_Z      = 0x5A # SNES B (Brake)
$VK_DOWN   = 0x28 # Down Arrow
$VK_UP     = 0x26 # Up Arrow

Write-Host "=== Pilotwings Flight Dynamics & Pitch Response Test ===" -ForegroundColor Cyan

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [PitchTest]::FindGameWindow($proc.Id)
$baseAddr = $proc.MainModule.BaseAddress
$hProc = [PitchTest]::OpenProcess([PitchTest]::PROCESS_VM_READ, $false, $proc.Id)
$gRamAddr = [IntPtr]($baseAddr.ToInt64() + 0x1295e0)
$gInputStateAddr = [IntPtr]($baseAddr.ToInt64() + 0xdcfe64)

function ReadTelemetry {
    $bufRam = New-Object byte[] 0x2000
    $bufInput = New-Object byte[] 4
    $len = [IntPtr]::Zero
    [PitchTest]::ReadProcessMemory($hProc, $gRamAddr, $bufRam, 0x2000, [ref]$len) | Out-Null
    [PitchTest]::ReadProcessMemory($hProc, $gInputStateAddr, $bufInput, 4, [ref]$len) | Out-Null
    return @{
        Alt        = [BitConverter]::ToInt16($bufRam, 0x64)
        Speed      = [BitConverter]::ToUInt16($bufRam, 0x1FAC)
        InputState = [BitConverter]::ToUInt32($bufInput, 0)
        JoypadHeld = $bufRam[0x78]
        PitchAngle = [BitConverter]::ToInt16($bufRam, 0x1FE2)
    }
}

# Boot -> Curriculum
Write-Host "Navigating to Curriculum..."
Start-Sleep -Milliseconds 3200
[PitchTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000
[PitchTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[PitchTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[PitchTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 3000
[PitchTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[PitchTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[PitchTest]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[PitchTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1500
[PitchTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000
[PitchTest]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000

# Launch Flight!
Write-Host "Pressing START on Curriculum..."
[PitchTest]::TapKey($hWnd, $VK_RETURN, 100)

# Wait for 3D activation
while ($true) {
    Start-Sleep -Milliseconds 100
    $t = ReadTelemetry
    if ($t.Alt -gt 100) { break }
}
Write-Host ">>> In Flight at Alt=$($t.Alt) Speed=$($t.Speed) <<<" -ForegroundColor Green

# Test: Instead of holding Full Throttle A (which caused overspeed descent),
# Let's hold Down Arrow (VK_DOWN) and TAP Throttle A gently!
Write-Host "Applying PULL UP (Down Arrow) + Light Throttle Pulse..."
[PitchTest]::PostKey($hWnd, $VK_DOWN, $true)

for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Milliseconds 300
    $t = ReadTelemetry
    Write-Host ("  [Sec {0:F1}] Alt={1} Speed={2} Pitch={3} Input=0x{4:X4} Held=0x{5:X2}" -f `
        ($i * 0.3), $t.Alt, $t.Speed, $t.PitchAngle, $t.InputState, $t.JoypadHeld)
    CaptureWindowNative $hWnd "$artifactDir\pitch_sample_$i.png" | Out-Null
}

[PitchTest]::PostKey($hWnd, $VK_DOWN, $false)
[PitchTest]::CloseHandle($hProc)
[PitchTest]::PostMessage($hWnd, [PitchTest]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(3000) | Out-Null
