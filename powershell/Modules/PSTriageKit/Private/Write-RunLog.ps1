function Write-RunLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Level = 'Info',
        [hashtable]$Data
    )

    $entry = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        level     = $Level
        message   = $Message
    }
    if ($Data) { $entry.data = $Data }
    $json = $entry | ConvertTo-Json -Compress
    Add-Content -Path $Path -Value $json
}
