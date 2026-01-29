function Get-MyPublicIP {
  (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
}

Export-Module -Function Get-MyPublicIP
