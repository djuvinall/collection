function Expand-GzipBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][byte[]]$Bytes
    )

    $input = New-Object System.IO.MemoryStream(,$Bytes)
    $gzip = New-Object System.IO.Compression.GzipStream($input, [System.IO.Compression.CompressionMode]::Decompress)
    $output = New-Object System.IO.MemoryStream
    try {
        $buffer = New-Object byte[] 4096
        while (($read = $gzip.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $read)
        }
    }
    finally {
        $gzip.Dispose()
        $input.Dispose()
    }

    return [System.Text.Encoding]::UTF8.GetString($output.ToArray())
}
