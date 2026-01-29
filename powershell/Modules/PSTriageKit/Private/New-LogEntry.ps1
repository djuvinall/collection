function New-LogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Info','Warn','Error')][string]$Level,
        [Parameter(Mandatory)][string]$Message,
        [string]$Collector,
        [hashtable]$Data
    )

    $entry = [ordered]@{
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        level     = $Level
        message   = $Message
    }

    if ($Collector) {
        $entry['collector'] = $Collector
    }

    if ($Data) {
        $entry['data'] = $Data
    }

    return $entry
}
