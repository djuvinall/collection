[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    $os = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, LastBootUpTime
    $uptime = if ($os.LastBootUpTime) { (New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)).ToString() } else { 'Unknown' }
    [pscustomobject]@{
        OS     = $os.Caption
        Version = $os.Version
        Build  = $os.BuildNumber
        Uptime = $uptime
    }
}

Invoke-Collector -SinceHours $SinceHours
