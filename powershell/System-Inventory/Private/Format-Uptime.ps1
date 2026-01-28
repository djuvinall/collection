function Format-Uptime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Uptime
    )

    $parts = @()
    if ($Uptime.Days -gt 0) {
        $parts += "{0}d" -f $Uptime.Days
    }

    $parts += "{0}h" -f $Uptime.Hours
    $parts += "{0}m" -f $Uptime.Minutes

    return $parts -join " "
}
