11#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Disables non-essential Windows services to reduce background overhead and
    optimize system performance on Windows desktops and workstations.

.DESCRIPTION
    Sets startup type to Disabled (and stops, if running) on a curated list of
    Windows services that are commonly recommended for disablement on
    general-purpose machines. Services are grouped into categories so callers
    can opt into specific buckets (e.g., Telemetry, PeerUpdates, Xbox).

    A JSON backup of each service's previous startup type and run state is
    written before changes are applied, allowing rollback via
    Restore-ServiceBaseline. Services that are not present on the host are
    reported as 'NotFound' and skipped without raising an error.

    SECURITY NOTE: Some services in the catalog (Print Spooler, Remote Registry)
    have notable historical CVEs but disabling them removes legitimate
    functionality. Choose categories based on the role of the target machine.

    POLICY NOTE: On AD- or Intune-joined endpoints, Group Policy / MDM settings
    generally take precedence and may re-enable services after this runs.
    Some services (notably DiagTrack on Enterprise/Education SKUs) are not
    fully suppressed by service state alone and require additional policy.

.NOTES
    Author : Devon
    Version: 1.0
    Requires: Elevation (admin), Windows OS, PowerShell 5.1 or 7+.

    Catalog distilled from MakeUseOf "Disable these Windows services
    recommended by Microsoft" and adjacent recommendations, cross-referenced
    against commonly accepted safe-to-disable lists.

.EXAMPLE
    PS> Disable-NonEssentialService -Category Telemetry,PeerUpdates -WhatIf

    Previews changes for telemetry and peer-update services without applying.

.EXAMPLE
    PS> Disable-NonEssentialService -Category All -ExcludeService Spooler,RemoteRegistry -Verbose

    Disables every catalog service except Print Spooler and Remote Registry,
    with verbose progress output.

.EXAMPLE
    PS> Restore-ServiceBaseline -BackupPath 'C:\ProgramData\ServiceBaseline\Backup_20260427_103000.json' -StartIfWasRunning

    Restores services to their pre-disable startup type and starts those that
    were originally running.
#>

#region Service catalog

