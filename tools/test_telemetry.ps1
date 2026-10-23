Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class MemoryReader {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, [Out] byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);

    public const int PROCESS_VM_READ = 0x0010;
}
"@

$probeDir = Join-Path $env:LOCALAPPDATA "PilotwingsRunProbe"
$exePath = Join-Path $probeDir "PilotwingsSNESRecomp.exe"
$romPath = "D:\Project\GameRecomp\PilotwingsRecomp\Pilotwings (USA).sfc"

$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 2

$proc.Refresh()
$mainModule = $proc.MainModule
$baseAddr = $mainModule.BaseAddress
Write-Host "Module Base: 0x$($baseAddr.ToString('X'))"

$hProc = [MemoryReader]::OpenProcess([MemoryReader]::PROCESS_VM_READ, $false, $proc.Id)
if ($hProc -ne [IntPtr]::Zero) {
    # g_ram offset: 0x1295e0
    $gRamAddr = [IntPtr]($baseAddr.ToInt64() + 0x1295e0)
    $buf = New-Object byte[] 256
    $bytesRead = [IntPtr]::Zero
    $res = [MemoryReader]::ReadProcessMemory($hProc, $gRamAddr, $buf, 256, [ref]$bytesRead)
    Write-Host "ReadProcessMemory g_ram: $res ($bytesRead bytes read)"
    Write-Host "Byte at 0x78 (Joypad Held): 0x$($buf[0x78].ToString('X2'))"
    Write-Host "Byte at 0x7A (Joypad Trig): 0x$($buf[0x7A].ToString('X2'))"
    [MemoryReader]::CloseHandle($hProc)
}

$proc.Kill()
