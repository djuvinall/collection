function Get-ComputerMotherboard {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [switch]$UseWmiFallback
    )

    # If ComputerName not provided, do local CIM (no WinRM needed)
    $useRemote = -not [string]::IsNullOrWhiteSpace($ComputerName)

    try {
        $mb = if ($useRemote) {
            Get-CimInstance -ClassName Win32_BaseBoard -ComputerName $ComputerName -ErrorAction Stop |
                Select-Object -First 1
        } else {
            Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
                Select-Object -First 1
        }

        [pscustomobject]@{
            ComputerName  = if ($useRemote) { $ComputerName } else { $env:COMPUTERNAME }
            Manufacturer  = $mb.Manufacturer
            Product       = $mb.Product
            SerialNumber  = $mb.SerialNumber
            Version       = $mb.Version
            PartNumber    = $mb.PartNumber
        }
    }
    catch {
        if ($UseWmiFallback) {
            $mb = if ($useRemote) {
                Get-WmiObject -Class Win32_BaseBoard -ComputerName $ComputerName -ErrorAction Stop |
                    Select-Object -First 1
            } else {
                Get-WmiObject -Class Win32_BaseBoard -ErrorAction Stop |
                    Select-Object -First 1
            }

            [pscustomobject]@{
                ComputerName  = if ($useRemote) { $ComputerName } else { $env:COMPUTERNAME }
                Manufacturer  = $mb.Manufacturer
                Product       = $mb.Product
                SerialNumber  = $mb.SerialNumber
                Version       = $mb.Version
                PartNumber    = $mb.PartNumber
            }
        }
        else {
            throw
        }
    }
}

Export-Module -Function Get-ComputerMotherboard
