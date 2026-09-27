# start_cd64.ps1 - start Commodore Desk 64 in VICE with working networking.
#
# Wi-Fi adapters drop the emulated RR-Net's frames, so VICE is attached to the
# Hyper-V "vEthernet (WSL)" adapter instead. Windows is the gateway there and
# routes on (internet, Tailscale). This script:
#   1. makes sure WSL runs (the adapter only exists while the WSL VM is up),
#   2. finds that adapter and its subnet (WSL may pick another one after a reboot),
#   3. writes the matching IP / MASK / GATEWAY into NET.CFG on the disk image
#      (keeps the chat server settings that are already there),
#   4. starts VICE with the RR-Net cartridge on that adapter.
param(
    [string]$Disk = "build\CD64.d71",
    [string]$Vice = "C:\Users\aegwh\OneDrive\dev\c64\vice\bin",
    [switch]$NoStart          # only update NET.CFG (for testing)
)
$ErrorActionPreference = "Continue"
Set-Location (Split-Path -Parent $PSScriptRoot)
$c1541 = Join-Path $Vice "c1541.exe"
$x64sc = Join-Path $Vice "x64sc.exe"

function Get-WslAdapter {
    Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "vEthernet (WSL*" -and $_.Status -eq "Up" } |
        Select-Object -First 1
}

# 1. WSL up (a hidden 'sleep' keeps the VM alive while VICE runs)
$keep = Start-Process wsl.exe -ArgumentList "-e", "sleep", "86400" -WindowStyle Hidden -PassThru
$adapter = $null
foreach ($i in 1..30) {
    $adapter = Get-WslAdapter
    if ($adapter) { break }
    Start-Sleep -Milliseconds 500
}
if (-not $adapter) {
    Write-Host "No 'vEthernet (WSL)' adapter found. Is WSL installed?" -ForegroundColor Red
    exit 1
}
$ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $adapter.ifIndex | Select-Object -First 1
$iface = "\Device\NPF_$($adapter.InterfaceGuid)"

# 2. C64 address in the same subnet: network + 3.64 (or + .64 for small nets)
$hostBytes = ([System.Net.IPAddress]::Parse($ip.IPAddress)).GetAddressBytes()
$prefix = $ip.PrefixLength
$maskVal = [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix))
$mask = [byte[]]@((($maskVal -shr 24) -band 255), (($maskVal -shr 16) -band 255),
                  (($maskVal -shr 8) -band 255), ($maskVal -band 255))
$c64 = [byte[]]@(0, 0, 0, 0)
for ($i = 0; $i -lt 4; $i++) { $c64[$i] = $hostBytes[$i] -band $mask[$i] }
if ($prefix -le 22) { $c64[2] = $c64[2] + 3 }
$c64[3] = 64
Write-Host "WSL adapter : $($adapter.Name)  ($iface)"
Write-Host "C64 network : IP $($c64 -join '.')  MASK $($mask -join '.')  GATEWAY $($ip.IPAddress)"

# 3. NET.CFG on the disk: keep what is there, only fix IP/MASK/GATEWAY
function ScreenCodes([string]$t, [int]$len) {
    $b = [byte[]]::new($len)
    for ($i = 0; $i -lt $len; $i++) { $b[$i] = 0xff }
    for ($i = 0; $i -lt $t.Length; $i++) {
        $c = [int][char]$t[$i]
        if ($c -ge 65 -and $c -le 90) { $c -= 64 }
        $b[$i] = [byte]$c
    }
    return ,$b
}
$tmp = Join-Path $env:TEMP "cd64_net.cfg"
Remove-Item $tmp -ErrorAction SilentlyContinue
& $c1541 -attach $Disk -read net.cfg $tmp *> $null
if ((Test-Path $tmp) -and (Get-Item $tmp).Length -eq 133) {
    $cfg = [System.IO.File]::ReadAllBytes($tmp)
} else {
    # no NET.CFG yet: the same defaults as the C64 (LM Studio + gemma)
    $list = New-Object System.Collections.Generic.List[byte]
    $list.AddRange([byte[]]@(0x00, 0xc4, 0x0e, 0x03))
    $list.AddRange([byte[]]::new(12))
    $list.AddRange([byte[]]@(1, 1, 1, 1))                       # DNS 1.1.1.1
    $list.AddRange((ScreenCodes "100.112.242.111" 33))
    $list.AddRange((ScreenCodes "1234" 6))
    $list.AddRange((ScreenCodes "" 41))
    $list.AddRange((ScreenCodes "GEMMA-1.1-2B-IT" 33))
    $cfg = $list.ToArray()
}
for ($i = 0; $i -lt 4; $i++) {
    $cfg[4 + $i]  = $c64[$i]          # IP
    $cfg[8 + $i]  = $mask[$i]         # MASK
    $cfg[12 + $i] = $hostBytes[$i]    # GATEWAY = Windows on the WSL switch
}
[System.IO.File]::WriteAllBytes($tmp, $cfg)
& $c1541 -attach $Disk -delete net.cfg *> $null
& $c1541 -attach $Disk -write $tmp net.cfg *> $null
if ($NoStart) { Stop-Process -Id $keep.Id -ErrorAction SilentlyContinue; exit 0 }

# 4. VICE with the RR-Net on the WSL adapter (a 1571 reads both D64 and D71)
$viceArgs = @("-drive8type", "1571", "+georam", "+reu",
              "-ethernetcart", "-ethernetcartmode", "1", "-ethernetcartbase", "0xDE00",
              "-ethernetioif", "`"$iface`"", "-autostart", "`"$Disk`"")
$vice = Start-Process $x64sc -ArgumentList $viceArgs -PassThru
$vice.WaitForExit()
Stop-Process -Id $keep.Id -ErrorAction SilentlyContinue
