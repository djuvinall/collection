function Show-TriageSummary {
    [CmdletBinding()]
    param(
        $Collection,
        [string]$Path,
        [Security.SecureString]$Password,
        [switch]$Formatted
    )

    if (-not $Collection) {
        $Collection = Get-TriageCollection -Path $Path
    }

    $data = Get-TriageData -Collection $Collection -All -Password $Password -AsHashtable
    $system = $data['SystemInfo']
    $users = $data['UsersAndGroups']
    $hardware = $data['HardwareInventory']
    $events = @($data['EventLogs'])
    $services = @($data['Services'])
    $processes = @($data['Processes'])
    $defender = @($data['DefenderStatus'])

    $osString = $null
    if ($system) {
        $osParts = @()
        if ($system.OS) { $osParts += $system.OS }
        $versionParts = @()
        if ($system.Version) { $versionParts += "Version $($system.Version)" }
        if ($system.Build) { $versionParts += "Build $($system.Build)" }
        if ($versionParts) { $osParts += "($($versionParts -join ', '))" }
        $osString = $osParts -join ' '
    }

    $cpuName = $null
    $gpuNames = @()
    $diskSummary = $null

    if ($hardware) {
        if ($hardware.Cpu) { $cpuName = @($hardware.Cpu | Select-Object -First 1).Name }
        if ($hardware.Gpu) { $gpuNames = @($hardware.Gpu | Where-Object { $_.Name } | Select-Object -ExpandProperty Name) }
        if ($hardware.Disks) {
            $diskStrings = foreach ($disk in @($hardware.Disks)) {
                $sizeGb = if ($disk.SizeBytes -gt 0) { [math]::Round($disk.SizeBytes / 1GB,1) } else { 0 }
                "$($disk.Model) ($sizeGb GB $($disk.MediaType))"
            }
            if ($diskStrings) { $diskSummary = $diskStrings -join '; ' }
        }
    }

    $recentCritical = @()
    if ($events) {
        $recentCritical = $events | Where-Object { $_.Level -in @('Critical','Error') } | Sort-Object -Property TimeCreated -Descending | Select-Object -First 5 LogName, Id, Level, ProviderName, TimeCreated, Message
    }

    $summary = [pscustomobject]@{
        ComputerName        = $env:COMPUTERNAME
        OS                  = $osString
        Uptime              = if ($system) { $system.Uptime } else { $null }
        UserCount           = if ($users) { @($users.Users).Count } else { 0 }
        AdminCount          = if ($users) { @($users.Administrators).Count } else { 0 }
        ServiceCount        = if ($services) { $services.Count } else { 0 }
        ProcessCount        = if ($processes) { $processes.Count } else { 0 }
        Cpu                 = $cpuName
        Gpu                 = if (@($gpuNames).Count -gt 0) { $gpuNames -join '; ' } else { $null }
        DiskSummary         = $diskSummary
        DefenderStatus      = if ($defender) { $defender | Select-Object -First 1 } else { $null }
        RecentCriticalEvents = @($recentCritical)
    }
    if ($Formatted) {
        $recentStrings = @()
        foreach ($e in $recentCritical) {
            $recentStrings += "[$($e.TimeCreated)] $($e.LogName) $($e.Level) $($e.Id): $($e.ProviderName)"
        }
        return [pscustomobject]@{
            ComputerName  = $summary.ComputerName
            OS            = $summary.OS
            Uptime        = $summary.Uptime
            Cpu           = $summary.Cpu
            Gpu           = $summary.Gpu
            DiskSummary   = $summary.DiskSummary
            Users         = $summary.UserCount
            Admins        = $summary.AdminCount
            Services      = $summary.ServiceCount
            Processes     = $summary.ProcessCount
            Defender      = $summary.DefenderStatus
            RecentEvents  = $recentStrings -join '; '
        }
    }

    return $summary
}
