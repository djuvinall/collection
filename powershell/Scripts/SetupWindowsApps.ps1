#Requires -Version 5.1

<#
.SYNOPSIS
    Sets up a new Windows machine with commonly used applications via winget.

.DESCRIPTION
    Installs a predefined list of applications using winget. Packages that are
    already installed are skipped. A summary of installed, skipped, and failed
    packages is displayed on completion.

.EXAMPLE
    .\SetupWindowsApps.ps1

.EXAMPLE
    .\SetupWindowsApps.ps1 -WhatIf
    Shows which applications would be installed without making any changes.

.NOTES
    Requires winget (Windows Package Manager). If missing, install the
    App Installer package from the Microsoft Store.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Apps = @(
    'Microsoft.PowerShell'
    'Git.Git'
    'Microsoft.VisualStudioCode'
    'Obsidian.Obsidian'
    'Microsoft.PowerToys'
    'VideoLAN.VLC'
    'Spotify.Spotify'
)

function Test-WingetAvailable {
    return [bool](Get-Command -Name winget -ErrorAction SilentlyContinue)
}

function Test-AppInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    winget list --id $AppId --exact --accept-source-agreements | Out-Null
    return $LASTEXITCODE -eq 0
}

if (-not (Test-WingetAvailable)) {
    throw 'winget is not available. Install the App Installer package from the Microsoft Store and try again.'
}

$Results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($App in $Apps) {
    Write-Verbose "Checking $App..."

    if (Test-AppInstalled -AppId $App) {
        Write-Host "[SKIP]    $App — already installed" -ForegroundColor Yellow
        $Results.Add([PSCustomObject]@{ App = $App; Status = 'Skipped' })
        continue
    }

    if ($PSCmdlet.ShouldProcess($App, 'Install via winget')) {
        Write-Host "[INSTALL] $App" -ForegroundColor Cyan
        try {
            winget install --id $App --exact --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) {
                throw "winget exited with code $LASTEXITCODE"
            }
            Write-Host "[OK]      $App" -ForegroundColor Green
            $Results.Add([PSCustomObject]@{ App = $App; Status = 'Installed' })
        }
        catch {
            Write-Warning "Failed to install ${App}: $_"
            $Results.Add([PSCustomObject]@{ App = $App; Status = 'Failed' })
        }
    }
}

Write-Host ''
Write-Host '--- Summary ---' -ForegroundColor White
$Results | Format-Table -AutoSize
