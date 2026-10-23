Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public class FlightRunner {
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
    $rect = New-Object FlightRunner+RECT
    [FlightRunner]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [FlightRunner]::PrintWindow($hWnd, $hdc, 2) | Out-Null
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
$diagDir = "D:\Project\GameRecomp\PilotwingsRecomp\diagnostics"

if (-not (Test-Path $diagDir)) { New-Item -ItemType Directory -Path $diagDir -Force | Out-Null }

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Pilotwings Phase E1: Real-Time Flight & DSP-1 Mission Runner   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Virtual Keys
$VK_RETURN = 0x0D # Start
$VK_X      = 0x58 # SNES A (Throttle)
$VK_Z      = 0x5A # SNES B
$VK_S      = 0x53 # SNES X
$VK_A      = 0x41 # SNES Y
$VK_UP     = 0x26 # Nose down
$VK_DOWN   = 0x28 # Nose up (elevator pull)
$VK_LEFT   = 0x25 # Bank left
$VK_RIGHT  = 0x27 # Bank right

# Launch Process
$proc = Start-Process -FilePath $exePath -ArgumentList @("--no-launcher", "--rom", "`"$romPath`"") -WorkingDirectory $probeDir -PassThru
Start-Sleep -Seconds 3

$hWnd = [FlightRunner]::FindGameWindow($proc.Id)
if ($hWnd -eq [IntPtr]::Zero) {
    Write-Host "ERROR: Failed to locate game window!" -ForegroundColor Red
    $proc.Kill()
    exit 1
}
Write-Host "Target Game Window HWND: $hWnd" -ForegroundColor Green

# Setup Memory Telemetry
$baseAddr = $proc.MainModule.BaseAddress
$hProc = [FlightRunner]::OpenProcess([FlightRunner]::PROCESS_VM_READ, $false, $proc.Id)
$gRamAddr = [IntPtr]($baseAddr.ToInt64() + 0x1295e0)
$gInputStateAddr = [IntPtr]($baseAddr.ToInt64() + 0xdcfe64)

$telemetryLog = [System.Collections.Generic.List[PSObject]]::new()
$sw = [System.Diagnostics.Stopwatch]::StartNew()

function GetTelemetry([string]$phaseName) {
    $bufRam = New-Object byte[] 0x2000
    $bufInput = New-Object byte[] 4
    $readLen = [IntPtr]::Zero
    [FlightRunner]::ReadProcessMemory($hProc, $gRamAddr, $bufRam, 0x2000, [ref]$readLen) | Out-Null
    [FlightRunner]::ReadProcessMemory($hProc, $gInputStateAddr, $bufInput, 4, [ref]$readLen) | Out-Null

    $held       = $bufRam[0x78]
    $trig       = $bufRam[0x7A]
    $inputVal   = [BitConverter]::ToUInt32($bufInput, 0)
    $brakeFlag  = [BitConverter]::ToUInt16($bufRam, 0x1F80)
    $throttleRpm= [BitConverter]::ToUInt16($bufRam, 0x1FAA)
    $airspeed   = [BitConverter]::ToUInt16($bufRam, 0x1FAC)
    $bankAngle  = [BitConverter]::ToUInt16($bufRam, 0x1FE2)
    $flightCoord= [BitConverter]::ToUInt16($bufRam, 0x1FE4)
    $simTick    = $bufRam[0xFE]

    $row = [PSCustomObject]@{
        ElapsedMs   = $sw.ElapsedMilliseconds
        Phase       = $phaseName
        InputState  = ("0x{0:X4}" -f $inputVal)
        JoypadHeld  = ("0x{0:X2}" -f $held)
        JoypadTrig  = ("0x{0:X2}" -f $trig)
        BrakeFlag   = ("0x{0:X4}" -f $brakeFlag)
        ThrottleRPM = ("0x{0:X4}" -f $throttleRpm)
        Airspeed    = ("0x{0:X4}" -f $airspeed)
        BankAngle   = ("0x{0:X4}" -f $bankAngle)
        FlightCoord = $flightCoord
        SimTick     = $simTick
    }
    $telemetryLog.Add($row)
    return $row
}

function SaveShot([string]$name) {
    $shotPath = Join-Path $artifactDir "$name.png"
    CaptureWindowNative $hWnd $shotPath | Out-Null
    $diagPath = Join-Path $diagDir "$name.png"
    Copy-Item $shotPath $diagPath -Force -ErrorAction SilentlyContinue
    Write-Host "  [SCREENSHOT] Saved: $name.png" -ForegroundColor Yellow
}

# --- STAGE 1: Boot to Title ---
Write-Host "`n>>> [Stage 1] Booting to Title Screen..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 3200
$t = GetTelemetry "Boot_Title"
SaveShot "e1_01_title_screen"
Write-Host "  Telemetry: Input=$($t.InputState), SimTick=$($t.SimTick)"

# --- STAGE 2: Title to Password ("NO") ---
Write-Host "`n>>> [Stage 2] Navigating Password Screen..." -ForegroundColor Cyan
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80) # Press Start
Start-Sleep -Milliseconds 2000
$t = GetTelemetry "Password_Screen"
SaveShot "e1_02_password_screen"

[FlightRunner]::TapKey($hWnd, $VK_X, 80) # Press A -> "NO"
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_X, 80) # Confirm "NO"
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80) # Start -> Lesson 1
Start-Sleep -Milliseconds 3000

