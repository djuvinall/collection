function Get-Sha256Hex {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Bytes')][byte[]]$Bytes,
        [Parameter(Mandatory, ParameterSetName = 'Path')][string]$Path
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()

    if ($PSCmdlet.ParameterSetName -eq 'Bytes') {
        $hashBytes = $sha.ComputeHash($Bytes)
    }
    else {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $hashBytes = $sha.ComputeHash($fs)
        }
        finally {
            $fs.Dispose()
        }
    }

    return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
}
