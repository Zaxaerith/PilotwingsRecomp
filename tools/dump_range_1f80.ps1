$p = "$env:LOCALAPPDATA\PilotwingsRunProbe"
$wram0 = [System.IO.File]::ReadAllBytes("$p\flight_00_p1_done.wram.bin")
$wram2 = [System.IO.File]::ReadAllBytes("$p\flight_02_rolling_fast.wram.bin")
$wram3 = [System.IO.File]::ReadAllBytes("$p\flight_03_takeoff_speed.wram.bin")
$wram4 = [System.IO.File]::ReadAllBytes("$p\flight_04_airborne_climbing.wram.bin")
$wram5 = [System.IO.File]::ReadAllBytes("$p\flight_05_banking_right.wram.bin")

Write-Host "WRAM range 0x1F80..0x2000 across flight phases:"
for ($i = 0x1F80; $i -lt 0x2000; $i += 2) {
    $v0 = [BitConverter]::ToUInt16($wram0, $i)
    $v2 = [BitConverter]::ToUInt16($wram2, $i)
    $v3 = [BitConverter]::ToUInt16($wram3, $i)
    $v4 = [BitConverter]::ToUInt16($wram4, $i)
    $v5 = [BitConverter]::ToUInt16($wram5, $i)
    if ($v0 -ne $v2 -or $v2 -ne $v3 -or $v3 -ne $v4 -or $v4 -ne $v5) {
        Write-Host ("  0x{0:X4}: P1=0x{1:X4} ({1,5}) | Roll=0x{2:X4} ({2,5}) | Takeoff=0x{3:X4} ({3,5}) | Air=0x{4:X4} ({4,5}) | Bank=0x{5:X4} ({5,5})" -f `
            $i, $v0, $v2, $v3, $v4, $v5)
    }
}
