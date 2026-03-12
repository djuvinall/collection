function Start-InteractiveUpgrade {
    <#
    .SYNOPSIS
        Creates and launches a scheduled task to run Windows Setup interactively.
    .DESCRIPTION
        Useful when running from a non-interactive session (e.g., RMM backstage or SYSTEM context).
        The task runs as SYSTEM with /IT to attach to the console desktop.
    .PARAMETER SetupPath
        Full path to Setup.exe (usually from mounted ISO).
    .PARAMETER Arguments
        Command-line arguments for Setup.exe.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$SetupPath,

        [Parameter(Mandatory = $false)]
        [string]$Arguments = "/Auto Upgrade /Quiet /MigrateDrivers all /DynamicUpdate Disable /Telemetry disable /compat IgnoreWarning /ShowOOBE none /NoReboot /eula accept"
    )

    try {
        $taskName = "Win11_Interactive_Upgrade"
        Write-Host "Creating temporary scheduled task '$taskName'..." -ForegroundColor Yellow

        # Delete existing task if present
        schtasks /delete /tn $taskName /f 2>$null | Out-Null

        # Create the task (run once, interactively as SYSTEM)
        schtasks /create /tn $taskName `
            /tr "`"$SetupPath`" $Arguments" `
            /sc once /st 00:00 `
            /ru "SYSTEM" /rl HIGHEST /f | Out-Null

        # Launch the task immediately
        schtasks /run /tn $taskName | Out-Null

        Write-Host "✅ Upgrade process has been launched interactively via Task Scheduler." -ForegroundColor Green
        Write-Host "You can monitor progress from: C:\`$WINDOWS.~BT\Sources\Panther\" -ForegroundColor Cyan
    }
    catch {
        Write-Host "❌ Failed to launch interactive upgrade task: $_" -ForegroundColor Red
    }
}