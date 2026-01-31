function Get-MyPublicIP {
  (Invoke-RestMethod -Uri "ipinfo.io").ip
}

Export-Module -Function Get-MyPublicIP
