<#
.SYNOPSIS
    Applies Pilotwings DSP-1 PCB and mathematical HLE patches to snesrecomp.
.DESCRIPTION
    Ensures the snesrecomp submodule is initialized and applies the SHVC-1B0N
    LoROM PCB mapping and 3D flight library patches required for Pilotwings.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$snesrecompDir = Join-Path $repoRoot "snesrecomp"
$patchDir = Join-Path $repoRoot "patches\snesrecomp"
$patch1 = Join-Path $patchDir "0001-feat-dsp1-add-SHVC-1B0N-LoROM-PCB-mapping-support-fo.patch"
$patch2 = Join-Path $patchDir "0002-feat-dsp1-implement-Pilotwings-command-set-Zenith-cl.patch"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Pilotwings SNESRecomp - Framework Setup & Patch Tool" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify submodule exists
if (-not (Test-Path "$snesrecompDir\runner\runner.cmake")) {
    Write-Host "[INFO] Initializing snesrecomp submodule..." -ForegroundColor Yellow
    Push-Location $repoRoot
    try {
        git submodule update --init snesrecomp
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path "$snesrecompDir\runner\runner.cmake")) {
    Write-Error "Could not find snesrecomp at $snesrecompDir. Please clone the submodule first."
}

# 2. Check if patches are already applied
$dsp1Header = Join-Path $snesrecompDir "runner\src\snes\dsp1_hle.h"
$cartHeader = Join-Path $snesrecompDir "runner\src\snes\cart.h"

$alreadyPatched = $false
if ((Test-Path $dsp1Header) -and (Test-Path $cartHeader)) {
    $dsp1Content = Get-Content -Raw $dsp1Header
    $cartContent = Get-Content -Raw $cartHeader
    if (($dsp1Content -match "matrix\[3\]\[3\]\[3\]") -and ($cartContent -match "DSP1_PCB_1B0N")) {
        $alreadyPatched = $true
    }
}

if ($alreadyPatched) {
    Write-Host "[OK] Pilotwings DSP-1 patches are already applied in snesrecomp." -ForegroundColor Green
    exit 0
}

# 3. Verify patch files exist
if (-not (Test-Path $patch1) -or -not (Test-Path $patch2)) {
    Write-Error "Patch files not found in $patchDir. Please ensure repository is intact."
}

# 4. Apply patches
Write-Host "[INFO] Applying DSP-1 patches onto snesrecomp..." -ForegroundColor Yellow
Push-Location $snesrecompDir
try {
    # Check patch 1
    $check1 = & git apply --check $patch1 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Patch 1 dry-run failed:`n$check1"
    }

    # Apply patch 1
    & git apply $patch1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to apply Patch 1."
    }
    Write-Host "  -> Applied 0001 (SHVC-1B0N LoROM PCB mapping)" -ForegroundColor Green

    # Check patch 2
    $check2 = & git apply --check $patch2 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Patch 2 dry-run failed:`n$check2"
    }

    # Apply patch 2
    & git apply $patch2
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to apply Patch 2."
    }
    Write-Host "  -> Applied 0002 (Pilotwings DSP-1 3D flight library & Zenith clamp)" -ForegroundColor Green

    Write-Host "`n[SUCCESS] All Pilotwings DSP-1 patches successfully applied!" -ForegroundColor Green
    Write-Host "You may now proceed with CMake configuration and building." -ForegroundColor Cyan
} finally {
    Pop-Location
}