$script:NonEssentialServiceCatalog = @(
    # --- Telemetry ---
    [PSCustomObject]@{ Name = 'DiagTrack';        DisplayName = 'Connected User Experiences and Telemetry';    Category = 'Telemetry';      Reason = 'Sends diagnostic and usage data to Microsoft.' }
    [PSCustomObject]@{ Name = 'dmwappushservice'; DisplayName = 'WAP Push Message Routing Service';            Category = 'Telemetry';      Reason = 'Device management messaging; rarely needed on consumer endpoints.' }

    # --- Peer-to-peer update sharing ---
    [PSCustomObject]@{ Name = 'DoSvc';            DisplayName = 'Delivery Optimization';                       Category = 'PeerUpdates';    Reason = 'P2P update sharing; consumes bandwidth and disk for non-LAN scenarios.' }

    # --- Compatibility / legacy diagnostic ---
    [PSCustomObject]@{ Name = 'PcaSvc';           DisplayName = 'Program Compatibility Assistant Service';     Category = 'Compatibility';  Reason = 'Monitors apps for compatibility issues; rarely useful on modern Windows.' }
    [PSCustomObject]@{ Name = 'RetailDemo';       DisplayName = 'Retail Demo Service';                         Category = 'Compatibility';  Reason = 'Powers retail store demo mode; not used outside retail kiosks.' }
    [PSCustomObject]@{ Name = 'wisvc';            DisplayName = 'Windows Insider Service';                     Category = 'Compatibility';  Reason = 'Required only for Windows Insider Program participation.' }

    # --- Indexing and caching ---
    [PSCustomObject]@{ Name = 'WSearch';          DisplayName = 'Windows Search';                              Category = 'SearchAndIndex'; Reason = 'Constant filesystem indexing; CPU/disk overhead, especially on HDDs.' }
    [PSCustomObject]@{ Name = 'SysMain';          DisplayName = 'SysMain (Superfetch)';                        Category = 'SearchAndIndex'; Reason = 'App preloading; minimal benefit on SSDs and can cause high disk usage.' }

    # --- Printing ---
    [PSCustomObject]@{ Name = 'Spooler';          DisplayName = 'Print Spooler';                               Category = 'Printing';       Reason = 'Disables ALL printing. Disable only on machines with no printers (security: PrintNightmare).' }

    # --- Mobility ---
    [PSCustomObject]@{ Name = 'icssvc';           DisplayName = 'Windows Mobile Hotspot Service';              Category = 'MobileHotspot';  Reason = 'Mobile hotspot sharing; only useful with cellular-capable devices.' }

    # --- Legacy / rarely needed ---
    [PSCustomObject]@{ Name = 'Fax';              DisplayName = 'Fax';                                         Category = 'LegacyHardware'; Reason = 'Fax modem support; not needed on virtually all modern machines.' }
    [PSCustomObject]@{ Name = 'TrkWks';           DisplayName = 'Distributed Link Tracking Client';            Category = 'LegacyHardware'; Reason = 'NTFS shortcut repair across volumes; rarely meaningful today.' }
    [PSCustomObject]@{ Name = 'AJRouter';         DisplayName = 'AllJoyn Router Service';                      Category = 'LegacyHardware'; Reason = 'IoT/AllJoyn protocol bridging; not used by typical home or office devices.' }
    [PSCustomObject]@{ Name = 'lmhosts';          DisplayName = 'TCP/IP NetBIOS Helper';                       Category = 'LegacyHardware'; Reason = 'NetBIOS name resolution; obsolete on networks using DNS only.' }
    [PSCustomObject]@{ Name = 'WMPNetworkSvc';    DisplayName = 'Windows Media Player Network Sharing Service'; Category = 'LegacyHardware'; Reason = 'Shares WMP libraries over UPnP; obsolete given modern streaming.' }
    [PSCustomObject]@{ Name = 'RemoteRegistry';   DisplayName = 'Remote Registry';                             Category = 'LegacyHardware'; Reason = 'Allows remote registry access; security exposure on standalone machines.' }

    # --- Maps ---
    [PSCustomObject]@{ Name = 'MapsBroker';       DisplayName = 'Downloaded Maps Manager';                     Category = 'Maps';           Reason = 'Required only by the Windows Maps app, which Microsoft is deprecating.' }

    # --- Xbox ---
    [PSCustomObject]@{ Name = 'XblAuthManager';   DisplayName = 'Xbox Live Auth Manager';                      Category = 'Xbox';           Reason = 'Xbox Live authentication; not needed without Xbox/Game Pass.' }
    [PSCustomObject]@{ Name = 'XblGameSave';      DisplayName = 'Xbox Live Game Save';                         Category = 'Xbox';           Reason = 'Xbox cloud save sync; not needed without Xbox titles.' }
    [PSCustomObject]@{ Name = 'XboxGipSvc';       DisplayName = 'Xbox Accessory Management Service';           Category = 'Xbox';           Reason = 'Xbox controller accessory configuration.' }
    [PSCustomObject]@{ Name = 'XboxNetApiSvc';    DisplayName = 'Xbox Live Networking Service';                Category = 'Xbox';           Reason = 'Xbox Live multiplayer networking helper.' }
)

#endregion

#region Functions

