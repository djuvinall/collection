function New-RandomBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateRange(1,1048576)][int]$Length
    )

    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return $bytes
}
