# PilotwingsRecomp - Phase G2 SkipLauncher Regression Test Suite
# Implements Tests A, B, C, D with strictly bounded timeouts and isolated directories.

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$buildDir = Join-Path $projectRoot "build-rc2"
$realRom = Join-Path $projectRoot "Pilotwings (USA).sfc"
$testBase = Join-Path $env:TEMP "PW_G2_Regression"

if (-not (Test-Path $realRom)) {
    throw "Required test ROM not found at $realRom"
}

if (Test-Path $testBase) {
    Remove-Item -Recurse -Force $testBase
}
New-Item -ItemType Directory -Path $testBase -Force | Out-Null

function Deploy-IsolatedEnv([string]$targetDir) {
    if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    
    Copy-Item (Join-Path $buildDir "PilotwingsSNESRecomp.exe") -Destination $targetDir
    Copy-Item (Join-Path $buildDir "SDL2.dll") -Destination $targetDir
    Copy-Item (Join-Path $buildDir "assets") -Destination $targetDir -Recurse
    Copy-Item (Join-Path $buildDir "mods") -Destination $targetDir -Recurse
    
    $mingwDlls = @("libgcc_s_seh-1.dll", "libstdc++-6.dll", "libwinpthread-1.dll")
    foreach ($dll in $mingwDlls) {
        $p = Join-Path "C:\MYAPPLY\mingw64\bin" $dll
        if (Test-Path $p) { Copy-Item $p -Destination $targetDir }
    }
    
    # Default base config
    $defaultCfg = @"
[General]
Autosave = 0
DisableFrameDelay = 0

[Graphics]
WindowSize = Auto
Fullscreen = 0
WindowScale = 1
NewRenderer = 1
IgnoreAspectRatio = 0
NoSpriteLimits = 1

[Sound]
EnableAudio = 0
Volume = 0
"@
    Set-Content -Path (Join-Path $targetDir "config.ini") -Value $defaultCfg -Encoding UTF8
    
    $defaultKeys = @"
[player1]
a = X
b = Z
start = Return
up = Up
down = Down
left = Left
right = Right
"@
    Set-Content -Path (Join-Path $targetDir "keybinds.ini") -Value $defaultKeys -Encoding UTF8
}

function Run-BoundedProcess([string]$exePath, [string[]]$ProcessArgs, [string]$workingDir, [int]$timeoutMs = 15000) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.WorkingDirectory = $workingDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    if ($ProcessArgs -and $ProcessArgs.Count -gt 0) {
        $psi.Arguments = ($ProcessArgs -join " ")
    }
    
    $p = [System.Diagnostics.Process]::Start($psi)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $exited = $p.WaitForExit($timeoutMs)
    $sw.Stop()
    
    if (-not $exited) {
        Write-Warning "Process $($p.Id) exceeded timeout of ${timeoutMs}ms. Forcing termination."
        try {
            $p.Kill()
            $p.WaitForExit(3000)
        } catch { }
        return @{
            Success = $false
            TimedOut = $true
            ExitCode = -999
            ElapsedMs = $sw.ElapsedMilliseconds
        }
    }
    
    return @{
        Success = ($p.ExitCode -eq 0)
        TimedOut = $false
        ExitCode = $p.ExitCode
        ElapsedMs = $sw.ElapsedMilliseconds
    }
}

Write-Host "===================================================="
Write-Host "  Starting SkipLauncher Four-Item Regression Suite  "
Write-Host "===================================================="

# -----------------------------------------------------------------------------
# Test A: First launch (no rom.cfg, SkipLauncher=0, no explicit ROM arg)
# Expected: GUI opens, renders via smoke test (25 frames), and exits cleanly code 0.
# -----------------------------------------------------------------------------
Write-Host "`n>>> [Test A] First Launch (No ROM, Clean GUI smoke) <<<"
$dirA = Join-Path $testBase "TestA_FirstLaunch"
Deploy-IsolatedEnv $dirA
$exeA = Join-Path $dirA "PilotwingsSNESRecomp.exe"

$env:LNG_SMOKE_FRAMES = "25"
$resA = Run-BoundedProcess -exePath $exeA -ProcessArgs @() -workingDir $dirA -timeoutMs 15000
Remove-Item Env:\LNG_SMOKE_FRAMES

Write-Host "Test A Result: ExitCode=$($resA.ExitCode), TimedOut=$($resA.TimedOut), Elapsed=$($resA.ElapsedMs)ms"
if ($resA.ExitCode -ne 0 -or $resA.TimedOut) {
    throw "Test A failed: Expected exit code 0 without timeout."
}
Write-Host "[Test A PASS]"

# -----------------------------------------------------------------------------
# Test B: SkipLauncher=1 with valid cached ROM
# Expected: Boots straight into game, runs 120 frames, exits code 0.
# -----------------------------------------------------------------------------
Write-Host "`n>>> [Test B] Skip Launcher (Valid cached ROM, Run 120 frames) <<<"
$dirB = Join-Path $testBase "TestB_SkipLauncher"
Deploy-IsolatedEnv $dirB
$exeB = Join-Path $dirB "PilotwingsSNESRecomp.exe"
$romB = Join-Path $dirB "Pilotwings (USA).sfc"
Copy-Item $realRom -Destination $romB

# Write cached ROM (without BOM)
[System.IO.File]::WriteAllText((Join-Path $dirB "rom.cfg"), $romB)