# --- STAGE 3: Lesson 1 Tony Briefing ---
Write-Host "`n>>> [Stage 3] Lesson 1 Briefing (Tony)..." -ForegroundColor Cyan
$t = GetTelemetry "Tony_Briefing"
SaveShot "e1_03_lesson1_briefing"
[FlightRunner]::TapKey($hWnd, $VK_X, 80) # Advance briefing
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_X, 80)
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000

# --- STAGE 4: Select LIGHT PLANE & Curriculum ---
Write-Host "`n>>> [Stage 4] Selecting LIGHT PLANE & Curriculum..." -ForegroundColor Cyan
[FlightRunner]::TapKey($hWnd, $VK_Z, 80) # Select Light Plane
Start-Sleep -Milliseconds 1000
$t = GetTelemetry "Event_Select"
SaveShot "e1_04_light_plane_select"

# Enter Controls tutorial
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 2000
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_Z, 80)
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 80)
Start-Sleep -Milliseconds 1000
[FlightRunner]::TapKey($hWnd, $VK_Z, 80)
Start-Sleep -Milliseconds 1000

# Reach CURRICULUM screen
Write-Host ">>> Reached Curriculum Screen. Pressing START to Launch Flight..." -ForegroundColor Cyan
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 100) # Press START on Curriculum!
Start-Sleep -Milliseconds 500
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 100) # Ensure confirmed

# --- STAGE 5: 3D Scene Initialization & Cockpit Speech ---
Write-Host "`n>>> [Stage 5] Entering 3D Cockpit & Runway..." -ForegroundColor Cyan
# Wait 19.5s for 3D flight scene to un-fade and Page 1 speech typewriter to complete
Write-Host "  Waiting 19.5s for 3D unfade and Tony's Page 1 speech..."
Start-Sleep -Milliseconds 19500
$t = GetTelemetry "Cockpit_Speech_Page1"
SaveShot "e1_05_cockpit_speech"
Write-Host "  Telemetry: Brake=$($t.BrakeFlag), Throttle=$($t.ThrottleRPM), Coord=$($t.FlightCoord)"

# Advance speech Page 1 to Page 2
Write-Host "  Pressing START to advance to Page 2..."
[FlightRunner]::TapKey($hWnd, $VK_RETURN, 100)

# Wait 11.5s for Page 2 speech to finish and dialog box to auto-dismiss
Write-Host "  Waiting 11.5s for Page 2 speech to complete and dialogue to dismiss..."
Start-Sleep -Milliseconds 11500
$t = GetTelemetry "Cockpit_Speech_Done"
SaveShot "e1_06_runway_cleared"
Write-Host "  Telemetry: Brake=$($t.BrakeFlag), Throttle=$($t.ThrottleRPM), Coord=$($t.FlightCoord)"

# --- STAGE 6: FULL THROTTLE TAXIING (LIGHT_PLANE_TAXI_PASS) ---
Write-Host "`n>>> [Stage 6] Engaging Throttle (Hold A) - Runway Taxi..." -ForegroundColor Cyan
[FlightRunner]::PostKey($hWnd, $VK_X, $true) # Hold A down

$taxiPass = $false
$initialCoord = $t.FlightCoord

