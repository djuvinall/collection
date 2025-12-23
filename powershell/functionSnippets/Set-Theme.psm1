# Modify Windows 10/11 or Server theme (Light or Dark mode). Makes registry changes which  
# take effect upon reboot, or explorer.exe restart. Bypasses restriction to change theme on 
# unactivated  Windows installations. 
#
# Usage:
#   To switch to dark mode, run script, then run: Set-Theme -Mode Dark
#   To switch to light mode, run script, then run: Set-Theme -Mode Light
#
#   Optional: Restart the explorer.exe process: 
#             "Stop-Process -Name explorer -Force; Start-Sleep -Seconds 2; Start-Process explorer"
function Set-Theme {

    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("light", "dark")]
        [string]$Mode
    )

    function Set-DarkTheme {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
        Write-Host -f Yellow "Dark theme enabled.`n"
    }

    function Set-LightTheme {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 1
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 1
        Write-Host -f Yellow "Light theme enabled.`n"
    }

    switch ($Mode) {
        "dark" {
            Set-DarkTheme
        }
        "light" {
            Set-LightTheme
        }
    }

    # Stops and starts the explorer process to update the taskbark color
    Stop-Process -Name explorer -Force; Start-Sleep -Seconds 2; Start-Process explorer

        ## There is an error received that access is denied when stopping the explorer process but the process restarts anyways.
        ## Once the Process is restarted, a new file explorer window pops up, likely due ot the Start-Process explorer command
}

Export-ModuleMember -Function Set-Theme
