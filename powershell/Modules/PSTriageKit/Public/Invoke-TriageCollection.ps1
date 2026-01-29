function Invoke-TriageCollection {
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [string]$Profile = 'default',
        [string[]]$Collectors,
        [string[]]$ExcludeCollectors,
        [int]$SinceHours = 72,
        [ValidateSet('Compress','Password')]
        [string]$Protect = 'Compress',
        [Security.SecureString]$Password,
        [switch]$Zip,
        [switch]$Force
    )

    if (-not $OutputPath) {
        $stamp = Get-NowString
        $OutputPath = Join-Path -Path (Get-Location) -ChildPath "triage-$($env:COMPUTERNAME)-$stamp"
    }

    if (Test-Path -Path $OutputPath) {
        if (-not $Force) { throw "OutputPath exists: $OutputPath" }
        Remove-Item -Path $OutputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $collectorOut = Join-Path -Path $OutputPath -ChildPath 'Collectors'
    New-Item -ItemType Directory -Path $collectorOut -Force | Out-Null

    $logPath = Join-Path -Path $OutputPath -ChildPath 'run.log.jsonl'

    $profileConfig = Get-ProfileConfig -Profile $Profile
    $includes = if ($Collectors) { $Collectors } elseif ($profileConfig.Collectors) { $profileConfig.Collectors } else { $null }
    $excludes = @()
    if ($ExcludeCollectors) { $excludes += $ExcludeCollectors }
    if ($profileConfig.Exclude) { $excludes += $profileConfig.Exclude }

    $collectorList = Get-CollectorList -Include $includes -Exclude $excludes
    $results = @()
    $skipped = @()

    Write-RunLog -Path $logPath -Message 'Starting collection' -Data @{ protect = $Protect; profile = $profileConfig.Name }

    foreach ($collector in $collectorList) {
        try {
            Write-RunLog -Path $logPath -Message "Collector $($collector.Name) starting"
            $data = Invoke-CollectorScript -Collector $collector -SinceHours $SinceHours
            $ptkPath = Join-Path -Path $collectorOut -ChildPath "$($collector.Name).ptk"
            $pkg = Write-PtkPackage -Collector $collector.Name -Data $data -Protect $Protect -Password $Password -OutputPath $ptkPath
            $results += [pscustomobject]@{
                Name = $collector.Name
                Path = $ptkPath
            }
            Write-RunLog -Path $logPath -Message "Collector $($collector.Name) completed" -Data @{ path = $ptkPath }
        }
        catch {
            $msg = $_.Exception.Message
            Write-RunLog -Path $logPath -Message "Collector $($collector.Name) skipped" -Level 'Warn' -Data @{ reason = $msg }
            $skipped += [pscustomobject]@{ Name = $collector.Name; Reason = $msg }
        }
    }

    $index = [ordered]@{
        tool        = 'PSTriageKit'
        version     = (Test-ModuleManifest (Join-Path -Path $PSScriptRoot -ChildPath '..\PSTriageKit.psd1')).Version.ToString()
        host        = $env:COMPUTERNAME
        createdUtc  = (Get-Date).ToUniversalTime().ToString('o')
        protect     = $Protect
        profile     = $profileConfig.Name
        collectors  = $results
        skipped     = $skipped
    }

    $indexPath = Join-Path -Path $OutputPath -ChildPath 'index.json'
    Write-Index -Path $indexPath -IndexObject $index

    $hashLines = Get-HashList -Root $OutputPath
    $hashPath = Join-Path -Path $OutputPath -ChildPath 'hashes.sha256'
    Set-Content -Path $hashPath -Value $hashLines

    if ($Zip) {
        $zipPath = "$OutputPath.zip"
        if (Test-Path -Path $zipPath) { Remove-Item -Path $zipPath -Force }
        Compress-Archive -Path $OutputPath -DestinationPath $zipPath -Force
    }

    return [pscustomobject]@{
        OutputPath = $OutputPath
        Collectors = $results
        Skipped    = $skipped
        Protect    = $Protect
        ZipPath    = if ($Zip) { "$OutputPath.zip" } else { $null }
    }
}
