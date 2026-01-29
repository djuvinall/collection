function Read-PtkPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Security.SecureString]$Password
    )

    if (-not (Test-Path -Path $Path)) {
        throw "PTK file not found: $Path"
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $offset = 0
    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 8)
    if ($magic -ne 'PSTKPTK1') {
        throw 'Invalid PTK magic header.'
    }
    $offset += 8
    $headerLen = [BitConverter]::ToUInt32($bytes, $offset)
    $offset += 4
    $headerJson = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $headerLen)
    $offset += $headerLen
    $header = $headerJson | ConvertFrom-Json
    $payload = $bytes[$offset..($bytes.Length - 1)]

    $expectedMac = $null
    if ($header.protect -eq 'Password') {
        if (-not $Password) {
            throw 'Password is required to read this PTK file.'
        }
        $salt = [Convert]::FromBase64String($header.saltB64)
        $iv = [Convert]::FromBase64String($header.ivB64)
        $material = Derive-KeyMaterial -Password $Password -Salt $salt -Iterations $header.iterations
        $expectedMac = $header.macB64
        $mac = New-Object System.Security.Cryptography.HMACSHA256 -ArgumentList (, $material.MacKey)
        $macStream = New-Object System.IO.MemoryStream
        $header.macB64 = ''
        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(($header | ConvertTo-Json -Depth 6 -Compress))
        $macStream.Write($headerBytes, 0, $headerBytes.Length)
        $macStream.Write($payload, 0, $payload.Length)
        $computed = $mac.ComputeHash($macStream.ToArray())
        $expected = [Convert]::FromBase64String($expectedMac)
        if (-not ($computed -ceq $expected)) {
            throw 'Authentication failed for PTK payload. Password may be incorrect.'
        }

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $aes.KeySize = 256
        $aes.Key = $material.EncKey
        $aes.IV = $iv
        $decryptor = $aes.CreateDecryptor()
        $cipherStream = New-Object System.IO.MemoryStream(,$payload)
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($cipherStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
        $plainStream = New-Object System.IO.MemoryStream
        $buffer = New-Object byte[] 4096
        while (($read = $cryptoStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $plainStream.Write($buffer, 0, $read)
        }
        $cryptoStream.Dispose()
        $cipherStream.Dispose()
        $aes.Dispose()
        $payload = $plainStream.ToArray()
        $plainStream.Dispose()
    }

    if ($expectedMac) { $header.macB64 = $expectedMac }
    $jsonBytes = Expand-Bytes -Bytes $payload
    $json = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
    $data = $json | ConvertFrom-Json

    return [pscustomobject]@{
        Header = $header
        Data   = $data
        Path   = $Path
    }
}
