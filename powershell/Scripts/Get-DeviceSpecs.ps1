  # Collect Computer Specs

$finalSpecs = [PSCustomObject]@{
  Motherboard = $null
  CPU = $null
  RAM = $null
  GPU = $null
  Storage = $null
}

$a = Get-ComputerInfo
$b = Get-PhysicalDisk


$storage = [PSCustomObject]@{
  FriendlyName = $b.FriendlyName
  StorageType = $b.MediaType
  StorageSpace = [math]::Round(($b.Size / 1GB), 2)
}


$finalSpecs.Motherboard = (Get-WmiObject -Class Win32_BaseBoard).Product
$finalSpecs.CPU = $a.CsProcessors.Name
$finalSpecs.RAM = "{0:N2} GB" -f ($a.CsTotalPhysicalMemory / 1GB)
$finalSpecs.GPU = (Get-WmiObject -Class Win32_VideoController).Name
$finalSpecs.Storage = $storage
 
$finalSpecs | ConvertTo-Json | Out-File -FilePath "$PSScriptRoot\Specs.json" -Encoding UTF8

Write-Host "Computer specifications collected and saved to $PSScriptRoot\Specs.json" -ForegroundColor Green



#### TO DO ####
# Need to modularize this and turn it into a function
# It will need to return a rich powershell object
# Need to convert the WMI calls to CIM calls
