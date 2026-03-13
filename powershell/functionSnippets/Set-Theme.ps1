<#
.SYNOPSIS
    Sets the Windows light or dark theme by modifying the registry.

.DESCRIPTION
    Modifies the AppsUseLightTheme and SystemUsesLightTheme registry values under
    HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize to switch
    between Light and Dark mode on Windows 10, Windows 11, or Windows Server.

    Bypasses the standard theme UI restriction, making it usable on inactive or
    restricted Windows installations. After applying the registry change, restarts
    explorer.exe to apply the new taskbar and shell colors immediately — no reboot
    required.

    Known behavior: The Stop-Process call on explorer.exe may emit an "Access Denied"
    error; this is cosmetic — explorer restarts successfully regardless. The
    Start-Process explorer call may open a new File Explorer window as a side effect.

.PARAMETER Mode
    The theme to apply. Accepts 'Light' or 'Dark' (case-insensitive).

.EXAMPLE
    Set-Theme -Mode Dark

    Switches the system and app theme to Dark mode and restarts explorer.exe.

.EXAMPLE
    Set-Theme -Mode Dark -Verbose

    Switches the system and app theme to Dark mode and restarts explorer.exe,
    printing status messages to the verbose stream.

.EXAMPLE
    Set-Theme -Mode Light

    Switches the system and app theme to Light mode and restarts explorer.exe.

.EXAMPLE
    Set-Theme -Mode Light -Verbose

    Switches the system and app theme to Light mode and restarts explorer.exe,
    printing status messages to the verbose stream.

.OUTPUTS
    None. Applies registry changes as a side effect. Status written to verbose stream.

.INPUTS
    None. This function does not accept pipeline input.

.NOTES
    Author:       Devon
    Windows-only: Yes — depends on HKCU registry paths present only on Windows.
                  Will not function on Linux or macOS.
    Compatibility: Windows 10, Windows 11, Windows Server (2019+)
    Side effects:  Restarts explorer.exe; may open a new File Explorer window.
#>
function Set-Theme {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("light", "dark")]
        [string]$Mode
    )

    function Set-DarkTheme {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
        Write-Verbose "Dark theme enabled."
    }

    function Set-LightTheme {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 1
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 1
        Write-Verbose "Light theme enabled."
    }

    switch ($Mode) {
        "dark"  { Set-DarkTheme }
        "light" { Set-LightTheme }
    }

    # Stops and starts the explorer process to update the taskbar color.
    # Access Denied on Stop-Process is cosmetic — explorer restarts successfully.
    # Start-Process explorer may open a new File Explorer window as a side effect.
    Write-Verbose "Restarting explorer.exe to apply theme changes."
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Start-Process explorer
    Write-Verbose "Explorer restarted. Theme change applied."
}
