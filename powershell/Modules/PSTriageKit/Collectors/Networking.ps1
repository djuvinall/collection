[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv6Address, InterfaceDescription, DNSServer
}

Invoke-Collector -SinceHours $SinceHours
