function Derive-KeyMaterial {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Security.SecureString]$Password,
        [Parameter(Mandatory)]
        [byte[]]$Salt,
        [int]$Iterations = 200000
    )

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($plain, $Salt, $Iterations, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $key = $kdf.GetBytes(64)
        $enc = [byte[]]($key[0..31])
        $mac = [byte[]]($key[32..63])
        return [pscustomobject]@{
            EncKey = $enc
            MacKey = $mac
        }
    }
    finally {
        if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
}