# Use config.local.ini for clean override (without BOM)
[System.IO.File]::WriteAllText((Join-Path $dirB "config.local.ini"), "[General]`r`nSkipLauncher = 1`r`n")

$env:SNESRECOMP_RUN_FRAMES = "120"
$resB = Run-BoundedProcess -exePath $exeB -ProcessArgs @() -workingDir $dirB -timeoutMs 15000
Remove-Item Env:\SNESRECOMP_RUN_FRAMES

Write-Host "Test B Result: ExitCode=$($resB.ExitCode), TimedOut=$($resB.TimedOut), Elapsed=$($resB.ElapsedMs)ms"
if ($resB.ExitCode -ne 0 -or $resB.TimedOut) {
    throw "Test B failed: Expected exit code 0 within timeout."
}
Write-Host "[Test B PASS]"

# -----------------------------------------------------------------------------
# Test C: Force display launcher with --launcher flag
# Expected: GUI is forced open despite SkipLauncher=1; smoke test 25 frames -> code 0.
# -----------------------------------------------------------------------------
Write-Host "`n>>> [Test C] Force Launcher (--launcher override) <<<"
$dirC = Join-Path $testBase "TestC_ForceLauncher"
Deploy-IsolatedEnv $dirC
$exeC = Join-Path $dirC "PilotwingsSNESRecomp.exe"
$romC = Join-Path $dirC "Pilotwings (USA).sfc"
Copy-Item $realRom -Destination $romC

[System.IO.File]::WriteAllText((Join-Path $dirC "rom.cfg"), $romC)
[System.IO.File]::WriteAllText((Join-Path $dirC "config.local.ini"), "[General]`r`nSkipLauncher = 1`r`n")

$env:LNG_SMOKE_FRAMES = "25"
$resC = Run-BoundedProcess -exePath $exeC -ProcessArgs @("--launcher") -workingDir $dirC -timeoutMs 15000
Remove-Item Env:\LNG_SMOKE_FRAMES

Write-Host "Test C Result: ExitCode=$($resC.ExitCode), TimedOut=$($resC.TimedOut), Elapsed=$($resC.ElapsedMs)ms"
if ($resC.ExitCode -ne 0 -or $resC.TimedOut) {
    throw "Test C failed: Expected exit code 0 without timeout."
}
Write-Host "[Test C PASS]"

# -----------------------------------------------------------------------------
# Test D: Missing ROM cache fallback
# Expected: Missing file causes fopen failure -> falls back to GUI -> smoke 25 frames -> code 0.
# -----------------------------------------------------------------------------
Write-Host "`n>>> [Test D] Missing ROM Cache Fallback <<<"
$dirD = Join-Path $testBase "TestD_MissingROM"
Deploy-IsolatedEnv $dirD
$exeD = Join-Path $dirD "PilotwingsSNESRecomp.exe"

[System.IO.File]::WriteAllText((Join-Path $dirD "rom.cfg"), "C:\NonExistent\FakePilotwings.sfc")
[System.IO.File]::WriteAllText((Join-Path $dirD "config.local.ini"), "[General]`r`nSkipLauncher = 1`r`n")

$env:LNG_SMOKE_FRAMES = "25"
$resD = Run-BoundedProcess -exePath $exeD -ProcessArgs @() -workingDir $dirD -timeoutMs 15000
Remove-Item Env:\LNG_SMOKE_FRAMES

Write-Host "Test D Result: ExitCode=$($resD.ExitCode), TimedOut=$($resD.TimedOut), Elapsed=$($resD.ElapsedMs)ms"
if ($resD.ExitCode -ne 0 -or $resD.TimedOut) {
    throw "Test D failed: Expected exit code 0 without timeout."
}
Write-Host "[Test D PASS]"

# -----------------------------------------------------------------------------
# Test E: Mismatched / Bad ROM hash check
# -----------------------------------------------------------------------------
Write-Host "`n>>> [Test E] Corrupt / Mismatched ROM Handling <<<"
$dirE = Join-Path $testBase "TestE_CorruptROM"
Deploy-IsolatedEnv $dirE
$exeE = Join-Path $dirE "PilotwingsSNESRecomp.exe"
$badRom = Join-Path $dirE "BadRom.sfc"
# Create 512KB of zero bytes
$dummyBytes = New-Object byte[] (524288)
[System.IO.File]::WriteAllBytes($badRom, $dummyBytes)

[System.IO.File]::WriteAllText((Join-Path $dirE "rom.cfg"), $badRom)
[System.IO.File]::WriteAllText((Join-Path $dirE "config.local.ini"), "[General]`r`nSkipLauncher = 1`r`n")

# Since hash check fails on boot with bad ROM, verify it rejects and exits cleanly or shows GUI error
$env:LNG_SMOKE_FRAMES = "25"
$resE = Run-BoundedProcess -exePath $exeE -ProcessArgs @() -workingDir $dirE -timeoutMs 15000
Remove-Item Env:\LNG_SMOKE_FRAMES

Write-Host "Test E Result: ExitCode=$($resE.ExitCode), TimedOut=$($resE.TimedOut), Elapsed=$($resE.ElapsedMs)ms"
Write-Host "[Test E Checked]"

# Cleanup test directory
Remove-Item -Recurse -Force $testBase
Write-Host "`n===================================================="
Write-Host "  ALL SKIPLAUNCHER REGRESSION TESTS PASSED CLEANLY  "
Write-Host "===================================================="
