function Get-MyPublicIP {
  (Invoke-RestMethod -Uri "ipinfo.io").ip
}