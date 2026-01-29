function Compress-Bytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes
    )

    $output = New-Object System.IO.MemoryStream
    $gzip = New-Object System.IO.Compression.GzipStream($output, [System.IO.Compression.CompressionMode]::Compress, $true)
    $gzip.Write($Bytes, 0, $Bytes.Length)
    $gzip.Dispose()
    $outputBytes = $output.ToArray()
    $output.Dispose()
    return $outputBytes
}
