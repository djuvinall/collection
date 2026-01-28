function Get-SystemInventory {
    <#
    .SYNOPSIS
    Collects a concise system inventory snapshot.

    .DESCRIPTION
    Gathers core system details useful for IT support, including OS, uptime,
    CPU, memory, disk usage, GPU, network adapters, domain/workgroup, BIOS
    version, and last boot time.

    .EXAMPLE
    Get-SystemInventory
    #>
    [CmdletBinding()]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS | Select-Object -First 1
    $gpus = Get-CimInstance -ClassName Win32_VideoController | Select-Object -ExpandProperty Name
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True"

    $lastBoot = [datetime]$os.LastBootUpTime
    $uptime = New-TimeSpan -Start $lastBoot -End (Get-Date)

    $domainOrWorkgroup = if ($computerSystem.PartOfDomain) {
        $computerSystem.Domain
    } else {
        $computerSystem.Workgroup
    }

    $biosVersion = if ($bios.SMBIOSBIOSVersion) {
        $bios.SMBIOSBIOSVersion
    } elseif ($bios.BIOSVersion) {
        $bios.BIOSVersion -join ", "
    } else {
        "Unknown"
    }

    [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        OS = $os.Caption
        OSVersion = $os.Version
        OSBuild = $os.BuildNumber
        LastBootTime = $lastBoot.ToString("yyyy-MM-dd HH:mm:ss")
        Uptime = Format-Uptime -Uptime $uptime
        CPU = $cpu.Name
        TotalMemory = Convert-BytesToReadable -Bytes $computerSystem.TotalPhysicalMemory
        DiskUsage = Format-DiskUsage -Disks $disks
        GPU = ($gpus -join ", ")
        NetworkAdapters = Format-NetworkAdapters -Adapters $adapters
        DomainOrWorkgroup = $domainOrWorkgroup
        BiosVersion = $biosVersion
    }
}
