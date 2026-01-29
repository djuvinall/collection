[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    try {
        Get-CimInstance -Namespace 'root\Microsoft\Windows\Defender' -ClassName MSFT_MpComputerStatus | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, QuickScanAge, FullScanAge, NISSignatureVersion, AntivirusSignatureVersion
    }
    catch { @() }
}

Invoke-Collector -SinceHours $SinceHours
