function Test-TriagePrereq {
    [CmdletBinding()]
    param()

    $results = @()
    $results += [pscustomobject]@{ Check = 'PowerShellVersion'; Passed = ($PSVersionTable.PSVersion.Major -ge 5) }
    $results += [pscustomobject]@{ Check = 'GZipSupport'; Passed = $null -ne ([System.IO.Compression.CompressionMode]) }
    $results += [pscustomobject]@{ Check = 'AES'; Passed = $null -ne ([System.Security.Cryptography.Aes]::Create()) }
    return $results
}
