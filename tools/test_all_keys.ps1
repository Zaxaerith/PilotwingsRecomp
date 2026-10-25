Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class WinInputTester {
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
            // Extended keys: PageUp, PageDown, End, Home, Left, Up, Right, Down
            lParam |= (1u << 24);
        }
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
$romPath = "$PSScriptRoot\..\Pilotwings (USA).sfc"

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [WinInputTester]::FindGameWindow($proc.Id)
$baseAddr = $proc.MainModule.BaseAddress
$hProc = [WinInputTester]::OpenProcess([WinInputTester]::PROCESS_VM_READ, $false, $proc.Id)
$gInputStateAddr = [IntPtr]($baseAddr.ToInt64() + 0xdcfe64)

function ReadInputState {
    $buf = New-Object byte[] 4
    $readLen = [IntPtr]::Zero
    [WinInputTester]::ReadProcessMemory($hProc, $gInputStateAddr, $buf, 4, [ref]$readLen) | Out-Null
    return [BitConverter]::ToUInt32($buf, 0)
}

$testKeys = @(
    @{ Name = "Start (Return)"; VK = 0x0D; ExpectedBit = 0x0008 },
    @{ Name = "A (Keyboard X)"; VK = 0x58; ExpectedBit = 0x0100 },
    @{ Name = "B (Keyboard Z)"; VK = 0x5A; ExpectedBit = 0x0001 },
    @{ Name = "X (Keyboard S)"; VK = 0x53; ExpectedBit = 0x0200 },
    @{ Name = "Y (Keyboard A)"; VK = 0x41; ExpectedBit = 0x0002 },
    @{ Name = "Up (Up Arrow)"; VK = 0x26; ExpectedBit = 0x0010 },
    @{ Name = "Down (Down Arrow)"; VK = 0x28; ExpectedBit = 0x0020 },
    @{ Name = "Left (Left Arrow)"; VK = 0x25; ExpectedBit = 0x0040 },
    @{ Name = "Right (Right Arrow)"; VK = 0x27; ExpectedBit = 0x0080 }
)

Write-Host "=== Testing All Controller Button Mappings via PostKey ===" -ForegroundColor Cyan
$allPassed = $true

foreach ($k in $testKeys) {
    [WinInputTester]::PostKey($hWnd, $k.VK, $true)
    Start-Sleep -Milliseconds 60
    $stateDown = ReadInputState
    
    [WinInputTester]::PostKey($hWnd, $k.VK, $false)
    Start-Sleep -Milliseconds 60
    $stateUp = ReadInputState
    
    $hit = (($stateDown -band [uint32]$k.ExpectedBit) -eq [uint32]$k.ExpectedBit)
    $cleared = (($stateUp -band [uint32]$k.ExpectedBit) -eq 0)
    $ok = $hit -and $cleared
    $statusStr = if ($ok) { "PASS" } else { "FAIL" }
    Write-Host ("  Key {0,-18} (VK 0x{1:X2}): Down=0x{2:X4} (Expect 0x{3:X4}) | Up=0x{4:X4} -> {5}" -f `
        $k.Name, $k.VK, $stateDown, $k.ExpectedBit, $stateUp, $statusStr)
    if (-not $ok) { $allPassed = $false }
}

[WinInputTester]::CloseHandle($hProc)
[WinInputTester]::PostMessage($hWnd, [WinInputTester]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$proc.WaitForExit(5000) | Out-Null

Write-Host "`nAll Key Mappings Passed: $allPassed" -ForegroundColor $(if ($allPassed) { "Green" } else { "Red" })
