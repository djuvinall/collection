#Requires -Version 5.1

<#
.SYNOPSIS
    Tools to assist with creating and managing symbolic links on Windows.

.DESCRIPTION
    Provides functions for moving files/folders and replacing them with symbolic
    links, as well as utilities for inspecting existing symbolic links.
    Symbolic link creation requires either elevated privileges or Developer Mode
    enabled on Windows 10/11.

.NOTES
    Author:  Devon
    Version: 1.0.0
    Requires: Windows (New-Item -ItemType SymbolicLink is Windows-only)
    PSScriptAnalyzer: Export-ModuleMember is valid in .psm1 context only.
                      If this runs as a script, remove that call.
#>


#region Helpers

function Test-SymbolicLink {
    <#
    .SYNOPSIS
        Returns true if the specified path is a symbolic link.

    .DESCRIPTION
        Checks whether the item at the given path exists and has the ReparsePoint
        attribute set, which is how Windows marks symbolic links.

    .PARAMETER Path
        The full path to the file or directory to test.

    .OUTPUTS
        [bool] — $true if the path is a symbolic link, $false otherwise.

    .INPUTS
        None. Does not accept pipeline input.

    .EXAMPLE
        Test-SymbolicLink -Path 'C:\Games\SaveData'
        # Returns $true if SaveData is a symlink.

    .NOTES
        Author:  Devon
        Version: 1.0.0
        Windows-only: ReparsePoint attribute behavior is Windows-specific.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Path -Force
    return ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}


function Get-SymbolicLinkTarget {
    <#
    .SYNOPSIS
        Returns the target path that a symbolic link points to.

    .DESCRIPTION
        Resolves the target of a symbolic link at the given path. Returns $null
        and writes an error if the path does not exist or is not a symbolic link.

    .PARAMETER Path
        The full path to the symbolic link to inspect.

    .OUTPUTS
        [string] — The resolved target path, or $null if not a valid symlink.

    .INPUTS
        None. Does not accept pipeline input.

    .EXAMPLE
        Get-SymbolicLinkTarget -Path 'C:\Games\SaveData'
        # Returns something like 'D:\Storage\SaveData'

    .NOTES
        Author:  Devon
        Version: 1.0.0
        Windows-only: LinkTarget property is available in PS 6+ on Windows.
                      On PS 5.1, falls back to the Target property.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-SymbolicLink -Path $Path)) {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.IO.IOException]::new("'$Path' is not a symbolic link or does not exist."),
                'NotASymbolicLink',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Path
            )
        )
        return $null
    }

    $item = Get-Item -LiteralPath $Path -Force

    # LinkTarget is PS 6+; fall back to Target for 5.1 compatibility
    if ($item.PSObject.Properties['LinkTarget']) {
        return $item.LinkTarget
    }
    return $item.Target
}

#endregion Helpers


#region Exported Functions

