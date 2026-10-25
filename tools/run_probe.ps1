<#
.SYNOPSIS
  Pilotwings PC Native AOT - Probe Test Runner
.DESCRIPTION
  Safely stages and executes PilotwingsSNESRecomp.exe outside the Low Integrity
  GameRecomp directory (into %LOCALAPPDATA%\PilotwingsRunProbe) to completely
  bypass the Windows 0xc0000142 (STATUS_DLL_INIT_FAILED) error caused by
  the Low Mandatory Level label on restricted workspace directories.
#>
param(
    [switch]$NoLauncher = $true,
    [string]$RomPath = "$PSScriptRoot\..\Pilotwings (USA).sfc",
    [int]$RunFrames = 0,
    [string]$FrameDumpDir = "",
    [string]$ScriptPath = "",
    [switch]$DumpPixels = $false,
    [switch]$DumpVideo = $false,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$buildDir = Join-Path $projectRoot "build-dsp1-hle"
$probeDir = Join-Path $env:LOCALAPPDATA "PilotwingsRunProbe"

if (-not (Test-Path (Join-Path $buildDir "PilotwingsSNESRecomp.exe"))) {
    throw "PilotwingsSNESRecomp.exe not found in $buildDir. Please build the project first."
}

if (-not (Test-Path $probeDir)) {
    New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
}

# Sync binary and runtime DLLs
$stagedFiles = @(
    "PilotwingsSNESRecomp.exe",
    "SDL2.dll",
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
    "libwinpthread-1.dll"
)

foreach ($f in $stagedFiles) {
    $src = Join-Path $buildDir $f
    if (Test-Path $src) {
        Copy-Item $src -Destination $probeDir -Force
    }
}

# Sync test scripts directory if exists
$testsSrc = Join-Path $projectRoot "tests"
if (Test-Path $testsSrc) {
    $testsDst = Join-Path $probeDir "tests"
    if (-not (Test-Path $testsDst)) { New-Item -ItemType Directory -Path $testsDst -Force | Out-Null }
    Copy-Item "$testsSrc\*" -Destination $testsDst -Recurse -Force
}

$probeExe = Join-Path $probeDir "PilotwingsSNESRecomp.exe"

$cmdArgs = @()
if ($NoLauncher) { $cmdArgs += "--no-launcher" }

if ($ScriptPath) {
    $resolvedScript = (Resolve-Path $ScriptPath).Path
    $cmdArgs += @("--script", "`"$resolvedScript`"")
}

if ($FrameDumpDir) {
    $resolvedDump = if ([System.IO.Path]::IsPathRooted($FrameDumpDir)) { $FrameDumpDir } else { (Join-Path $probeDir $FrameDumpDir) }
    if (-not (Test-Path $resolvedDump)) { New-Item -ItemType Directory -Path $resolvedDump -Force | Out-Null }
    $cmdArgs += @("--framedump", "`"$resolvedDump`"")
}

if ($RomPath -and (Test-Path $RomPath)) {
    $cmdArgs += @("--rom", "`"$((Resolve-Path $RomPath).Path)`"")
}

if ($ExtraArgs) {
    $cmdArgs += $ExtraArgs
}

if ($RunFrames -gt 0) {
    $env:SNESRECOMP_RUN_FRAMES = "$RunFrames"
} else {
    Remove-Item Env:\SNESRECOMP_RUN_FRAMES -ErrorAction SilentlyContinue
}

if ($DumpPixels) {
    $env:SNESRECOMP_FRAMEDUMP_PIXELS = "1"
} else {
    Remove-Item Env:\SNESRECOMP_FRAMEDUMP_PIXELS -ErrorAction SilentlyContinue
}

if ($DumpVideo) {
    $env:SNESRECOMP_FRAMEDUMP_VIDEO = "1"
} else {
    Remove-Item Env:\SNESRECOMP_FRAMEDUMP_VIDEO -ErrorAction SilentlyContinue
}

Set-Location $probeDir
Write-Host "Executing PilotwingsSNESRecomp via Medium-Integrity Probe..." -ForegroundColor Cyan
Write-Host "Command arguments: $($cmdArgs -join ' ')" -ForegroundColor Gray
$p = Start-Process -FilePath $probeExe -ArgumentList $cmdArgs -PassThru -Wait -NoNewWindow
$exitCode = $p.ExitCode
Write-Host "Process finished with exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Yellow' })
exit $exitCode
