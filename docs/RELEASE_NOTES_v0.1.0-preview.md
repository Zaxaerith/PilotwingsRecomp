# PilotwingsRecomp v0.1.0-preview (Windows x64)

Welcome to the first public preview release of **PilotwingsRecomp**, an Ahead-Of-Time (AOT) static binary recompilation of *Pilotwings* (SNES 1990 USA) for 64-bit Windows PCs!

This milestone port transforms the classic flight simulation title into a native Windows executable with zero CPU emulation overhead, microsecond frame response, native controller support, and modern convenience features.

---

## What's New & Key Highlights

### 1. Native AOT Static Recompilation
- Recompiled from authentic 65816 machine code into native x86-64 instructions.
- Eliminates typical emulator audio/video lag, delivering responsive flight controls.

### 2. Full DSP-1 Coprocessor HLE & Zenith Clamping
- *Pilotwings* was one of the earliest Super NES cartridges to embed the NEC µPD77C25 (DSP-1) math coprocessor to perform real-time 3D vector transformations, horizon projection, and Mode 7 matrix scaling.
- Implements the complete Pilotwings 3D mathematical instruction set:
  - Command `0x0E` (Target range & bearing)
  - Commands `0x01` / `0x11` / `0x21` (Attitude rotation matrices)
  - Commands `0x0D` / `0x1D` / `0x2D` & `0x03` / `0x13` / `0x23` (3D coordinate transformations)
  - Commands `0x0B` / `0x1B` / `0x2B` (Vector dot products)
  - Command `0x14` (Attitude rate numerical integration)
- **Zenith Angle Clamping**: Prevents mathematical singularity and coordinate overflow during steep dives and climbs, ensuring stable flight perspective throughout loops and stall recoveries.
- **SHVC-1B0N PCB Decoding**: Fixes the non-standard LoROM address decoding of the `SHVC-1B0N` cartridge layout, resolving memory bus collisions.

### 3. Integrated `recomp-ui` Graphical Launcher
- Official Dear ImGui configuration frontend.
- Built-in ROM selector with instantaneous SHA-256 cryptographic verification and visual status badges.
- Configurable Video (aspect ratios 4:3, 8:7, 1:1, integer scaling), Audio volume, and Gamepad/Keyboard bindings.
- **SkipLauncher**: Ability to bypass the launcher on subsequent launches and jump directly into the cockpit. Press `Ctrl + L` mid-game or pass `--launcher` via command line to re-open settings anytime.

### 4. Modern PC Quality-of-Life Enhancements
- **Save State Browser (`F7` / `F11`)**: Visual save-state gallery with live screenshot thumbnails and instant slot restoration.
- **Rewind Filmstrip (`F8` / `F12`)**: Rewind flight mistakes with interactive frame stepping.
- **Fast-Forward Turbo Mode (`Tab`)**: Accelerate takeoff preparations and lesson briefings.
- **Authentic Cartridge Passwords**: Faithfully preserves the authentic 16-character Flight Club certificate password system.

---

## Release Asset Checksums

| File / Component | SHA-256 Checksum | Size |
|---|---|---|
| **Release ZIP Archive** (`PilotwingsRecomp-windows-x64-v0.1.0-preview.zip`) | `4D09AD33780F7CC66C50F53FC4A0D187276F1AC87B83BC76102AED7DE5E1F286` | 5,260,535 bytes |
| **Release Candidate 2 Archive** (`PilotwingsRecomp-windows-x64-v0.1.0-preview-rc2.zip`) | `D6D142A2AC34EC5CEBFDEFB61560204D61C73581146AAFD7F31F50FD413A729D` | 5,096,271 bytes |
| **Main Executable** (`PilotwingsSNESRecomp.exe`) | `E3DF497092CA0D2EACA904C6C17EF917255D1069FDA484775E648D71BEB71115` | 4,205,568 bytes |
| **Required ROM** (`Pilotwings (USA).sfc`, headerless) | `03d0127f5de3237e22ad00de0c20763274da7b71142dde693240ac96d10983a3` | 524,288 bytes |

---

## Player Quick Start

1. Extract the release ZIP to any standard directory on your computer (e.g. `C:\Games\PilotwingsRecomp` or `Desktop`).
2. Run `PilotwingsSNESRecomp.exe`.
3. When the launcher opens, click **Browse** and select your clean, headerless `Pilotwings (USA).sfc` ROM.
4. Verify that the green checkmark badge appears.
5. Click **PLAY** to start the game!

### Default Keyboard Controls
- **Pitch Down / Dive**: Up Arrow
- **Pitch Up / Climb**: Down Arrow
- **Roll Left / Right**: Left / Right Arrow
- **Throttle / Accelerate**: X
- **Brake / Decelerate**: Z
- **Secondary Actions**: S / A
- **Left / Right Rudder Trim**: C / V
- **Start / Confirm**: Enter
- **Select**: Right Shift

*(Controllers are auto-detected upon plugging in).*

---

## Troubleshooting & FAQ

- **ROM Verification Fails (Red Warning Badge)**:
  Ensure your ROM file is exactly 524,288 bytes (512 KB). If the file size is 524,800 bytes, it contains a 512-byte copier header that must be stripped before launching.
- **Launcher Re-opening**:
  If you checked "Skip launcher on boot" and want to access settings again, press `Ctrl + L` during gameplay, or run the executable from a terminal with `.\PilotwingsSNESRecomp.exe --launcher`.
- **Application Exits Immediately on Direct Click**:
  If running from heavily restricted enterprise directories with Low Mandatory Integrity labels, extract the game to standard user folders such as `%LOCALAPPDATA%`, `C:\Games`, or your Desktop.

---

## Scope & Known Community Testing Items

- **Verified Playable Paths**:
  - Full Title and Introduction sequences
  - Password Registration and New Pilot sign-in
  - Instructor Tony flight briefing and tutorial
  - Event Selection: Light Plane & Skydiving
  - Runway acceleration, elevator pitch rotation, lift-off, and stable cruising
  - In-flight banking, coordinated rudder turns, and horizon rendering
  - Save states, rewind, pause, turbo, and soft-reset
- **Open for Extended Community Playtesting**:
  - Rocketbelt and Hang Glider advanced events
  - Later Flight Club licenses (Lessons 2 through 8)
  - Precision landing scoring and bonus round target accuracy
