# PilotwingsRecomp - Phase G2 RC2 Standalone Independent Verification
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$zipPath = Join-Path $projectRoot "dist\PilotwingsRecomp-windows-x64-v0.1.0-preview-rc2.zip"
$realRom = Join-Path $projectRoot "Pilotwings (USA).sfc"
$testBase = Join-Path $env:TEMP "PilotwingsRC2CleanVerify"

if (-not (Test-Path $zipPath)) { throw "RC2 ZIP not found at $zipPath" }
if (-not (Test-Path $realRom)) { throw "ROM not found at $realRom" }

if (Test-Path $testBase) { Remove-Item -Recurse -Force $testBase }
New-Item -ItemType Directory -Path $testBase -Force | Out-Null

Write-Host "=== Step 1: Extracting RC2 ZIP to Clean Directory ==="
Expand-Archive -Path $zipPath -DestinationPath $testBase

$extractedDir = Join-Path $testBase "PilotwingsRecomp-windows-x64-v0.1.0-preview-rc2"
$exePath = Join-Path $extractedDir "PilotwingsSNESRecomp.exe"

Write-Host "Extracted directory: $extractedDir"
Get-ChildItem -Path $extractedDir

Write-Host "`n=== Step 2: Verifying Integrity Level ==="
icacls $exePath

# Sanitize PATH completely
$oldPath = $env:PATH
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem"

function Run-Step([string]$name, [string[]]$procArgs, [int]$timeoutMs = 15000) {
    Write-Host "`n--- Running: $name ---"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.WorkingDirectory = $extractedDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    if ($procArgs -and $procArgs.Count -gt 0) {
        $psi.Arguments = ($procArgs -join " ")
    }
    
    $p = [System.Diagnostics.Process]::Start($psi)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $exited = $p.WaitForExit($timeoutMs)
    $sw.Stop()
    
    if (-not $exited) {
        Write-Warning "Process $($p.Id) timed out in $name. Forcing kill."
        try { $p.Kill() } catch { }
        throw "Failed: $name timed out after ${timeoutMs}ms"
    }
    
    Write-Host "Result: ExitCode=$($p.ExitCode), Elapsed=$($sw.ElapsedMilliseconds)ms"
    if ($p.ExitCode -ne 0) {
        throw "Failed: $name returned non-zero exit code $($p.ExitCode)"
    }
    Write-Host "PASS: $name"
}

# 1. First launch without ROM (smoke 25 frames)
$env:LNG_SMOKE_FRAMES = "25"
Run-Step "1. First Launch Without ROM (GUI Smoke)" @()
Remove-Item Env:\LNG_SMOKE_FRAMES

# 2. Place ROM beside executable & configure cached ROM + SkipLauncher
$destRom = Join-Path $extractedDir "Pilotwings (USA).sfc"
Copy-Item $realRom -Destination $destRom
[System.IO.File]::WriteAllText((Join-Path $extractedDir "rom.cfg"), $destRom)
[System.IO.File]::WriteAllText((Join-Path $extractedDir "config.local.ini"), "[General]`r`nSkipLauncher = 1`r`nAutosave = 1`r`n")

# 3. Direct launch with cached ROM and SkipLauncher=1 for 180 frames
$env:SNESRECOMP_RUN_FRAMES = "180"
Run-Step "2. Direct Game Launch with Cached ROM (180 frames)" @()
Remove-Item Env:\SNESRECOMP_RUN_FRAMES

# Check savestate generated
$save0 = Join-Path $extractedDir "saves\save0.sav"
if (Test-Path $save0) {
    $saveItem = Get-Item $save0
    Write-Host "Save state successfully generated: $($saveItem.Length) bytes"
} else {
    throw "Expected save state not found at $save0"
}

# 4. Reload save state & run 60 frames in-flight
$env:SNESRECOMP_RUN_FRAMES = "60"
Run-Step "3. Reload In-Flight Save State (60 frames)" @()
Remove-Item Env:\SNESRECOMP_RUN_FRAMES

# 5. Force launcher open with --launcher flag
$env:LNG_SMOKE_FRAMES = "25"
Run-Step "4. Force Launcher Override (--launcher flag)" @("--launcher")
Remove-Item Env:\LNG_SMOKE_FRAMES

# 6. Command line --help
Run-Step "5. CLI Help Flag (--help)" @("--help")

# Restore PATH
$env:PATH = $oldPath

# Clean up test directory
Remove-Item -Recurse -Force $testBase

Write-Host "`n======================================================="
Write-Host "  ALL RC2 STANDALONE VERIFICATION STEPS PASSED CLEANLY "
Write-Host "======================================================="
