$p = "$env:LOCALAPPDATA\PilotwingsRunProbe"
$wram0 = [System.IO.File]::ReadAllBytes("$p\flight_00_p1_done.wram.bin")
$wram2 = [System.IO.File]::ReadAllBytes("$p\flight_02_rolling_fast.wram.bin")
$wram3 = [System.IO.File]::ReadAllBytes("$p\flight_03_takeoff_speed.wram.bin")
$wram4 = [System.IO.File]::ReadAllBytes("$p\flight_04_airborne_climbing.wram.bin")
$wram5 = [System.IO.File]::ReadAllBytes("$p\flight_05_banking_right.wram.bin")
$wram6 = [System.IO.File]::ReadAllBytes("$p\flight_06_in_flight.wram.bin")

Write-Host "Searching full WRAM for active flight physics coordinates..."
$diffs = [System.Collections.Generic.List[PSObject]]::new()

for ($i = 0; $i -lt 0x2000; $i += 2) {
    $v0 = [BitConverter]::ToUInt16($wram0, $i)
    $v2 = [BitConverter]::ToUInt16($wram2, $i)
    $v3 = [BitConverter]::ToUInt16($wram3, $i)
    $v4 = [BitConverter]::ToUInt16($wram4, $i)
    $v5 = [BitConverter]::ToUInt16($wram5, $i)
    $v6 = [BitConverter]::ToUInt16($wram6, $i)

    # Looking for monotonically increasing or changing flight variables
    if ($v0 -ne $v2 -and $v2 -ne $v3 -and $v3 -ne $v4 -and $v4 -ne $v5) {
        $diffs.Add([PSCustomObject]@{
            Offset = ("0x{0:X4}" -f $i)
            P1_Done = $v0
            Rolling = $v2
            Takeoff = $v3
            Airborne = $v4
            Banking = $v5
            InFlight = $v6
        })
    }
}

Write-Host "Found $($diffs.Count) actively changing flight variables in 0x0000..0x2000:"
$diffs | Select-Object -First 30 | Format-Table -AutoSize
