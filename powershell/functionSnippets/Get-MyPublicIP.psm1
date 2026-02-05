function Get-MyPublicIP {
  (Invoke-RestMethod -Uri "ipinfo.io").ip
}

Export-ModuleMember -Function Get-MyPublicIP
