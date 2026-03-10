function Add-GitKeep {
    <#
    .SYNOPSIS
        Scans for empty directories and adds a .gitkeep file to each one.

    .DESCRIPTION
        Recursively walks a target directory, finds any folders with no files
        in them (ignoring other .gitkeep files), and places a .gitkeep placeholder
        so Git will track the folder.

    .PARAMETER Path
        Root directory to scan. Defaults to current directory.

    .PARAMETER WhatIf
        Preview what would be created without actually writing any files.

    .EXAMPLE
        Add-GitKeep
        Add-GitKeep -Path "F:\localRepositories\SystemInventory"
        Add-GitKeep -Path "F:\localRepositories\SystemInventory" -WhatIf
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string]$Path = (Get-Location)
    )

    $Path = Resolve-Path $Path

    # Get all directories recursively
    $allDirs = Get-ChildItem -Path $Path -Recurse -Directory

    $added   = 0
    $skipped = 0

    foreach ($dir in $allDirs) {
        # Check for any files directly in this folder (not subdirs)
        $files = Get-ChildItem -Path $dir.FullName -File

        if ($files.Count -eq 0) {
            $gitkeepPath = Join-Path $dir.FullName ".gitkeep"

            if ($PSCmdlet.ShouldProcess($gitkeepPath, "Create .gitkeep")) {
                New-Item -ItemType File -Path $gitkeepPath -Force | Out-Null
                Write-Host "  [+] $($dir.FullName)" -ForegroundColor Green
                $added++
            }
        } else {
            Write-Verbose "  [skip] $($dir.FullName) ($($files.Count) file(s))"
            $skipped++
        }
    }

    return @{
        "Added"=$added
        "Skipped"= $skipped
    }
}

Export-ModuleMember -Function Add-GitKeep