function Move-SymbolicTarget {
    <#
    .SYNOPSIS
        Moves a file or folder to a new location and leaves a symbolic link in its place.

    .DESCRIPTION
        Moves the item at $Source to $Target (optionally rooted under $Root),
        then creates a symbolic link at the original $Source path pointing to the
        new location. This is useful for redirecting application data directories
        to a different drive without changing the path the application sees.

        Symbolic link creation requires either:
          - An elevated (Administrator) PowerShell session, OR
          - Developer Mode enabled (Windows 10 version 1703+)

        The function will abort without making changes if:
          - $Source does not exist
          - $Source is already a symbolic link
          - $Target already exists as a file or folder
          - The current process lacks symlink creation rights

    .PARAMETER Root
        Optional. A base directory prepended to both $Source and $Target using
        Join-Path. Useful when both paths are relative to a common root.

    .PARAMETER Source
        The path to the file or folder to move. If $Root is provided, this is
        treated as relative to $Root.

    .PARAMETER Target
        The destination directory to move $Source into. The item will land at
        $Target\<SourceLeafName>. If $Root is provided, this is relative to $Root.

    .OUTPUTS
        [System.IO.FileSystemInfo] — The FileSystemInfo object for the newly
        created symbolic link, as returned by New-Item.

    .INPUTS
        None. Does not accept pipeline input.

    .EXAMPLE
        Move-SymbolicTarget -Source 'C:\Users\Devon\AppData\Roaming\SomeApp' `
                            -Target 'D:\AppData'
        # Moves SomeApp to D:\AppData\SomeApp and creates a symlink at the original path.

    .EXAMPLE
        Move-SymbolicTarget -Root 'C:\Users\Devon\AppData\Roaming' `
                            -Source 'SomeApp' `
                            -Target 'D:\AppData'
        # Same result using -Root to avoid repeating the base path.

    .EXAMPLE
        Move-SymbolicTarget -Source 'C:\Data\Saves' -Target 'D:\Storage' -WhatIf
        # Preview what would happen without making any changes.

    .NOTES
        Author:  Devon
        Version: 1.0.0
        Windows-only: New-Item -ItemType SymbolicLink requires Windows.
        Requires elevation or Developer Mode for symlink creation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileSystemInfo])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    # Resolve full paths
    if (-not [string]::IsNullOrEmpty($Root)) {
        $Source = Join-Path $Root $Source
        $Target = Join-Path $Root $Target
    }

    # --- Validation ---

    if (-not (Test-Path -LiteralPath $Source)) {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileNotFoundException]::new("Source path does not exist: '$Source'"),
                'SourceNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Source
            )
        )
        return
    }

    if (Test-SymbolicLink -Path $Source) {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("Source '$Source' is already a symbolic link."),
                'SourceIsSymlink',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $Source
            )
        )
        return
    }

    # The item will land at $Target\<leaf> — check that destination doesn't already exist
    $leafName        = Split-Path $Source -Leaf
    $resolvedTarget  = Join-Path $Target $leafName

    if (Test-Path -LiteralPath $resolvedTarget) {
        $PSCmdlet.WriteError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.IO.IOException]::new("Destination already exists: '$resolvedTarget'"),
                'DestinationExists',
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $resolvedTarget
            )
        )
        return
    }

    # --- Privilege check (Windows-only; skip gracefully on non-Windows) ---
    if ($IsWindows -or -not (Test-Path Variable:\IsWindows)) {
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $isElevated        = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # Developer Mode check (registry key present = enabled)
        $devModeKey  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $devModeOn   = (Get-ItemProperty -Path $devModeKey -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue)?.AllowDevelopmentWithoutDevLicense -eq 1

        if (-not $isElevated -and -not $devModeOn) {
            $PSCmdlet.WriteError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.UnauthorizedAccessException]::new(
                        'Symbolic link creation requires an elevated session or Developer Mode. ' +
                        'Enable Developer Mode in Settings > Privacy & Security > For Developers.'
                    ),
                    'InsufficientPrivilege',
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $Source
                )
            )
            return
        }
    }

    # --- Execute ---

    if ($PSCmdlet.ShouldProcess($Source, "Move to '$resolvedTarget' and replace with symbolic link")) {
        try {
            Move-Item -LiteralPath $Source -Destination $Target -ErrorAction Stop
            Write-Verbose "Moved '$Source' to '$resolvedTarget'"

            $link = New-Item -ItemType SymbolicLink -Path $Source -Target $resolvedTarget -ErrorAction Stop
            Write-Verbose "Created symbolic link: '$Source' -> '$resolvedTarget'"

            return $link
        }
        catch {
            # If Move-Item succeeded but New-Item failed, we're in a broken state.
            # Attempt rollback and surface a clear error.
            if (-not (Test-Path -LiteralPath $Source) -and (Test-Path -LiteralPath $resolvedTarget)) {
                Write-Warning "Symlink creation failed after move. Attempting rollback: '$resolvedTarget' -> '$Source'"
                try {
                    Move-Item -LiteralPath $resolvedTarget -Destination (Split-Path $Source -Parent) -ErrorAction Stop
                    Write-Verbose "Rollback succeeded."
                }
                catch {
                    Write-Warning "Rollback failed. '$resolvedTarget' was NOT moved back. Manual intervention required."
                }
            }

            $PSCmdlet.WriteError(
                [System.Management.Automation.ErrorRecord]::new(
                    $_.Exception,
                    'MoveSymbolicTargetFailed',
                    [System.Management.Automation.ErrorCategory]::NotSpecified,
                    $Source
                )
            )
        }
    }
}

#endregion Exported Functions


Export-ModuleMember -Function Move-SymbolicTarget, Get-SymbolicLinkTarget, Test-SymbolicLink