[CmdletBinding()]
param(
    [int]$SinceHours = 72
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 72
    )

    function Get-CimSafe {
        param(
            [string]$ClassName,
            [string]$Filter,
            [string]$Namespace
        )

        $params = @{ ClassName = $ClassName; ErrorAction = 'Stop' }
        if ($Filter) { $params['Filter'] = $Filter }
        if ($Namespace) { $params['Namespace'] = $Namespace }

        try { Get-CimInstance @params } catch { @() }
    }

    function Get-OrUnknown {
        param([object]$Value)
        if ($null -eq $Value) { return 'Unknown' }
        if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) { return 'Unknown' }
        return $Value
    }

    $cpuInfo = @(Get-CimSafe -ClassName 'Win32_Processor' | ForEach-Object {
        [pscustomobject]@{
            Name                 = Get-OrUnknown $_.Name
            Manufacturer         = Get-OrUnknown $_.Manufacturer
            NumberOfCores        = $_.NumberOfCores
            NumberOfLogicalProcessors = $_.NumberOfLogicalProcessors
            MaxClockSpeedMHz     = $_.MaxClockSpeed
        }
    })
    if (-not $cpuInfo -or $cpuInfo.Count -eq 0) { $cpuInfo = @([pscustomobject]@{ Name = 'Unknown'; Manufacturer = 'Unknown'; NumberOfCores = $null; NumberOfLogicalProcessors = $null; MaxClockSpeedMHz = $null }) }

    $gpuInfo = @(Get-CimSafe -ClassName 'Win32_VideoController' | ForEach-Object {
        [pscustomobject]@{
            Name          = Get-OrUnknown $_.Name
            AdapterRAM    = $_.AdapterRAM
            DriverVersion = Get-OrUnknown $_.DriverVersion
            DriverDate    = $_.DriverDate
        }
    })
    if (-not $gpuInfo -or $gpuInfo.Count -eq 0) { $gpuInfo = @([pscustomobject]@{ Name = 'Unknown'; AdapterRAM = $null; DriverVersion = 'Unknown'; DriverDate = $null }) }

    $motherboard = @(Get-CimSafe -ClassName 'Win32_BaseBoard' | Select-Object Manufacturer, Product, SerialNumber)
    if (-not $motherboard -or $motherboard.Count -eq 0) { $motherboard = @([pscustomobject]@{ Manufacturer = 'Unknown'; Product = 'Unknown'; SerialNumber = 'Unknown' }) }

    $bios = @(Get-CimSafe -ClassName 'Win32_BIOS' | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate)
    if (-not $bios -or $bios.Count -eq 0) { $bios = @([pscustomobject]@{ Manufacturer = 'Unknown'; SMBIOSBIOSVersion = 'Unknown'; ReleaseDate = $null }) }

    $memoryModules = @(Get-CimSafe -ClassName 'Win32_PhysicalMemory')
    $memoryTotal = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum
    $memory = [pscustomobject]@{
        TotalBytes = if ($memoryTotal) { [int64]$memoryTotal } else { 0 }
        Modules    = $memoryModules | Select-Object Capacity, Manufacturer, PartNumber, Speed
    }
    if (-not $memory.Modules) { $memory.Modules = @() }

    $disks = @(Get-CimSafe -ClassName 'Win32_DiskDrive' | ForEach-Object {
        [pscustomobject]@{
            Model       = Get-OrUnknown $_.Model
            SizeBytes   = if ($_.Size) { [int64]$_.Size } else { 0 }
            SerialNumber = Get-OrUnknown $_.SerialNumber
            MediaType   = Get-OrUnknown $_.MediaType
            Interface   = Get-OrUnknown $_.InterfaceType
        }
    })
    if (-not $disks -or $disks.Count -eq 0) { $disks = @([pscustomobject]@{ Model = 'Unknown'; SizeBytes = 0; SerialNumber = 'Unknown'; MediaType = 'Unknown'; Interface = 'Unknown' }) }

    $nics = @(Get-CimSafe -ClassName 'Win32_NetworkAdapter' -Filter 'PhysicalAdapter = true' | ForEach-Object {
        [pscustomobject]@{
            Name         = Get-OrUnknown $_.Name
            Manufacturer = Get-OrUnknown $_.Manufacturer
            MACAddress   = Get-OrUnknown $_.MACAddress
            Speed        = $_.Speed
            AdapterType  = Get-OrUnknown $_.AdapterType
        }
    })
    if (-not $nics -or $nics.Count -eq 0) { $nics = @([pscustomobject]@{ Name = 'Unknown'; Manufacturer = 'Unknown'; MACAddress = 'Unknown'; Speed = $null; AdapterType = 'Unknown' }) }

    $controllers = @()
    $controllers += @(Get-CimSafe -ClassName 'Win32_IDEController' | Select-Object Name, Manufacturer, PNPDeviceID)
    $controllers += @(Get-CimSafe -ClassName 'Win32_SCSIController' | Select-Object Name, Manufacturer, PNPDeviceID)
    if (-not $controllers -or $controllers.Count -eq 0) { $controllers = @([pscustomobject]@{ Name = 'Unknown'; Manufacturer = 'Unknown'; PNPDeviceID = 'Unknown' }) }

    $driverList = @(Get-CimSafe -ClassName 'Win32_PnPSignedDriver' | Select-Object DeviceName, DriverVersion, DriverDate, Manufacturer, DriverProviderName, DeviceID)
    if (-not $driverList) { $driverList = @() }

    $driverLookup = @{ }
    foreach ($driver in $driverList) {
        $driverLookup[$driver.DeviceID] = $driver
    }

    $peripheralClasses = @('USB','MEDIA','HIDClass','Keyboard','Mouse','AudioEndpoint','Sound','Net')
    $pnpDevices = @(Get-CimSafe -ClassName 'Win32_PnPEntity' | ForEach-Object {
        if ($_.PNPClass -notin $peripheralClasses) { return }
        $matchedDriver = $driverLookup[$_.DeviceID]
        [pscustomobject]@{
            Name           = Get-OrUnknown $_.Name
            Category       = Get-OrUnknown $_.PNPClass
            Manufacturer   = Get-OrUnknown $_.Manufacturer
            DriverVersion  = if ($matchedDriver) { Get-OrUnknown $matchedDriver.DriverVersion } else { 'Unknown' }
            DriverDate     = if ($matchedDriver) { $matchedDriver.DriverDate } else { $null }
            DriverProvider = if ($matchedDriver) { Get-OrUnknown $matchedDriver.DriverProviderName } else { 'Unknown' }
            DeviceId       = Get-OrUnknown $_.DeviceID
        }
    })
    if (-not $pnpDevices) { $pnpDevices = @() }

    return [pscustomobject]@{
        Cpu                = $cpuInfo
        Gpu                = $gpuInfo
        Motherboard        = $motherboard
        Bios               = $bios
        Memory             = $memory
        Disks              = $disks
        NetworkAdapters    = $nics
        StorageControllers = $controllers
        Drivers            = $driverList
        Peripherals        = $pnpDevices
    }
}

Invoke-Collector -SinceHours $SinceHours
