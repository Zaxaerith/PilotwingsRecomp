$p = "$env:LOCALAPPDATA\PilotwingsRunProbe"
$wram0 = [System.IO.File]::ReadAllBytes("$p\flight_00_p1_done.wram.bin")
$wram2 = [System.IO.File]::ReadAllBytes("$p\flight_02_rolling_fast.wram.bin")
$wram3 = [System.IO.File]::ReadAllBytes("$p\flight_03_takeoff_speed.wram.bin")
$wram4 = [System.IO.File]::ReadAllBytes("$p\flight_04_airborne_climbing.wram.bin")

Write-Host "Comparing WRAM values between Ground and Flight:"
Write-Host "Offset 0x58 (16-bit): P1_done=$([BitConverter]::ToUInt16($wram0, 0x58)) | Rolling=$([BitConverter]::ToUInt16($wram2, 0x58)) | TakeoffSpeed=$([BitConverter]::ToUInt16($wram3, 0x58)) | Airborne=$([BitConverter]::ToUInt16($wram4, 0x58))"
Write-Host "Offset 0x64 (16-bit): P1_done=$([BitConverter]::ToUInt16($wram0, 0x64)) | Rolling=$([BitConverter]::ToUInt16($wram2, 0x64)) | TakeoffSpeed=$([BitConverter]::ToUInt16($wram3, 0x64)) | Airborne=$([BitConverter]::ToUInt16($wram4, 0x64))"
Write-Host "Offset 0x60 (16-bit): P1_done=$([BitConverter]::ToInt16($wram0, 0x60)) | Rolling=$([BitConverter]::ToInt16($wram2, 0x60)) | TakeoffSpeed=$([BitConverter]::ToInt16($wram3, 0x60)) | Airborne=$([BitConverter]::ToInt16($wram4, 0x60))"
Write-Host "Offset 0x62 (16-bit): P1_done=$([BitConverter]::ToInt16($wram0, 0x62)) | Rolling=$([BitConverter]::ToInt16($wram2, 0x62)) | TakeoffSpeed=$([BitConverter]::ToInt16($wram3, 0x62)) | Airborne=$([BitConverter]::ToInt16($wram4, 0x62))"

Write-Host "`nDifferences in 0x00..0x100:"
for ($i = 0; $i -lt 0x100; $i += 2) {
    $v0 = [BitConverter]::ToUInt16($wram0, $i)
    $v2 = [BitConverter]::ToUInt16($wram2, $i)
    $v4 = [BitConverter]::ToUInt16($wram4, $i)
    if ($v0 -ne $v2 -or $v2 -ne $v4) {
        Write-Host ("  0x{0:X2}: P1={1,6} (0x{1:X4}) | Roll={2,6} (0x{2:X4}) | Air={3,6} (0x{3:X4})" -f $i, $v0, $v2, $v4)
    }
}
