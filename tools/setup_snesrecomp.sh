#!/usr/bin/env bash
#
# setup_snesrecomp.sh - Applies Pilotwings DSP-1 patches to snesrecomp
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SNESRECOMP_DIR="${REPO_ROOT}/snesrecomp"
PATCH_DIR="${REPO_ROOT}/patches/snesrecomp"
PATCH1="${PATCH_DIR}/0001-feat-dsp1-add-SHVC-1B0N-LoROM-PCB-mapping-support-fo.patch"
PATCH2="${PATCH_DIR}/0002-feat-dsp1-implement-Pilotwings-command-set-Zenith-cl.patch"

echo "=========================================================="
echo " Pilotwings SNESRecomp - Framework Setup & Patch Tool"
echo "=========================================================="

# 1. Verify submodule exists
if [ ! -f "${SNESRECOMP_DIR}/runner/runner.cmake" ]; then
    echo "[INFO] Initializing snesrecomp submodule..."
    cd "${REPO_ROOT}"
    git submodule update --init snesrecomp
fi

if [ ! -f "${SNESRECOMP_DIR}/runner/runner.cmake" ]; then
    echo "[ERROR] Could not find snesrecomp at ${SNESRECOMP_DIR}." >&2
    exit 1
fi

# 2. Check if patches are already applied
DSP1_HEADER="${SNESRECOMP_DIR}/runner/src/snes/dsp1_hle.h"
CART_HEADER="${SNESRECOMP_DIR}/runner/src/snes/cart.h"

if [ -f "${DSP1_HEADER}" ] && [ -f "${CART_HEADER}" ]; then
    if grep -q "matrix\[3\]\[3\]\[3\]" "${DSP1_HEADER}" && grep -q "DSP1_PCB_1B0N" "${CART_HEADER}"; then
        echo "[OK] Pilotwings DSP-1 patches are already applied in snesrecomp."
        exit 0
    fi
fi

# 3. Verify patch files exist
if [ ! -f "${PATCH1}" ] || [ ! -f "${PATCH2}" ]; then
    echo "[ERROR] Patch files not found in ${PATCH_DIR}." >&2
    exit 1
fi

# 4. Apply patches
echo "[INFO] Applying DSP-1 patches onto snesrecomp..."
cd "${SNESRECOMP_DIR}"

git apply --check "${PATCH1}"
git apply "${PATCH1}"
echo "  -> Applied 0001 (SHVC-1B0N LoROM PCB mapping)"

git apply --check "${PATCH2}"
git apply "${PATCH2}"
echo "  -> Applied 0002 (Pilotwings DSP-1 3D flight library & Zenith clamp)"

echo ""
echo "[SUCCESS] All Pilotwings DSP-1 patches successfully applied!"
echo "You may now proceed with CMake configuration and building."
