function Test-IsInteractiveSession {
    <#
    .SYNOPSIS
        Detects if the current PowerShell session is running interactively (attached to a desktop).
    .DESCRIPTION
        Returns $true if the current process is running in a user-interactive session (Session ID 1 or higher) 
        with access to the Windows desktop. Returns $false if running as SYSTEM, from RMM "backstage", or any 
        background/non-interactive service context.
    .EXAMPLE
        if (-not (Test-IsInteractiveSession)) { Write-Host "Not interactive!" }
    #>
    try {
        $sessionId = (Get-Process -Id $PID).SessionId
        $isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)
        $desktop = $env:SESSIONNAME

        if ($isSystem -or $sessionId -eq 0 -or $desktop -eq 'Services') {
            return $false
        } else {
            return $true
        }
    }
    catch {
        Write-Warning "Failed to detect session type: $_"
        return $false
    }
}

Export-ModuleMember -Function Test-IsInteractiveSession
