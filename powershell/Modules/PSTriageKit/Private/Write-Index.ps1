function Write-Index {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        $IndexObject
    )

    $json = $IndexObject | ConvertTo-Json -Depth 8 -Compress
    Set-Content -Path $Path -Value $json
}
