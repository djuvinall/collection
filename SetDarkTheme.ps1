# Set Windows Personalization, color settings, to enable Dark mode for System
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0


# Set Windows Personalization, color settings, to enable Dark mode for Apps
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
Write-Host "Dark theme enabled."


# Stops and starts the explorer process to update the taskbark color
Stop-Process -Name explorer -Force; Start-Sleep -Seconds 2; Start-Process explorer
