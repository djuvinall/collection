function ConvertTo-GzipBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $output = New-Object System.IO.MemoryStream
    $gzip = New-Object System.IO.Compression.GzipStream($output, [System.IO.Compression.CompressionMode]::Compress)
    try {
        $gzip.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $gzip.Dispose()
    }

    return $output.ToArray()
}
