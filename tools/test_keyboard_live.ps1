Add-Type @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class WinInputHelper {
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
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint MapVirtualKey(uint uCode, uint uMapType);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, [Out] byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public uint type;
        public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    public const int INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYDOWN = 0x0000;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint KEYEVENTF_SCANCODE = 0x0008;
    public const uint KEYEVENTF_EXTENDEDKEY = 0x0001;

    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP = 0x0101;
    public const uint WM_CLOSE = 0x0010;

    public const int PROCESS_VM_READ = 0x0010;

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

    public static void SendKeyDirect(ushort vk, bool down) {
        ushort scan = (ushort)MapVirtualKey(vk, 0);
        var input = new INPUT();
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = vk;
        input.ki.wScan = scan;
        input.ki.dwFlags = down ? KEYEVENTF_KEYDOWN : KEYEVENTF_KEYUP;
        if (vk == 0x25 || vk == 0x26 || vk == 0x27 || vk == 0x28) {
            input.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
        }
        SendInput(1, new INPUT[] { input }, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void PostKeyMessage(IntPtr hWnd, ushort vk, bool down) {
        uint scan = MapVirtualKey(vk, 0);
        uint lParam = 1 | (scan << 16);
        if (!down) {
            lParam |= (1u << 30) | (1u << 31);
            PostMessage(hWnd, WM_KEYUP, (IntPtr)vk, (IntPtr)lParam);
        } else {
            PostMessage(hWnd, WM_KEYDOWN, (IntPtr)vk, (IntPtr)lParam);
        }
    }
}
"@

$probeDir = Join-Path $env:LOCALAPPDATA "PilotwingsRunProbe"
$exePath = Join-Path $probeDir "PilotwingsSNESRecomp.exe"
$romPath = "D:\Project\GameRecomp\PilotwingsRecomp\Pilotwings (USA).sfc"

Write-Host "=== Phase E1.1: Live Keyboard Input & Joypad Telemetry Verification ===" -ForegroundColor Cyan

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [WinInputHelper]::FindGameWindow($proc.Id)
Write-Host "Game Window HWND: $hWnd"
if ($hWnd -eq [IntPtr]::Zero) {
    Write-Host "FAIL: Game window not found." -ForegroundColor Red
    $proc.Kill()
    exit 1
}

$baseAddr = $proc.MainModule.BaseAddress
$hProc = [WinInputHelper]::OpenProcess([WinInputHelper]::PROCESS_VM_READ, $false, $proc.Id)
$gRamAddr = [IntPtr]($baseAddr.ToInt64() + 0x1295e0)
$gInputStateAddr = [IntPtr]($baseAddr.ToInt64() + 0xdcfe64)

function ReadTelemetry {
    $bufRam = New-Object byte[] 256
    $bufInput = New-Object byte[] 4
    $readLen = [IntPtr]::Zero
    [WinInputHelper]::ReadProcessMemory($hProc, $gRamAddr, $bufRam, 256, [ref]$readLen) | Out-Null
    [WinInputHelper]::ReadProcessMemory($hProc, $gInputStateAddr, $bufInput, 4, [ref]$readLen) | Out-Null
    $inputVal = [BitConverter]::ToUInt32($bufInput, 0)
    return @{
        InputState = $inputVal
        JoypadHeld = $bufRam[0x78]
        JoypadTrig = $bufRam[0x7A]
        Airspeed   = $bufRam[0x58]
        Altitude   = $bufRam[0x64]
    }
}

# Ensure window is foreground
[WinInputHelper]::SetForegroundWindow($hWnd) | Out-Null
Start-Sleep -Milliseconds 300

Write-Host "`n1. Initial Baseline Telemetry:"
$t0 = ReadTelemetry
Write-Host "  g_input_state: 0x$($t0.InputState.ToString('X4')) | Held (\$78): 0x$($t0.JoypadHeld.ToString('X2')) | Trig (\$7A): 0x$($t0.JoypadTrig.ToString('X2'))"

# Test Key Press: START (VK_RETURN = 0x0D)
Write-Host "`n2. Testing START Key (VK_RETURN = 0x0D)..."
[WinInputHelper]::PostKeyMessage($hWnd, 0x0D, $true)
Start-Sleep -Milliseconds 100
$t1 = ReadTelemetry
Write-Host "  [POST KEY DOWN] g_input_state: 0x$($t1.InputState.ToString('X4')) | Held (\$78): 0x$($t1.JoypadHeld.ToString('X2')) | Trig (\$7A): 0x$($t1.JoypadTrig.ToString('X2'))"

[WinInputHelper]::PostKeyMessage($hWnd, 0x0D, $false)
Start-Sleep -Milliseconds 100
$t2 = ReadTelemetry
Write-Host "  [POST KEY UP]   g_input_state: 0x$($t2.InputState.ToString('X4')) | Held (\$78): 0x$($t2.JoypadHeld.ToString('X2')) | Trig (\$7A): 0x$($t2.JoypadTrig.ToString('X2'))"

# Also test SendKeyDirect (hardware SendInput)
Write-Host "`n3. Testing A Button (Keyboard 'X', VK_X = 0x58) via SendInput..."
[WinInputHelper]::SetForegroundWindow($hWnd) | Out-Null
Start-Sleep -Milliseconds 100
[WinInputHelper]::SendKeyDirect(0x58, $true)
Start-Sleep -Milliseconds 100
$t3 = ReadTelemetry
Write-Host "  [SENDINPUT DOWN] g_input_state: 0x$($t3.InputState.ToString('X4')) | Held (\$78): 0x$($t3.JoypadHeld.ToString('X2')) | Trig (\$7A): 0x$($t3.JoypadTrig.ToString('X2'))"

[WinInputHelper]::SendKeyDirect(0x58, $false)
Start-Sleep -Milliseconds 100
$t4 = ReadTelemetry
Write-Host "  [SENDINPUT UP]   g_input_state: 0x$($t4.InputState.ToString('X4')) | Held (\$78): 0x$($t4.JoypadHeld.ToString('X2')) | Trig (\$7A): 0x$($t4.JoypadTrig.ToString('X2'))"

# Clean up
[WinInputHelper]::CloseHandle($hProc)
[WinInputHelper]::PostMessage($hWnd, [WinInputHelper]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(5000) | Out-Null

$inputWorked = ($t1.InputState -ne 0 -or $t3.InputState -ne 0 -or $t1.JoypadHeld -ne 0 -or $t3.JoypadHeld -ne 0)
Write-Host "`nResult: Input Worked = $inputWorked"
if ($inputWorked) {
    Write-Host "KEYBOARD_INPUT_PASS: SUCCESS!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "KEYBOARD_INPUT_PASS: FAILED!" -ForegroundColor Red
    exit 1
}
