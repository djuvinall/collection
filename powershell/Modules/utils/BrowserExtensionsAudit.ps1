<#
.SYNOPSIS
    Detects Chrome and Edge browser extensions for all local user profiles.

.DESCRIPTION
    Enumerates all non-special user profiles via CIM, discovers Chrome and Edge
    browser profiles, reads each extension's manifest.json, resolves localized
    names/descriptions, and outputs structured objects to stdout.

    Designed for ConnectWise ASIO execution — self-contained, no external module
    dependencies, no mandatory parameters.

.NOTES
    Author  : Devon
    Platform: Windows (PowerShell 5.1+)
    Output  : Formatted table to stdout for ASIO capture
#>

#region --- Helper Functions ---

function Get-BrowserProfilePath {
    <#
    .SYNOPSIS
        Returns browser profile directories for a given user profile path.

    .DESCRIPTION
        Builds the User Data path for Chrome or Edge under the specified user
        profile and returns child directories matching Default or Profile*.

    .PARAMETER UserProfilePath
        Full filesystem path to the user's profile root (e.g., C:\Users\jdoe).

    .PARAMETER Browser
        Browser to target. Must be 'Chrome' or 'Edge'.

    .OUTPUTS
        System.IO.DirectoryInfo[]

    .EXAMPLE
        Get-BrowserProfilePath -UserProfilePath 'C:\Users\jdoe' -Browser 'Chrome'

    .NOTES
        Author: Devon
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$UserProfilePath,

        [Parameter(Mandatory)]
        [ValidateSet('Chrome', 'Edge')]
        [string]$Browser
    )

    begin { }
    process {
        $browserDataPath = if ($Browser -eq 'Chrome') {
            Join-Path -Path $UserProfilePath -ChildPath 'AppData\Local\Google\Chrome\User Data'
        }
        else {
            Join-Path -Path $UserProfilePath -ChildPath 'AppData\Local\Microsoft\Edge\User Data'
        }

        if (Test-Path -LiteralPath $browserDataPath) {
            Get-ChildItem -LiteralPath $browserDataPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^Default$|^Profile \d+$' }
        }
    }
    end { }
}

function Resolve-ExtensionLocalizedString {
    <#
    .SYNOPSIS
        Resolves a __MSG_key__ string from an extension's _locales directory.

    .DESCRIPTION
        Checks the _locales folder for en, en_US, and en_GB message files first,
        then falls back to any available locale. Returns the resolved string or
        the original value if no localization is needed.

    .PARAMETER ExtensionVersionPath
        Full path to the versioned extension directory containing _locales.

    .PARAMETER RawValue
        The raw string from manifest.json — may be a __MSG_key__ reference or plain text.

    .OUTPUTS
        System.String

    .EXAMPLE
        Resolve-ExtensionLocalizedString -ExtensionVersionPath 'C:\...\1.0.0_0' -RawValue '__MSG_appName__'

    .NOTES
        Author: Devon
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ExtensionVersionPath,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RawValue
    )

    begin { }
    process {
        if ([string]::IsNullOrWhiteSpace($RawValue)) { return 'N/A' }
        if ($RawValue -notmatch '^__MSG_(.+)__$') { return $RawValue }

        $messageKey = $Matches[1]
        $localesPath = Join-Path -Path $ExtensionVersionPath -ChildPath '_locales'

        if (-not (Test-Path -LiteralPath $localesPath)) { return 'N/A' }

        # Preferred locales first, then any fallback
        $preferredLocales = @('en', 'en_US', 'en_GB')
        $allLocales = Get-ChildItem -LiteralPath $localesPath -Directory -ErrorAction SilentlyContinue

        $orderedLocales = @(
            $allLocales | Where-Object { $_.Name -in $preferredLocales }
            $allLocales | Where-Object { $_.Name -notin $preferredLocales }
        )

        foreach ($locale in $orderedLocales) {
            $messagesFile = Join-Path -Path $locale.FullName -ChildPath 'messages.json'
            if (-not (Test-Path -LiteralPath $messagesFile)) { continue }

            try {
                $messages = Get-Content -LiteralPath $messagesFile -Raw -ErrorAction Stop | ConvertFrom-Json
                if ($messages.PSObject.Properties.Name -contains $messageKey) {
                    $resolved = $messages.$messageKey.message
                    if (-not [string]::IsNullOrWhiteSpace($resolved)) { return $resolved }
                }
            }
            catch {
                Write-Verbose "[$($MyInvocation.MyCommand)] Failed to parse messages.json in $($locale.FullName)"
                continue
            }
        }

        return 'N/A'
    }
    end { }
}

