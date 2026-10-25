# SNESRecomp DSP-1 Patches for Pilotwings

This directory contains essential hardware and mathematical patches for the upstream [SNESRecomp](https://github.com/RetroPortingToolKit/snesrecomp) framework. These patches are required for *Pilotwings* (SNES 1990 USA) to execute Mode 7 flight routines without infinite polling loops or mathematical singularities.

---

## 1. Upstream Baseline

| Parameter | Value |
|---|---|
| **Upstream Repository** | `https://github.com/RetroPortingToolKit/snesrecomp.git` |
| **Upstream Base Commit** | `be6a01d35bc9c37c550022124ca0df042e12e3c4` |
| **Patched Commit** | `964cdc1ee89c471df980d01d199c335473251079` |
| **Target Game ROM** | `Pilotwings (USA).sfc` (SHA-256: `03d0127f5de3237e22ad00de0c20763274da7b71142dde693240ac96d10983a3`) |

---

## 2. Included Patches

### Patch 1: `0001-feat-dsp1-add-SHVC-1B0N-LoROM-PCB-mapping-support-fo.patch`
- **Affected Files**: `runner/src/snes/cart.c`, `runner/src/snes/cart.h`, `tests/dsp1/dsp1_pcb_mapping_test.c`
- **Technical Problem**: The standard LoROM memory map expects DSP-1 data registers at `$20-$3F:$8000-$FFFF` or `$30-$3F:$8000-$FFFF`. *Pilotwings* uses the proprietary `SHVC-1B0N` PCB where the DSP-1 is mapped to `$00-$1F:$6000-$7FFF` and `$80-$9F:$6000-$7FFF` (mirroring at `$E000-$FFFF`). Address bit 14 (`addr & 0x4000`) controls chip select.
- **Solution**: Implements hardware address decoding for `DSP1_PCB_1B0N` in the cartridge bus mapper. Adds unit tests verifying all read/write mirrors.

### Patch 2: `0002-feat-dsp1-implement-Pilotwings-command-set-Zenith-cl.patch`
- **Affected Files**: `runner/src/snes/dsp1.c`, `runner/src/snes/dsp1_hle.c`, `runner/src/snes/dsp1_hle.h`
- **Technical Problem**: 
  1. *Pilotwings* issues Mode 7 raster calculations before completing Command `0x02` matrix initialization, causing the unpatched HLE core to return uninitialized states.
  2. Steep pitch maneuvers produce extreme Zenith angles ($> \pm 80^\circ$), resulting in trigonometric division-by-zero singularities and 32-bit coordinate overflow.
  3. *Pilotwings* utilizes an extended flight-dynamics command set not implemented in standard SNES games:
     - `0x0E`: Target distance and bearing calculation
     - `0x01` / `0x11` / `0x21`: Attitude rotation matrix updates (A, B, C)
     - `0x0D` / `0x1D` / `0x2D`: Objective 3D coordinate transformation
     - `0x03` / `0x13` / `0x23`: Subjective 3D coordinate transformation
     - `0x0B` / `0x1B` / `0x2B`: Vector scalar products
     - `0x14`: Angular velocity attitude rate integration
- **Solution**:
  1. Allows Command `0x0A` raster calculations to execute with fallback identity parameters.
  2. Implements Zenith angle clamping ($\pm 0x3800$) to guarantee continuous, singularity-free perspective projections.
  3. Implements the full Pilotwings 3D flight library and expands `Dsp1HleState` with `matrix[3][3][3]`.

---

## 3. Automated Application

You do not need to apply these patches by hand. You can run:

### Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File tools/setup_snesrecomp.ps1
```

### Linux / macOS (Bash):
```bash
bash tools/setup_snesrecomp.sh
```

These scripts verify that the submodule is checked out at the correct baseline commit, verify patch cleanliness, and apply them automatically.

---

## 4. Manual Application

To apply manually:

```bash
cd snesrecomp
git checkout be6a01d35bc9c37c550022124ca0df042e12e3c4
git apply ../patches/snesrecomp/0001-feat-dsp1-add-SHVC-1B0N-LoROM-PCB-mapping-support-fo.patch
git apply ../patches/snesrecomp/0002-feat-dsp1-implement-Pilotwings-command-set-Zenith-cl.patch
```

To revert:

```bash
cd snesrecomp
git checkout be6a01d35bc9c37c550022124ca0df042e12e3c4 -- .
git clean -fd
```
