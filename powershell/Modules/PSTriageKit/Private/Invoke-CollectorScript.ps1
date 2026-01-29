function Invoke-CollectorScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Collector,
        [int]$SinceHours = 24
    )

    . $Collector.Path
    if (Get-Command -Name Invoke-Collector -ErrorAction SilentlyContinue) {
        try {
            return Invoke-Collector -SinceHours $SinceHours
        }
        finally {
            Remove-Item Function:\Invoke-Collector -ErrorAction SilentlyContinue
        }
    }
    else {
        throw "Collector $($Collector.Name) does not define Invoke-Collector."
    }
}
