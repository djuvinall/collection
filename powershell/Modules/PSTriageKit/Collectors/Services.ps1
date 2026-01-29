[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    Get-Service | Select-Object Name, DisplayName, Status, StartType
}

Invoke-Collector -SinceHours $SinceHours