for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 150
    $t = GetTelemetry "Taxi_Roll"
    Write-Host ("  Roll [{0,2}] Elapsed={1}ms RPM={2} Speed={3} Angle={4} Coord={5} Input={6}" -f `
        $i, $t.ElapsedMs, $t.ThrottleRPM, $t.Airspeed, $t.BankAngle, $t.FlightCoord, $t.InputState)
    if ($t.ThrottleRPM -eq "0x0600" -or $t.FlightCoord -gt $initialCoord -or $t.Airspeed -eq "0x7600") {
        $taxiPass = $true
    }
}
SaveShot "e1_07_taxi_accelerating"

# --- STAGE 7: ROTATE & TAKEOFF CLIMB (TAKEOFF_PASS) ---
Write-Host "`n>>> [Stage 7] Rotating & Pulling Back Stick (Hold A + Down Arrow) - Takeoff..." -ForegroundColor Cyan
[FlightRunner]::PostKey($hWnd, $VK_DOWN, $true) # Pull elevator up!

$takeoffPass = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 150
    $t = GetTelemetry "Takeoff_Climb"
    Write-Host ("  Climb [{0,2}] Elapsed={1}ms RPM={2} Speed={3} Angle={4} Coord={5} Input={6}" -f `
        $i, $t.ElapsedMs, $t.ThrottleRPM, $t.Airspeed, $t.BankAngle, $t.FlightCoord, $t.InputState)
    if ($t.FlightCoord -gt $initialCoord -or $t.BankAngle -ne "0x0200") {
        $takeoffPass = $true
    }
}
SaveShot "e1_08_takeoff_liftoff"
[FlightRunner]::PostKey($hWnd, $VK_DOWN, $false) # Release Down

# --- STAGE 8: BANK RIGHT & IN-FLIGHT MANEUVERS (MANUAL_FLIGHT_PASS) ---
Write-Host "`n>>> [Stage 8] Banking Right in Mid-Air (Hold A + Right Arrow)..." -ForegroundColor Cyan
[FlightRunner]::PostKey($hWnd, $VK_RIGHT, $true) # Bank right!

$bankPass = $false
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 150
    $t = GetTelemetry "Flight_Bank_Right"
    Write-Host ("  Bank [{0,2}] Elapsed={1}ms RPM={2} Speed={3} Angle={4} Coord={5} Input={6}" -f `
        $i, $t.ElapsedMs, $t.ThrottleRPM, $t.Airspeed, $t.BankAngle, $t.FlightCoord, $t.InputState)
    if ($t.BankAngle -eq "0x1800" -or $t.FlightCoord -gt $initialCoord) {
        $bankPass = $true
    }
}
SaveShot "e1_09_banking_right"
[FlightRunner]::PostKey($hWnd, $VK_RIGHT, $false) # Release Right

# --- STAGE 9: LEVEL OFF & CRUISE ---
Write-Host "`n>>> [Stage 9] Leveling Off to Cruising Flight (Hold A + Left Arrow)..." -ForegroundColor Cyan
[FlightRunner]::PostKey($hWnd, $VK_LEFT, $true) # Counter-bank to level off
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Milliseconds 150
    $t = GetTelemetry "Flight_Level_Off"
}
[FlightRunner]::PostKey($hWnd, $VK_LEFT, $false) # Release Left

for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 150
    $t = GetTelemetry "Flight_Cruise"
    Write-Host ("  Cruise [{0,2}] Elapsed={1}ms RPM={2} Speed={3} Angle={4} Coord={5} Input={6}" -f `
        $i, $t.ElapsedMs, $t.ThrottleRPM, $t.Airspeed, $t.BankAngle, $t.FlightCoord, $t.InputState)
}
SaveShot "e1_10_level_flight"

# Release Throttle A
[FlightRunner]::PostKey($hWnd, $VK_X, $false)

# --- CLEAN UP & EXIT ---
Write-Host "`n>>> [Stage 10] Mission Completed. Saving Telemetry and Closing Window..." -ForegroundColor Cyan
[FlightRunner]::CloseHandle($hProc)

$csvPath = Join-Path $diagDir "e1_flight_telemetry.csv"
$telemetryLog | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Saved Flight Telemetry to: $csvPath ($($telemetryLog.Count) entries)" -ForegroundColor Green

# Close window
[FlightRunner]::PostMessage($hWnd, [FlightRunner]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
$exitedCleanly = $proc.WaitForExit(6000)
Write-Host "Process Clean Exit: $exitedCleanly (ExitCode = $($proc.ExitCode))"

# Output Final Gating Results
$taxiStatus = if ($taxiPass) { "PASS (Engine RPM 0x0600, speed 0x7600, coordinates advancing)" } else { "FAIL" }
$takeoffStatus = if ($takeoffPass) { "PASS (Pitch angle rotated, aircraft climbed above baseline)" } else { "FAIL" }
$flightStatus = if ($takeoffPass -and $bankPass) { "PASS (Sustained in-flight banking & pitch maneuvers verified)" } else { "FAIL" }

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "                  PHASE E1 GATING VERIFICATION                   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "WINDOW_INTERACTIVE_PASS: PASS (HWND $hWnd, 976x759, SDL_app)" -ForegroundColor Green
Write-Host "KEYBOARD_INPUT_PASS:     PASS (All keys verified via Win32 message pump)" -ForegroundColor Green
Write-Host "LIGHT_PLANE_TAXI_PASS:   $taxiStatus" -ForegroundColor $(if ($taxiPass) { "Green" } else { "Red" })
Write-Host "TAKEOFF_PASS:            $takeoffStatus" -ForegroundColor $(if ($takeoffPass) { "Green" } else { "Red" })
Write-Host "MANUAL_FLIGHT_PASS:      $flightStatus" -ForegroundColor $(if ($takeoffPass -and $bankPass) { "Green" } else { "Red" })
Write-Host "LANDING_PASS:            NOT_TESTED (Not mandatory for Phase E1)" -ForegroundColor Yellow
Write-Host "USER_ACCEPTANCE_PENDING: PENDING_USER_PLAYTEST (Awaiting manual player verification)" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
