function Write-PtkPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Collector,
        [Parameter(Mandatory)]
        $Data,
        [ValidateSet('Compress','Password')]
        [string]$Protect = 'Compress',
        [Security.SecureString]$Password,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [int]$KdfIterations = 200000
    )

    if ($Protect -eq 'Password' -and -not $Password) {
        throw 'Password is required when Protect=Password.'
    }

    $jsonBytes = ConvertTo-DeterministicJson -InputObject $Data -Depth 32
    $payload = Compress-Bytes -Bytes $jsonBytes

    $header = [ordered]@{
        version      = 1
        collector    = $Collector
        createdUtc   = (Get-Date).ToUniversalTime().ToString('o')
        protect      = $Protect
        contentType  = 'application/json'
        encoding     = 'utf-8'
        compression  = 'gzip'
    }

    if ($Protect -eq 'Password') {
        $salt = New-Object byte[] 16
        $iv = New-Object byte[] 16
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $rng.GetBytes($salt)
            $rng.GetBytes($iv)
        }
        finally { $rng.Dispose() }
        $material = Derive-KeyMaterial -Password $Password -Salt $salt -Iterations $KdfIterations

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $aes.KeySize = 256
        $aes.Key = $material.EncKey
        $aes.IV = $iv
        $encryptor = $aes.CreateEncryptor()
        $cipherStream = New-Object System.IO.MemoryStream
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($cipherStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $cryptoStream.Write($payload, 0, $payload.Length)
        $cryptoStream.FlushFinalBlock()
        $protectedPayload = $cipherStream.ToArray()
        $cryptoStream.Dispose()
        $cipherStream.Dispose()
        $aes.Dispose()
        $payload = $protectedPayload

        $header.kdf = 'PBKDF2-HMACSHA256'
        $header.iterations = $KdfIterations
        $header.saltB64 = [Convert]::ToBase64String($salt)
        $header.cipher = 'AES-256-CBC'
        $header.ivB64 = [Convert]::ToBase64String($iv)
        $header.mac = 'HMAC-SHA256'
    }

    $header.macB64 = ''

    $headerJson = ($header | ConvertTo-Json -Depth 6 -Compress)
    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerJson)

    if ($Protect -eq 'Password') {
        $macKey = $material.MacKey
        $mac = New-Object System.Security.Cryptography.HMACSHA256 -ArgumentList (, $macKey)
        $macStream = New-Object System.IO.MemoryStream
        $macStream.Write($headerBytes, 0, $headerBytes.Length)
        $macStream.Write($payload, 0, $payload.Length)
        $macBytes = $mac.ComputeHash($macStream.ToArray())
        $header.macB64 = [Convert]::ToBase64String($macBytes)
        $headerJson = ($header | ConvertTo-Json -Depth 6 -Compress)
        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headerJson)
    }

    $magic = [System.Text.Encoding]::ASCII.GetBytes('PSTKPTK1')
    $headerLength = [BitConverter]::GetBytes([uint32]$headerBytes.Length)
    if (-not (Test-Path -Path (Split-Path -Path $OutputPath))) {
        New-Item -ItemType Directory -Path (Split-Path -Path $OutputPath) -Force | Out-Null
    }
    $stream = [System.IO.File]::Create($OutputPath)
    try {
        $stream.Write($magic, 0, $magic.Length)
        $stream.Write($headerLength, 0, $headerLength.Length)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($payload, 0, $payload.Length)
    }
    finally {
        $stream.Dispose()
    }

    return [pscustomobject]@{
        Collector = $Collector
        Path      = $OutputPath
        Header    = $header
    }
}
