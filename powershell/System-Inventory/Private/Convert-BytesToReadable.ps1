function Convert-BytesToReadable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )

    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $size = [double]$Bytes
    $unitIndex = 0

    while ($size -ge 1024 -and $unitIndex -lt ($units.Count - 1)) {
        $size = $size / 1024
        $unitIndex++
    }

    if ($unitIndex -eq 0) {
        return "{0} {1}" -f [math]::Round($size, 0), $units[$unitIndex]
    }

    return "{0:N1} {1}" -f $size, $units[$unitIndex]
}
