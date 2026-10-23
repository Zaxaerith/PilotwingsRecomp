$p = "$env:LOCALAPPDATA\PilotwingsRunProbe"
$wram0 = [System.IO.File]::ReadAllBytes("$p\flight_00_p1_done.wram.bin")
$wram2 = [System.IO.File]::ReadAllBytes("$p\flight_02_rolling_fast.wram.bin")
$wram3 = [System.IO.File]::ReadAllBytes("$p\flight_03_takeoff_speed.wram.bin")
$wram4 = [System.IO.File]::ReadAllBytes("$p\flight_04_airborne_climbing.wram.bin")
$wram5 = [System.IO.File]::ReadAllBytes("$p\flight_05_banking_right.wram.bin")

Write-Host "Searching ALL 128KB WRAM (0x00000..0x20000)..."
$diffs = [System.Collections.Generic.List[PSObject]]::new()

for ($i = 0; $i -lt 0x20000; $i += 2) {
    $v0 = [BitConverter]::ToUInt16($wram0, $i)
    $v2 = [BitConverter]::ToUInt16($wram2, $i)
    $v3 = [BitConverter]::ToUInt16($wram3, $i)
    $v4 = [BitConverter]::ToUInt16($wram4, $i)
    $v5 = [BitConverter]::ToUInt16($wram5, $i)

    # Monotonically increasing across roll, takeoff, climb
    if ($v0 -lt $v2 -and $v2 -lt $v3 -and $v3 -lt $v4) {
        $diffs.Add([PSCustomObject]@{
            Offset = ("0x{0:X5}" -f $i)
            P1_Done = $v0
            Rolling = $v2
            Takeoff = $v3
            Airborne = $v4
            Banking = $v5
        })
    }
}

Write-Host "Found $($diffs.Count) monotonically increasing variables across flight:"
$diffs | Select-Object -First 25 | Format-Table -AutoSize
