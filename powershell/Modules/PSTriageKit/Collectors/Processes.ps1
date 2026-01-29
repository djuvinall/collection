[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    Get-Process | Select-Object ProcessName, Id, Path, StartTime, Company
}

Invoke-Collector -SinceHours $SinceHours
