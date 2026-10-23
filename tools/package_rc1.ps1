# PilotwingsRecomp - Phase G1 Local Release Candidate Packaging Script
param(
    [string]$Version = "0.1.0-preview-rc1"
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$buildRelease = Join-Path $projectRoot "build-release"
$stageName = "PilotwingsRecomp-windows-x64-v$Version"
$stageRoot = Join-Path $projectRoot "release-stage"
$stageDir = Join-Path $stageRoot $stageName
$distDir = Join-Path $projectRoot "dist"

Write-Host "=== Staging PilotwingsRecomp $Version ==="
if (Test-Path $stageDir) {
    Remove-Item -Recurse -Force $stageDir
}
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# 1. Binary
$exeSrc = Join-Path $buildRelease "PilotwingsSNESRecomp.exe"
if (-not (Test-Path $exeSrc)) {
    throw "Release executable not found: $exeSrc"
}
Copy-Item $exeSrc -Destination (Join-Path $stageDir "PilotwingsSNESRecomp.exe") -Force

# 2. Runtime DLLs
$sdl2Src = Join-Path $buildRelease "SDL2.dll"
if (-not (Test-Path $sdl2Src)) {
    $sdl2Src = "D:\Project\GameRecomp\_sdl2\SDL2-2.32.8\x86_64-w64-mingw32\bin\SDL2.dll"
}
Copy-Item $sdl2Src -Destination (Join-Path $stageDir "SDL2.dll") -Force

$mingwDlls = @("libgcc_s_seh-1.dll", "libstdc++-6.dll", "libwinpthread-1.dll")
foreach ($dll in $mingwDlls) {
    $dllSrc = Join-Path "C:\MYAPPLY\mingw64\bin" $dll
    if (Test-Path $dllSrc) {
        Copy-Item $dllSrc -Destination (Join-Path $stageDir $dll) -Force
    } else {
        throw "MinGW DLL not found: $dllSrc"
    }
}

# 3. Configurations
$cfgContent = @"
[General]
Autosave = 0
DisableFrameDelay = 0

[Graphics]
WindowSize = Auto
Fullscreen = 0
WindowScale = 3
NewRenderer = 1
IgnoreAspectRatio = 0
NoSpriteLimits = 1

[Sound]
EnableAudio = 1
Volume = 100
AudioFreq = 32000
AudioChannels = 2
AudioSamples = 512

[KeyMap]
Fullscreen = Alt+Return
Reset = Ctrl+r
Pause = Shift+p
PauseDimmed = p
Turbo = Tab
WindowBigger = Ctrl+Up
WindowSmaller = Ctrl+Down
VolumeUp = Keypad +
VolumeDown = Keypad -
DisplayPerf = f
ToggleRenderer = r
SaveStateMenu = F11
Rewind = F12
Load =      F1,     F2,     F3,     F4,     F5,     F6,     F7,     F8,     F9,     F10
Save = Shift+F1,Shift+F2,Shift+F3,Shift+F4,Shift+F5,Shift+F6,Shift+F7,Shift+F8,Shift+F9,Shift+F10

[GamepadMap]
EnableGamepad1 = true
EnableGamepad2 = true
Controls =   DpadUp, DpadDown, DpadLeft, DpadRight, Back, Start, B, A, Y, X, Lb, Rb
ControlsP2 = DpadUp, DpadDown, DpadLeft, DpadRight, Back, Start, B, A, Y, X, Lb, Rb
"@
Set-Content -Path (Join-Path $stageDir "config.ini") -Value $cfgContent -Encoding UTF8

$keybindsContent = @"
# SNES Controller Keybinds
# Edit values to customize. Restart the game to apply.
# Use SDL key names. Common: A B C ... Z, 0-9, F1-F12, Up Down Left Right,
# Return, Tab, Space, Left Shift, Right Shift, Left Ctrl, Right Ctrl,
# Backspace, Escape, Backslash. Use "None" to leave a button unbound.

[player1]
a       = X
b       = Z
x       = S
y       = A
l       = C
r       = V
start   = Return
select  = Right Shift
up      = Up
down    = Down
left    = Left
right   = Right

[player2]
a       = X
b       = Z
x       = S
y       = A
l       = C
r       = V
start   = Return
select  = Right Shift
up      = Up
down    = Down
left    = Left
right   = Right
"@
Set-Content -Path (Join-Path $stageDir "keybinds.ini") -Value $keybindsContent -Encoding UTF8

# 4. Documentation & Legal
Copy-Item (Join-Path $projectRoot "README.md") -Destination (Join-Path $stageDir "README.md") -Force
Copy-Item (Join-Path $projectRoot "LICENSE") -Destination (Join-Path $stageDir "LICENSE") -Force

# 5. Mod packages placeholder
$modPackagesDir = Join-Path $stageDir "mods\preloaded\packages"
New-Item -ItemType Directory -Path $modPackagesDir -Force | Out-Null
Set-Content -Path (Join-Path $modPackagesDir ".gitkeep") -Value ""

Write-Host "=== Performing Strict Whitelist & Blacklist Audit ==="
$bannedExtensions = @(".sfc", ".smc", ".bin", ".rom", ".sav", ".srm", ".o", ".obj", ".ninja", ".c", ".h", ".cpp", ".ps1", ".sh")
$stagedFiles = Get-ChildItem -Path $stageDir -Recurse -File

$violations = @()
foreach ($item in $stagedFiles) {
    $ext = $item.Extension.ToLower()
    if ($bannedExtensions -contains $ext -and $item.Name -ne ".gitkeep") {
        $violations += "Forbidden extension ($ext): $($item.FullName)"
    }
    if ($item.Name -eq "rom.cfg") {
        $violations += "Forbidden cache file: $($item.FullName)"
    }
}

if ($violations.Count -gt 0) {
    throw "Packaging audit failed:`n" + ($violations -join "`n")
}

Write-Host "Staged files whitelist:"
$stagedFiles | Select-Object Name, Length, @{Name="SHA256";Expression={(Get-FileHash $_.FullName -Algorithm SHA256).Hash}} | Format-Table -AutoSize

# 6. Create Zip Archive
$zipName = "$stageName.zip"
$zipPath = Join-Path $distDir $zipName
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Write-Host "Creating zip package: $zipPath"
# Use Compress-Archive with root stage folder inside
Compress-Archive -Path $stageDir -DestinationPath $zipPath -CompressionLevel Optimal

$zipItem = Get-Item $zipPath
$zipHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
Write-Host "=== Package Created Successfully ==="
Write-Host "Path:   $($zipItem.FullName)"
Write-Host "Size:   $($zipItem.Length) bytes ($([Math]::Round($zipItem.Length / 1MB, 2)) MB)"
Write-Host "SHA256: $zipHash"
