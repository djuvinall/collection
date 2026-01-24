function Get-ComputerCPU {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [switch]$UseWmiFallback
    )

    $useRemote = -not [string]::IsNullOrWhiteSpace($ComputerName)

    try {
        $cpu = if ($useRemote) {
            Get-CimInstance -ClassName Win32_Processor -ComputerName $ComputerName -ErrorAction Stop |
                Select-Object -First 1
        } else {
            Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
        }

        [pscustomobject]@{
            ComputerName          = if ($useRemote) { $ComputerName } else { $env:COMPUTERNAME }
            Name                  = $cpu.Name
            Manufacturer          = $cpu.Manufacturer
            Socket                = $cpu.SocketDesignation
            Cores                 = $cpu.NumberOfCores
            LogicalProcessors     = $cpu.NumberOfLogicalProcessors
            MaxClockMHz           = $cpu.MaxClockSpeed
            CurrentClockMHz       = $cpu.CurrentClockSpeed
            ProcessorId           = $cpu.ProcessorId
        }
    }
    catch {
        if ($UseWmiFallback) {
            $cpu = if ($useRemote) {
                Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName -ErrorAction Stop |
                    Select-Object -First 1
            } else {
                Get-WmiObject -Class Win32_Processor -ErrorAction Stop |
                    Select-Object -First 1
            }

            [pscustomobject]@{
                ComputerName          = if ($useRemote) { $ComputerName } else { $env:COMPUTERNAME }
                Name                  = $cpu.Name
                Manufacturer          = $cpu.Manufacturer
                Socket                = $cpu.SocketDesignation
                Cores                 = $cpu.NumberOfCores
                LogicalProcessors     = $cpu.NumberOfLogicalProcessors
                MaxClockMHz           = $cpu.MaxClockSpeed
                CurrentClockMHz       = $cpu.CurrentClockSpeed
                ProcessorId           = $cpu.ProcessorId
            }
        }
        else {
            throw
        }
    }
}

Export-Module -Function Get-ComputerCP
