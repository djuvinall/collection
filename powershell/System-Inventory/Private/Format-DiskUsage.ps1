function Format-DiskUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Disks
    )

    $items = foreach ($disk in $Disks) {
        if (-not $disk.Size) {
            continue
        }

        $size = [double]$disk.Size
        $free = [double]$disk.FreeSpace
        $used = $size - $free
        $percent = if ($size -gt 0) { [math]::Round(($used / $size) * 100) } else { 0 }

        "{0}: {1} / {2} ({3}%)" -f $disk.DeviceID, (Convert-BytesToReadable -Bytes $used), (Convert-BytesToReadable -Bytes $size), $percent
    }

    if (-not $items -or $items.Count -eq 0) {
        return "None"
    }

    return $items -join "; "
}