function Get-BrowserExtension {
    <#
    .SYNOPSIS
        Retrieves extension details from a browser profile's Extensions directory.

    .DESCRIPTION
        Enumerates each extension subfolder, reads the latest version's manifest.json,
        resolves localized name and description, and emits a PSCustomObject per extension.

    .PARAMETER ProfilePath
        Full path to the browser profile directory (e.g., ...\User Data\Default).

    .PARAMETER Browser
        Browser name — 'Chrome' or 'Edge'.

    .PARAMETER UserName
        Display name of the owning Windows user.

    .PARAMETER ComputerName
        Hostname of the machine.

    .OUTPUTS
        PSCustomObject with properties: Browser, User, ComputerName, ProfilePath,
        ExtensionID, Name, Version, Description, URL, InstallDate

    .EXAMPLE
        Get-BrowserExtension -ProfilePath 'C:\...\Default' -Browser 'Edge' -UserName 'jdoe' -ComputerName 'WS01'

    .NOTES
        Author: Devon
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter(Mandatory)]
        [ValidateSet('Chrome', 'Edge')]
        [string]$Browser,

        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    begin { }
    process {
        $extensionsRoot = Join-Path -Path $ProfilePath -ChildPath 'Extensions'
        if (-not (Test-Path -LiteralPath $extensionsRoot)) { return }

        $extensionDirs = Get-ChildItem -LiteralPath $extensionsRoot -Directory -ErrorAction SilentlyContinue
        foreach ($extDir in $extensionDirs) {
            try {
                # Grab the most recent version folder
                $versionDir = Get-ChildItem -LiteralPath $extDir.FullName -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending |
                    Select-Object -First 1

                if ($null -eq $versionDir) { continue }

                $manifestFile = Join-Path -Path $versionDir.FullName -ChildPath 'manifest.json'
                if (-not (Test-Path -LiteralPath $manifestFile)) { continue }

                $manifest = Get-Content -LiteralPath $manifestFile -Raw -ErrorAction Stop | ConvertFrom-Json

                $resolvedName = Resolve-ExtensionLocalizedString -ExtensionVersionPath $versionDir.FullName -RawValue $manifest.name
                $resolvedDesc = Resolve-ExtensionLocalizedString -ExtensionVersionPath $versionDir.FullName -RawValue $manifest.description

                $installDate = try { (Get-Item -LiteralPath $versionDir.FullName -ErrorAction Stop).CreationTime } catch { 'N/A' }
                $version     = if ($null -eq $manifest.version) { 'N/A' } else { $manifest.version }
                $url         = if ($null -eq $manifest.homepage_url) { 'N/A' } else { $manifest.homepage_url }

                [PSCustomObject]@{
                    Browser      = $Browser
                    User         = $UserName
                    ComputerName = $ComputerName
                    ProfilePath  = $ProfilePath
                    ExtensionID  = $extDir.Name
                    Name         = $resolvedName
                    Version      = $version
                    Description  = $resolvedDesc
                    URL          = $url
                    InstallDate  = $installDate
                }
            }
            catch {
                Write-Verbose "[$($MyInvocation.MyCommand)] Failed to process extension $($extDir.Name): $_"
                continue
            }
        }
    }
    end { }
}

#endregion

#region --- Main Execution ---

$computerName  = $env:COMPUTERNAME
$allExtensions = [System.Collections.Generic.List[PSObject]]::new()

# CIM replaces deprecated WMI calls — same data, better performance
$userProfiles = Get-CimInstance -ClassName Win32_UserProfile -Filter "Special = FALSE" -ErrorAction SilentlyContinue

foreach ($profile in $userProfiles) {
    $userProfilePath = $profile.LocalPath
    if ([string]::IsNullOrWhiteSpace($userProfilePath)) { continue }

    # Derive username from profile path — reliable and avoids Win32_Account lookup failures
    $userName = Split-Path -Path $userProfilePath -Leaf

    foreach ($browser in @('Chrome', 'Edge')) {
        $browserProfiles = Get-BrowserProfilePath -UserProfilePath $userProfilePath -Browser $browser
        foreach ($bp in $browserProfiles) {
            $extensions = Get-BrowserExtension -ProfilePath $bp.FullName -Browser $browser -UserName $userName -ComputerName $computerName
            foreach ($ext in $extensions) {
                $allExtensions.Add($ext)
            }
        }
    }
}

# Output — ASIO captures stdout
$allExtensions |
    Select-Object Browser, User, Name, ExtensionID, Version |
    Format-Table -AutoSize -Wrap

#endregion