# PilotwingsRecomp - Phase G2 Local Release Candidate 2 Packaging Script
param(
    [string]$Version = "0.1.0-preview-rc2"
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$buildRelease = Join-Path $projectRoot "build-rc2"
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

# 1. Binary (Stripped)
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

# 3. GUI Assets (fonts and img)
$assetsSrc = Join-Path $buildRelease "assets"
if (-not (Test-Path $assetsSrc)) {
    throw "GUI assets directory not found in $buildRelease"
}
Copy-Item $assetsSrc -Destination $stageDir -Recurse -Force

# 4. Mod catalog placeholder
$modPackagesDir = Join-Path $stageDir "mods\preloaded\packages"
New-Item -ItemType Directory -Path $modPackagesDir -Force | Out-Null
Set-Content -Path (Join-Path $modPackagesDir ".gitkeep") -Value ""

# 5. Production Configurations
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
DisplayAspect = 4:3
LinearFiltering = 0
Shader = 
VSync = 1

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
SaveStateMenu = F7
Rewind = F8
Load =      F1,     F2,     F3,     F4,     F5,     F6,     F7,     F8,     F9,     F10
Save = Shift+F1,Shift+F2,Shift+F3,Shift+F4,Shift+F5,Shift+F6,Shift+F7,Shift+F8,Shift+F9,Shift+F10

[GamepadMap]
EnableGamepad1 = true
EnableGamepad2 = true
Controls =   DpadUp, DpadDown, DpadLeft, DpadRight, Back, Start, B, A, Y, X, Lb, Rb
ControlsP2 = DpadUp, DpadDown, DpadLeft, DpadRight, Back, Start, B, A, Y, X, Lb, Rb

[Rewind]
Enabled = 0
Depth = 50
Interval = 15
"@
[System.IO.File]::WriteAllText((Join-Path $stageDir "config.ini"), $cfgContent)

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
[System.IO.File]::WriteAllText((Join-Path $stageDir "keybinds.ini"), $keybindsContent)

# 6. Documentation & Licenses
Copy-Item (Join-Path $projectRoot "README.md") -Destination (Join-Path $stageDir "README.md") -Force
Copy-Item (Join-Path $projectRoot "LICENSE") -Destination (Join-Path $stageDir "LICENSE") -Force

# Third-party notices
$thirdPartyText = @"
# Third-Party Licenses and Notices

This distribution includes components licensed under various open-source licenses:

## 1. recomp-ui
Copyright (c) 2026 Matthew Stanley
License: MIT License
URL: https://github.com/mstan/recomp-ui

## 2. Dear ImGui
Copyright (c) 2014-2026 Omar Cornut
License: MIT License
URL: https://github.com/ocornut/imgui

## 3. Simple DirectMedia Layer (SDL2)
Copyright (c) 1997-2026 Sam Lantinga
License: zlib License
URL: https://www.libsdl.org/

## 4. Lato Latin Fonts
Copyright (c) 2010-2015 by tyPoland Lukasz Dziedzic
License: SIL Open Font License (OFL-1.1)

## 5. Noto Sans Symbols 2 & OpenMoji
OpenMoji: CC BY-SA 4.0
Noto: SIL Open Font License (OFL-1.1)

## 6. MinGW-w64 Runtime
Copyright (c) 2009-2026 by the MinGW-w64 project
License: Zope Public License (ZPL) / BSD 3-Clause / GNU Free Documentation License
"@
[System.IO.File]::WriteAllText((Join-Path $stageDir "THIRD_PARTY_LICENSES.md"), $thirdPartyText)

Write-Host "=== Performing Strict Whitelist & Blacklist Audit ==="
$bannedExtensions = @(".sfc", ".smc", ".bin", ".rom", ".sav", ".srm", ".o", ".obj", ".ninja", ".c", ".h", ".cpp", ".ps1", ".sh", ".make")
$stagedFiles = Get-ChildItem -Path $stageDir -Recurse -File

$violations = @()
foreach ($item in $stagedFiles) {
    $ext = $item.Extension.ToLower()
    if ($bannedExtensions -contains $ext -and $item.Name -ne ".gitkeep") {
        $violations += "Forbidden extension ($ext): $($item.FullName)"
    }
    if ($item.Name -eq "rom.cfg" -or $item.Name -eq "config.local.ini") {
        $violations += "Forbidden cache or override file: $($item.FullName)"
    }
}

if ($violations.Count -gt 0) {
    throw "Packaging audit failed:`n" + ($violations -join "`n")
}

Write-Host "Staged files whitelist:"
$stagedFiles | Select-Object Name, Length, @{Name="SHA256";Expression={(Get-FileHash $_.FullName -Algorithm SHA256).Hash}} | Format-Table -AutoSize

# 7. Create Zip Archive
$zipName = "$stageName.zip"
$zipPath = Join-Path $distDir $zipName
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Write-Host "Creating zip package: $zipPath"
Compress-Archive -Path $stageDir -DestinationPath $zipPath -CompressionLevel Optimal

$zipItem = Get-Item $zipPath
$zipHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
Write-Host "=== Package Created Successfully ==="
Write-Host "Path:   $($zipItem.FullName)"
Write-Host "Size:   $($zipItem.Length) bytes ($([Math]::Round($zipItem.Length / 1MB, 2)) MB)"
Write-Host "SHA256: $zipHash"
