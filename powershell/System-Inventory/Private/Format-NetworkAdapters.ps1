function Format-NetworkAdapters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Adapters
    )

    $items = foreach ($adapter in $Adapters) {
        $addresses = @($adapter.IPAddress | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' })
        if ($addresses.Count -eq 0) {
            continue
        }

        $name = if ($adapter.NetConnectionID) { $adapter.NetConnectionID } else { $adapter.Description }
        "{0} {1}" -f $name, ($addresses -join ", ")
    }

    if (-not $items -or $items.Count -eq 0) {
        return "None"
    }

    return $items -join "; "
}
