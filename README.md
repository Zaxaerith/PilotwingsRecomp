# Pilotwings SNES Native PC Recompilation

Native Windows x64 recompilation of **Pilotwings** (SNES 1990 USA), powered by [snesrecomp](https://github.com/RetroPortingToolKit/snesrecomp) AOT static binary translation and native DSP-1 HLE coprocessor math routines.

## Version: v0.1.0-preview-rc1

> **LEGAL NOTICE**:
> This package does NOT contain any proprietary Nintendo ROM data, DSP-1 microcode firmwares, or copyrighted assets.
> You must legally own an original retail copy of *Pilotwings* (SNES) and provide your own dump.

---

## Supported ROM Identity

| Property | Value |
|---|---|
| **Title** | *Pilotwings* (USA) |
| **System** | Super Nintendo Entertainment System (SNES) |
| **Release Year** | 1990 (North America: August 1991) |
| **Mapping** | LoROM (PCB: SHVC-1B0N-01) |
| **Coprocessor** | DSP-1 (HLE Mathematical Coprocessor) |
| **Region** | USA (NTSC) |
| **File Name** | `Pilotwings (USA).sfc` |
| **File Size** | 524,288 bytes (512 KB, headerless) |
| **CRC-32** | `266C44ED` |
| **SHA-256** | `03d0127f5de3237e22ad00de0c20763274da7b71142dde693240ac96d10983a3` |

The game binary verifies this exact cryptographic digest upon boot. Headers (e.g. 512-byte copier headers) must be removed prior to running.

---

## Quick Start Guide

1. Extract this release ZIP package to any local directory on Windows (e.g. `C:\Games\PilotwingsRecomp` or `Desktop`).
2. Place your verified `Pilotwings (USA).sfc` ROM into the same folder as `PilotwingsSNESRecomp.exe`.
3. Launch `PilotwingsSNESRecomp.exe`.
   - Alternatively, drag-and-drop the `.sfc` file onto `PilotwingsSNESRecomp.exe`.
   - Or launch via Command Prompt / PowerShell:
     ```powershell
     .\PilotwingsSNESRecomp.exe --rom "path\to\Pilotwings (USA).sfc"
     ```

No external runtime installations (Python, Rust, CMake, MinGW) are required. All necessary DLLs are self-contained.

---

## Default Controls

### Keyboard Controls (Configurable via `keybinds.ini`)

| Action | SNES Button | Default Key |
|---|---|---|
| **Pitch Down / Dive** | D-Pad Up | **Up Arrow** |
| **Pitch Up / Climb** | D-Pad Down | **Down Arrow** |
| **Roll / Rudder Left** | D-Pad Left | **Left Arrow** |
| **Roll / Rudder Right** | D-Pad Right | **Right Arrow** |
| **Throttle Up / Accelerate / Confirm** | A Button | **X** |
| **Throttle Down / Brake / Cancel** | B Button | **Z** |
| **Secondary Function / Look Down** | X Button | **S** |
| **Secondary Function / Look Ahead** | Y Button | **A** |
| **Rudder Left / Left Airbrake** | L Shoulder | **C** |
| **Rudder Right / Right Airbrake** | R Shoulder | **V** |
| **Start / Launch Flight / Pause** | Start | **Enter (Return)** |
| **Select** | Select | **Right Shift** |

### Gamepad Controls (Configurable via `config.ini`)

Standard XInput and DirectInput controllers (Xbox Wireless Controller, PlayStation DualShock/DualSense, Nintendo Switch Pro Controller) are auto-detected via SDL2.

- **D-Pad / Left Stick**: Directional flight control
- **A / B / X / Y**: Throttle, Brakes, Secondary controls
- **LB / RB**: Rudders
- **Start / Back**: Start / Select

---

## System Shortcuts (`config.ini`)

- **Fullscreen Toggle**: `Alt + Enter`
- **Turbo Mode**: `Tab` (hold for accelerated frame processing)
- **Soft Reset**: `Ctrl + R`
- **Pause**: `P` or `Shift + P`
- **Volume Up / Down**: `Keypad +` / `Keypad -`
- **Toggle Performance HUD**: `F`
- **Quick Save State (Slots 1-10)**: `Shift + F1` through `Shift + F10`
- **Quick Load State (Slots 1-10)**: `F1` through `F10`
- **Save State Menu**: `F11`
- **Rewind**: `F12`

---

## Game Progression & Save Mechanism

- **Important Notice**: The original *Pilotwings* cartridge **does NOT feature battery-backed SRAM**. 
- In-game career progression is saved using the authentic **16-character password system** awarded by the Flight Club instructors (Tony, Shirley, etc.) upon certifying lessons.
- To resume your career in vanilla fashion, select **PASSWORD** on the main menu and enter your 16-character code.
- In addition to cartridge passwords, this native PC port supports instant, full-state snapshots via the PC **Save State** system (`Shift+F1` to save, `F1` to load).

---

## Audio & Video Features

- **Rendering**: Hardware-accelerated OpenGL presenter (standard 4:3 native SNES pixel aspect ratio).
- **Audio**: 32,000 Hz, 16-bit stereo S-SMP DSP emulation with Gaussian sample interpolation.
- **DSP-1 Mathematical Precision**: Full HLE implementation of the NEC µPD77C25 coprocessor providing 3D Mode 7 matrix coordinate projections, altitude/pitch scaling, ground perspective transformation, and attitude clamping.

---

## Troubleshooting

- **Crash on Launch / Missing ROM**: Ensure `Pilotwings (USA).sfc` is in the same directory as the executable and matches the SHA-256 hash listed above.
- **Audio Stuttering**: Ensure your monitor refresh rate is stable, or adjust `AudioSamples` in `config.ini` (e.g. 1024).
- **Rebinding Keys**: Open `keybinds.ini` in any text editor, update key values according to SDL key names, and restart the game.
