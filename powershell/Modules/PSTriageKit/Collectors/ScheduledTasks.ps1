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
        Get-ScheduledTask | Select-Object TaskName, State, Author, Description
    }
    catch { @() }
}

Invoke-Collector -SinceHours $SinceHours
