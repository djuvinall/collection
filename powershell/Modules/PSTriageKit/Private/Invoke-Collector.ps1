function Invoke-Collector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CollectorPath,
        [int]$SinceHours = 24,
        [bool]$IsAdmin = $false
    )

    $parameters = @{
        SinceHours = $SinceHours
        IsAdmin    = $IsAdmin
    }

    return & $CollectorPath @parameters
}
