<#
.SYNOPSIS
    Removes orphaned patch and installer files from C:\Windows\Installer.

.DESCRIPTION
    Queries the Windows Installer COM object (WindowsInstaller.Installer) to enumerate
    all registered products and their associated patch packages. Files and directories
    in C:\Windows\Installer that are NOT referenced by a registered product or patch
    are considered orphaned and removed.

    Supports -WhatIf for dry-run previewing. Requires elevation. Tested against
    PS 5.1 and PS 7+.

.PARAMETER InstallerPath
    Path to the Windows Installer directory. Defaults to C:\Windows\Installer.
    Override for testing against a staging copy.

.PARAMETER Force
    Suppresses the confirmation prompt before deletion begins.

.EXAMPLE
    Remove-OrphanedInstallerFile
    Runs interactively with confirmation prompt. No files deleted until confirmed.

.EXAMPLE
    Remove-OrphanedInstallerFile -WhatIf
    Dry run. Lists every file and directory that would be removed. Nothing is deleted.

.EXAMPLE
    Remove-OrphanedInstallerFile -Force -Verbose
    Runs without confirmation, printing verbose output for every kept and removed item.

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    None. Removal actions are reported via Write-Verbose and the native -WhatIf stream.

.NOTES
    Author:  Devon
    Version: 1.0.0
    Requires elevation (Run as Administrator).
    Windows-only — depends on the WindowsInstaller.Installer COM object.
    Original concept: Heath Stewart (Microsoft), adapted by Bryan Vine (2015).
#>
function Remove-OrphanedInstallerFile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param (
        [Parameter()]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [string]$InstallerPath = 'C:\Windows\Installer',

        [Parameter()]
        [switch]$Force
    )

    begin {
        #region Elevation check
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'This function must be run as Administrator. Restart your session elevated and try again.'
        }
        #endregion

        #region Build registered path set via COM (O(1) lookups)
        Write-Verbose "[$($MyInvocation.MyCommand)] Querying WindowsInstaller COM object for registered packages..."

        try {
            $msi = New-Object -ComObject WindowsInstaller.Installer -ErrorAction Stop
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # HashSet for O(1) path lookups — normalise to lowercase for case-insensitive match
        $registeredPaths = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        # Also track product/patch GUIDs for directory-name matching
        $registeredGuids = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        try {
            foreach ($productCode in $msi.Products()) {
                [void]$registeredGuids.Add($productCode)

                foreach ($patchCode in $msi.Patches($productCode)) {
                    [void]$registeredGuids.Add($patchCode)

                    $localPackage = $msi.PatchInfo($patchCode, 'LocalPackage')
                    if (-not [string]::IsNullOrWhiteSpace($localPackage)) {
                        [void]$registeredPaths.Add($localPackage)
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        finally {
            # Release COM object whether enumeration succeeded or not
            if ($null -ne $msi) {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($msi)
            }
        }

        Write-Verbose "[$($MyInvocation.MyCommand)] Found $($registeredPaths.Count) registered patch path(s) and $($registeredGuids.Count) registered GUID(s)."
        #endregion

        #region Confirmation gate (skipped when -WhatIf or -Force is used)
        if (-not $Force -and -not $WhatIfPreference) {
            $target = "all orphaned files and directories under $InstallerPath"
            if (-not $PSCmdlet.ShouldContinue($target, 'Confirm removal of orphaned installer files?')) {
                Write-Verbose "[$($MyInvocation.MyCommand)] User declined confirmation. Aborting."
                return
            }
        }
        #endregion
    }

    process {
        #region Pass 1 — orphaned files
        Write-Verbose "[$($MyInvocation.MyCommand)] Pass 1: scanning files in $InstallerPath..."

        $files = Get-ChildItem -LiteralPath $InstallerPath -File -ErrorAction Stop

        foreach ($file in $files) {
            if ($registeredPaths.Contains($file.FullName)) {
                Write-Verbose "[$($MyInvocation.MyCommand)] KEEP (registered path)  : $($file.FullName)"
            }
            else {
                Write-Verbose "[$($MyInvocation.MyCommand)] REMOVE (orphaned file)  : $($file.FullName)"
                if ($PSCmdlet.ShouldProcess($file.FullName, 'Remove-Item')) {
                    try {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    }
                    catch {
                        $PSCmdlet.WriteError($_)
                    }
                }
            }
        }
        #endregion

        #region Pass 2 — orphaned directories
        Write-Verbose "[$($MyInvocation.MyCommand)] Pass 2: scanning directories in $InstallerPath..."

        $directories = Get-ChildItem -LiteralPath $InstallerPath -Directory -ErrorAction Stop

        foreach ($dir in $directories) {
            # Directory names are typically GUIDs matching a product or patch code
            $isRegistered = $registeredGuids.Contains($dir.Name) -or
                            ($registeredPaths | Where-Object { $_.StartsWith($dir.FullName, [System.StringComparison]::OrdinalIgnoreCase) })

            if ($isRegistered) {
                Write-Verbose "[$($MyInvocation.MyCommand)] KEEP (registered GUID)  : $($dir.FullName)"
            }
            else {
                Write-Verbose "[$($MyInvocation.MyCommand)] REMOVE (orphaned dir)   : $($dir.FullName)"
                if ($PSCmdlet.ShouldProcess($dir.FullName, 'Remove-Item -Recurse')) {
                    try {
                        Remove-Item -LiteralPath $dir.FullName -Force -Recurse -ErrorAction Stop
                    }
                    catch {
                        $PSCmdlet.WriteError($_)
                    }
                }
            }
        }
        #endregion
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand)] Scan complete."
    }
}

# ── Entry point ──────────────────────────────────────────────────────────────
# Dot-source or paste this file, then call the function.
# Examples:
#   Remove-OrphanedInstallerFile -WhatIf           # dry run
#   Remove-OrphanedInstallerFile -Verbose          # with confirmation prompt
#   Remove-OrphanedInstallerFile -Force -Verbose   # no prompt, full logging