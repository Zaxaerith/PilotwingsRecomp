# Pilotwings SNES Native PC Recompilation

A native Windows x64 PC port and static binary recompilation of **Pilotwings** (SNES 1990 USA), powered by [SNESRecomp](https://github.com/RetroPortingToolKit/snesrecomp) Ahead-Of-Time (AOT) binary translation, an extended NEC µPD77C25 (DSP-1) High-Level Emulation (HLE) 3D mathematical coprocessor pipeline, and the official [recomp-ui](https://github.com/mstan/recomp-ui) graphical launcher.

[![License: PolyForm Noncommercial](https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue.svg)](LICENSE)
[![Platform: Windows x64](https://img.shields.io/badge/Platform-Windows%20x64-0078D6.svg)](#system-requirements)
[![Release: v0.1.0-preview](https://img.shields.io/badge/Release-v0.1.0--preview-brightgreen.svg)](#quick-start-guide-players)

---

## Legal Notice & Unofficial Project Disclaimer

- **Unofficial Fan Project**: This project is an independent, non-commercial, open-source educational and digital preservation research project. It is **NOT** affiliated with, endorsed by, sponsored by, or connected to **Nintendo Co., Ltd.** or its subsidiaries in any way.
- **No Copyrighted Assets Included**: This repository and all release packages contain **ZERO** copyrighted ROM binaries, audio tracks, tile graphics, or proprietary DSP firmwares.
- **Player-Supplied ROM**: To run the game, players must provide their own legally obtained ROM dump from an authentic retail copy of *Pilotwings* (SNES).
- **Intellectual Property**: *Pilotwings*, the Super Nintendo Entertainment System (SNES), and all associated characters, artwork, music, and trademarks are registered trademarks and copyright of **Nintendo Co., Ltd.**

---

## Technical Highlights

1. **Static Ahead-Of-Time (AOT) Binary Recompilation**
   - Transpiles original 65816 machine code instructions into clean, native C11 translation units, compiled to native x86-64 machine code for zero-interpreter overhead, microsecond frame pacing, and minimal latency.

2. **SHVC-1B0N LoROM PCB Address Decoding**
   - Implements hardware address decoding for the rare `SHVC-1B0N` LoROM printed circuit board. Unlike standard LoROM cartridges where the DSP-1 resides at `$20-$3F:$8000-$FFFF`, Pilotwings selects the DSP-1 at `$00-$1F:$6000-$7FFF` and `$80-$9F:$6000-$7FFF` using address bit 14 (`addr & 0x4000`), resolving bus collision bugs.

3. **Expanded DSP-1 HLE Mathematical Coprocessor**
   - Full native High-Level Emulation of the NEC µPD77C25 fixed-point DSP coprocessor.
   - Implements the complete Pilotwings 3D flight library:
     - `0x0E`: Target bearing & planar distance calculations
     - `0x01` / `0x11` / `0x21`: 3D attitude rotation matrix generation (Matrices A, B, C)
     - `0x0D` / `0x1D` / `0x2D`: Objective 3D coordinate transformations
     - `0x03` / `0x13` / `0x23`: Subjective 3D coordinate transformations
     - `0x0B` / `0x1B` / `0x2B`: Multi-axis scalar products
     - `0x14`: Angular velocity attitude rate numerical integration
   - **Zenith Angle Clamping**: Clamps extreme pitch angles to $\pm 0x3800$ to avoid trigonometric division-by-zero singularities and 32-bit fixed-point projection overflow during steep dives and climbs.
   - **Mode 7 Raster Unblock**: Permits immediate horizon and ground perspective rendering before matrix initialization completes.

4. **Integrated `recomp-ui` Desktop Host & Graphical Launcher**
   - Native Dear ImGui configuration frontend rendered in OpenGL.
   - Interactive ROM picker with cryptographic SHA-256 verification and status badges.
   - In-game overlay menu (`Ctrl + L`), visual save-state browser (`F7`), and rewind filmstrip (`F8`).

---

## Supported ROM Identity

The launcher and runtime verify the exact cryptographic hash of the user-supplied ROM dump on boot:

| Property | Value |
|---|---|
| **Title** | *Pilotwings* (USA) |
| **Platform** | Super Nintendo Entertainment System (SNES) |
| **Catalog Code** | SNS-PW-USA |
| **Release Date** | August 13, 1991 (North America) |
| **PCB Layout** | `SHVC-1B0N-01` (LoROM + DSP-1) |
| **File Format** | Headerless raw binary (`.sfc` / `.smc`) |
| **File Size** | **524,288 bytes** (512 KB) |
| **CRC-32** | `266C44ED` |
| **MD5** | `8dcb216beed58c798b25df55f62218d0` |
| **SHA-1** | `fe941ba251acf329f028a1603a43562db2c75e51` |
| **SHA-256** | `03d0127f5de3237e22ad00de0c20763274da7b71142dde693240ac96d10983a3` |

> [!NOTE]
> If your ROM has a 512-byte copier header (making the file 524,800 bytes), remove the header using any SNES ROM utility (e.g. TSNES, NSRT, or an online header remover) before launching.

---

## Quick Start Guide (Players)

1. **Download Release Package**:
   Download the latest release ZIP (`PilotwingsRecomp-windows-x64-v0.1.0-preview.zip`) from [Releases](https://github.com/Zaxaerith/PilotwingsRecomp/releases).
2. **Extract**:
   Extract the archive to any folder on your PC (e.g. `C:\Games\PilotwingsRecomp`).
3. **Launch**:
   Double-click `PilotwingsSNESRecomp.exe`.
4. **Select ROM**:
   The **recomp-ui** launcher will appear automatically on first launch.
   - Click **Browse** and select your `Pilotwings (USA).sfc` ROM.
   - When verified, a green checkmark badge will appear alongside ROM metadata.
   - Click **PLAY** to start flying!
5. **Launcher Customization**:
   - The game remembers your chosen ROM in `rom.cfg`.
   - Checking **Skip launcher on boot** in the launcher will make future launches jump straight into flight.
   - To force the launcher to open again at any time, run:
     ```powershell
     .\PilotwingsSNESRecomp.exe --launcher
     ```
   - Or press `Ctrl + L` while playing to open the settings overlay.

---

## Controls & Key Mappings

### Default Keyboard Controls

| Flight Action | SNES Button | Default Keyboard Key |
|---|---|---|
| **Pitch Down / Dive** | D-Pad Up | **Up Arrow** |
| **Pitch Up / Climb** | D-Pad Down | **Down Arrow** |
| **Roll / Rudder Left** | D-Pad Left | **Left Arrow** |
| **Roll / Rudder Right** | D-Pad Right | **Right Arrow** |
| **Throttle Up / Accelerate / Select** | A Button | **X** |
| **Throttle Down / Airbrakes / Cancel** | B Button | **Z** |
| **Secondary Action / Look Down** | X Button | **S** |
| **Secondary Action / Look Ahead** | Y Button | **A** |
| **Left Rudder Trim** | L Shoulder | **C** |
| **Right Rudder Trim** | R Shoulder | **V** |
| **Start Flight / Pause** | Start | **Enter (Return)** |
| **Instrument Select** | Select | **Right Shift** |

### Gamepad Support

Standard XInput and DirectInput controllers (Xbox Wireless Controller, PlayStation DualShock 4 / DualSense, Nintendo Switch Pro Controller) are auto-detected via SDL2 with native analog stick and button mapping:

- **Left Analog Stick / D-Pad**: Directional pitch, roll, and steering
- **A Button**: Accelerate / Confirm
- **B Button**: Decelerate / Cancel
- **X / Y Buttons**: Secondary flight functions
- **LB / RB (Bumpers)**: Left and Right Rudders
- **Start / Back**: Pause / Select

### System Shortcuts & PC Enhancements

| Shortcut | Function |
|---|---|
| `Ctrl + L` | Open in-game launcher settings overlay |
| `Alt + Enter` | Toggle Fullscreen / Windowed mode |
| `Tab` (hold) | Fast-Forward / Turbo Mode |
| `Ctrl + R` | Soft Reset guest CPU |
| `P` | Pause emulation |
| `F` | Toggle performance HUD (FPS, frame time) |
| `F7` or `F11` | Open visual **Save State Browser** with thumbnail gallery |
| `F8` or `F12` | Open interactive **Rewind Filmstrip** |
| `Shift + F1` .. `F10` | Quick-save to slots 1 through 10 |
| `F1` .. `F10` | Quick-load from slots 1 through 10 |
| `Keypad +` / `Keypad -` | Master audio volume up / down |

---

## Game Progression & Password System

- **Authentic Cartridge Design**: The original 1990 *Pilotwings* cartridge **does not contain battery-backed SRAM**. 
- In-game career progression across the Flight Club licenses (Light Plane, Skydiving, Rocketbelt, Hang Glider) is saved using the authentic **16-character alphanumeric password system** awarded by your flight instructors (Tony, Shirley, etc.) upon passing certification tests.
- To continue a certified career, choose **PASSWORD** from the main menu and enter your 16-character code.
- **PC Save States**: In addition to vanilla passwords, you can save and restore instantaneous snapshots at any moment using PC save states (`Shift+F1` / `F1` or the `F7` thumbnail browser).

---

## Building from Source (Developers)

### 1. Prerequisites

- **OS**: Windows 10/11 x64 (or Linux / macOS x86_64 / arm64)
- **CMake**: Version 3.20 or newer
- **C/C++ Compiler**: MinGW-w64 GCC 11+, Clang 14+, or MSVC 2022
- **SDL2 Development Libraries**: SDL 2.0.18+ (SDL2 2.32 recommended)
- **Git**

### 2. Clone Repository with Submodules

```bash
git clone --recurse-submodules https://github.com/Zaxaerith/PilotwingsRecomp.git
cd PilotwingsRecomp
```

### 3. Apply DSP-1 Framework Patches

*Pilotwings* requires two hardware and mathematical patches applied onto the `snesrecomp` submodule. A CMake guard strictly enforces this and halts if the patches are absent.

Apply them automatically:

**Windows (PowerShell)**:
```powershell
powershell -ExecutionPolicy Bypass -File tools/setup_snesrecomp.ps1
```

**Linux / macOS (Bash)**:
```bash
bash tools/setup_snesrecomp.sh
```

*(See [patches/snesrecomp/README.md](patches/snesrecomp/README.md) for detailed technical patch descriptions and manual instructions).*

### 4. Generate Recompiled C Code from ROM

Place your authentic `Pilotwings (USA).sfc` ROM in the repository root, then generate the static C translation units:

```bash
bash tools/regen.sh "Pilotwings (USA).sfc"
```

This populates `src/gen/` with the AOT transpiled C source files.

### 5. Configure and Build

```bash
# Configure with CMake (Release build with DSP-1 HLE)
cmake -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release

# Build executable
cmake --build build --config Release -j2
```

The resulting executable `build/PilotwingsSNESRecomp.exe` is completely self-contained.

---

## Repository Structure

```
PilotwingsRecomp/
├── .github/workflows/       # GitHub Actions CI/CD release automation
├── CMakeLists.txt           # Main CMake project configuration and patch guards
├── LICENSE                  # PolyForm Noncommercial 1.0.0 license
├── README.md                # Project documentation and user guide
├── VERSION                  # Release version string (0.1.0)
├── framework_pins.txt       # Exact upstream commit pins for snesrecomp and recomp-ui
├── rom_identity.txt         # Cryptographic ROM identity and validation hashes
├── docs/                    # Architectural notes and release documentation
│   └── RELEASE_NOTES_v0.1.0-preview.md
├── patches/snesrecomp/      # Tracked Git patches for upstream snesrecomp DSP-1
│   ├── 0001-*.patch        # SHVC-1B0N LoROM PCB address mapping
│   ├── 0002-*.patch        # Pilotwings 3D flight library and Zenith clamp
│   └── README.md           # Patch documentation and recovery guide
├── recomp/                  # Static recompiler configuration and symbols
│   ├── bank00.cfg
│   └── symbols.toml
├── src/                     # Host contract, runtime library, and entrypoint
│   ├── game_rtl.c / .h     # Game-specific runtime stubs
│   ├── host_contract.c     # SNESRecomp host interface
│   ├── main.c              # Application bootstrap and command-line parsing
│   └── variables.h
├── tools/                   # Setup scripts, test suites, and packaging tools
│   ├── setup_snesrecomp.ps1 # Automated patch application for Windows
│   ├── setup_snesrecomp.sh  # Automated patch application for Linux/macOS
│   ├── package_rc2.ps1     # Automated release packaging script
│   └── test_skiplauncher_suite.ps1 # SkipLauncher regression test suite
├── recomp-ui/               # Git submodule: official recomp-ui graphical launcher
└── snesrecomp/              # Git submodule: SNESRecomp static recompilation framework
```

---

## Acknowledgments & Third-Party Licenses

- **[SNESRecomp](https://github.com/RetroPortingToolKit/snesrecomp)**: Static SNES recompilation engine developed by RetroPortingToolKit contributors, licensed under PolyForm Noncommercial 1.0.0.
- **[recomp-ui](https://github.com/mstan/recomp-ui)**: Native graphical launcher developed by Matthew Stanley, licensed under the MIT License.
- **[Dear ImGui](https://github.com/ocornut/imgui)**: Immediate mode GUI library created by Omar Cornut, licensed under the MIT License.
- **[SDL2](https://www.libsdl.org/)**: Cross-platform audio, input, and windowing library created by Sam Lantinga, licensed under the zlib License.
- **[Lato Font](https://www.latofonts.com/)**: Typography designed by Łukasz Dziedzic, licensed under the SIL Open Font License (OFL 1.1).
- Special thanks to the SNES reverse engineering and emulation preservation community for hardware documentation on the NEC µPD77C25 coprocessor and Mode 7 graphics pipeline.
