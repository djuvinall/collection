function Get-TriageCollector {
    [CmdletBinding()]
    param(
        [string[]]$Name
    )

    $collectors = Get-CollectorList -Include $Name
    return $collectors
}