function Disable-NonEssentialService {
    <#
    .SYNOPSIS
        Disables and stops Windows services drawn from a curated catalog.

    .DESCRIPTION
        Iterates the script-level catalog of non-essential services, filters
        by Category and ExcludeService, sets each matching service's startup
        type to Disabled, and stops it if currently running.

        A JSON backup of original state is written to BackupPath unless
        -NoBackup is specified. Services not present on the host are reported
        but not treated as errors. Services managed by Group Policy may fail
        to update; the failure is reported and processing continues.

    .PARAMETER Category
        One or more catalog categories to act on, or 'All'. Defaults to a
        conservative set: Telemetry, PeerUpdates, LegacyHardware.

    .PARAMETER ExcludeService
        Service short names (e.g., 'Spooler') to skip even if their category
        is selected.

    .PARAMETER BackupPath
        Path to the JSON backup file. Defaults to a timestamped file under
        $env:ProgramData\ServiceBaseline.

    .PARAMETER NoBackup
        Suppresses backup file creation. Not recommended.

    .EXAMPLE
        PS> Disable-NonEssentialService -Category Telemetry,PeerUpdates -WhatIf

        Previews changes for telemetry and peer-update services without applying.

    .EXAMPLE
        PS> Disable-NonEssentialService -Category All -ExcludeService Spooler,RemoteRegistry -Verbose

        Disables every catalog service except Print Spooler and Remote Registry.

    .INPUTS
        None. Does not accept pipeline input.

    .OUTPUTS
        PSCustomObject  One result object per service processed, with fields:
                        Name, DisplayName, Category, PreviousStartType,
                        PreviousStatus, NewStartType, Status, Message, Timestamp.

    .NOTES
        Author : Devon
        Version: 1.0
        Requires elevation. Windows-only.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [ValidateSet('Telemetry', 'PeerUpdates', 'Compatibility', 'SearchAndIndex',
                     'Printing', 'MobileHotspot', 'LegacyHardware', 'Maps', 'Xbox', 'All')]
        [string[]]$Category = @('Telemetry', 'PeerUpdates', 'LegacyHardware'),

        [Parameter()]
        [string[]]$ExcludeService = @(),

        [Parameter()]
        [string]$BackupPath,

        [Parameter()]
        [switch]$NoBackup
    )

    begin {
        $cmdName = $MyInvocation.MyCommand
        Write-Verbose "[$cmdName] Run started at $(Get-Date -Format 'o')."

        # Resolve target catalog entries
        $targets = if ('All' -in $Category) {
            $script:NonEssentialServiceCatalog
        }
        else {
            $script:NonEssentialServiceCatalog | Where-Object { $_.Category -in $Category }
        }

        if ($ExcludeService.Count -gt 0) {
            $targets = $targets | Where-Object { $_.Name -notin $ExcludeService }
        }

        Write-Verbose "[$cmdName] $($targets.Count) services queued for processing."

        # Resolve backup destination
        if (-not $NoBackup) {
            if (-not $BackupPath) {
                $backupDir = Join-Path -Path $env:ProgramData -ChildPath 'ServiceBaseline'
                if (-not (Test-Path -LiteralPath $backupDir)) {
                    $null = New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction Stop
                }
                $BackupPath = Join-Path -Path $backupDir -ChildPath ("Backup_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
            }
            Write-Verbose "[$cmdName] Backup destination: $BackupPath"
        }

        $backupRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($target in $targets) {
            $serviceName = $target.Name
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

            if (-not $service) {
                Write-Verbose "[$cmdName] '$serviceName' not present on this host."
                [PSCustomObject]@{
                    Name              = $serviceName
                    DisplayName       = $target.DisplayName
                    Category          = $target.Category
                    PreviousStartType = $null
                    PreviousStatus    = $null
                    NewStartType      = $null
                    Status            = 'NotFound'
                    Message           = 'Service does not exist on this system.'
                    Timestamp         = (Get-Date).ToString('o')
                }
                continue
            }

            $prevStartType = $service.StartType
            $prevStatus    = $service.Status

            if ($prevStartType -eq 'Disabled') {
                Write-Verbose "[$cmdName] '$serviceName' already Disabled; no change."
                [PSCustomObject]@{
                    Name              = $serviceName
                    DisplayName       = $target.DisplayName
                    Category          = $target.Category
                    PreviousStartType = $prevStartType
                    PreviousStatus    = $prevStatus
                    NewStartType      = 'Disabled'
                    Status            = 'AlreadyDisabled'
                    Message           = 'No change required.'
                    Timestamp         = (Get-Date).ToString('o')
                }
                continue
            }

            $shouldProcessTarget = '{0} ({1})' -f $target.DisplayName, $serviceName
            $shouldProcessAction = 'Stop and set startup type to Disabled'

            if (-not $PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
                continue
            }

            # Capture original state for rollback
            $backupRecords.Add([PSCustomObject]@{
                Name        = $serviceName
                DisplayName = $target.DisplayName
                StartType   = $prevStartType.ToString()
                Status      = $prevStatus.ToString()
            })

            try {
                if ($prevStatus -eq 'Running') {
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    Write-Verbose "[$cmdName] Stopped '$serviceName'."
                }

                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                Write-Verbose "[$cmdName] Set '$serviceName' to Disabled."

                [PSCustomObject]@{
                    Name              = $serviceName
                    DisplayName       = $target.DisplayName
                    Category          = $target.Category
                    PreviousStartType = $prevStartType
                    PreviousStatus    = $prevStatus
                    NewStartType      = 'Disabled'
                    Status            = 'Success'
                    Message           = $target.Reason
                    Timestamp         = (Get-Date).ToString('o')
                }
            }
            catch {
                $errorRecord = $_

                $wrapped = [System.Management.Automation.ErrorRecord]::new(
                    $errorRecord.Exception,
                    'ServiceDisableFailed',
                    [System.Management.Automation.ErrorCategory]::OperationStopped,
                    $serviceName
                )
                $PSCmdlet.WriteError($wrapped)

                [PSCustomObject]@{
                    Name              = $serviceName
                    DisplayName       = $target.DisplayName
                    Category          = $target.Category
                    PreviousStartType = $prevStartType
                    PreviousStatus    = $prevStatus
                    NewStartType      = $null
                    Status            = 'Failed'
                    Message           = $errorRecord.Exception.Message
                    Timestamp         = (Get-Date).ToString('o')
                }
            }
        }
    }

    end {
        if (-not $NoBackup -and $backupRecords.Count -gt 0) {
            try {
                $backupRecords |
                    ConvertTo-Json -Depth 4 |
                    Set-Content -LiteralPath $BackupPath -Encoding UTF8 -ErrorAction Stop

                Write-Verbose "[$cmdName] Backup of $($backupRecords.Count) services written to $BackupPath."
            }
            catch {
                $PSCmdlet.WriteError($_)
            }
        }

        Write-Verbose "[$cmdName] Run complete."
    }
}

