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
        Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
    }
    catch { @() }
}

Invoke-Collector -SinceHours $SinceHours
