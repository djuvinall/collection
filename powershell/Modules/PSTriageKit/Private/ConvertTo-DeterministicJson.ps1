function ConvertTo-DeterministicJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $InputObject,
        [int]$Depth = 16
    )

    $json = $InputObject | ConvertTo-Json -Depth $Depth -Compress
    return [System.Text.Encoding]::UTF8.GetBytes($json)
}