function Restore-ServiceBaseline {
    <#
    .SYNOPSIS
        Restores Windows service startup types from a backup JSON file
        produced by Disable-NonEssentialService.

    .DESCRIPTION
        Reads a backup file written by Disable-NonEssentialService and
        re-applies each recorded StartupType. Optionally re-starts services
        that were running at backup time.

    .PARAMETER BackupPath
        Path to the JSON backup file.

    .PARAMETER StartIfWasRunning
        If specified, services recorded as Running in the backup are started
        after their startup type is restored.

    .EXAMPLE
        PS> Restore-ServiceBaseline -BackupPath 'C:\ProgramData\ServiceBaseline\Backup_20260427_103000.json' -StartIfWasRunning -Verbose

        Restores services to their pre-disable state and starts those that
        were originally running.

    .INPUTS
        None.

    .OUTPUTS
        PSCustomObject  One result object per service processed.

    .NOTES
        Author : Devon
        Version: 1.0
        Requires elevation. Windows-only.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$BackupPath,

        [Parameter()]
        [switch]$StartIfWasRunning
    )

    begin {
        $cmdName = $MyInvocation.MyCommand

        try {
            $records = Get-Content -LiteralPath $BackupPath -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        Write-Verbose "[$cmdName] Loaded $($records.Count) records from $BackupPath."
    }

    process {
        foreach ($record in $records) {
            $serviceName = $record.Name
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

            if (-not $service) {
                Write-Verbose "[$cmdName] '$serviceName' not present, skipping."
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($serviceName, "Restore startup type to '$($record.StartType)'")) {
                continue
            }

            try {
                Set-Service -Name $serviceName -StartupType $record.StartType -ErrorAction Stop

                $started = $false
                if ($StartIfWasRunning -and $record.Status -eq 'Running') {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    $started = $true
                    Write-Verbose "[$cmdName] Started '$serviceName'."
                }

                [PSCustomObject]@{
                    Name       = $serviceName
                    RestoredTo = $record.StartType
                    Started    = $started
                    Status     = 'Success'
                    Message    = $null
                    Timestamp  = (Get-Date).ToString('o')
                }
            }
            catch {
                $PSCmdlet.WriteError($_)

                [PSCustomObject]@{
                    Name       = $serviceName
                    RestoredTo = $record.StartType
                    Started    = $false
                    Status     = 'Failed'
                    Message    = $_.Exception.Message
                    Timestamp  = (Get-Date).ToString('o')
                }
            }
        }
    }
}

#endregion

#region Main

# When invoked directly (not dot-sourced), this block is the entry point.
# Comment, uncomment, or replace the line below to control default behavior.
# By default the script only defines the functions, leaving execution to the
# caller — preferred when integrating into a larger optimization pipeline.

# Disable-NonEssentialService -Category Telemetry,PeerUpdates,LegacyHardware,SearchAndIndex,Compatibility -Verbose

#endregion