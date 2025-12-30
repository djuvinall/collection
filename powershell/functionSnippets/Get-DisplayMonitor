Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
    [PSCustomObject]@{
        Manufacturer      = (-join[char[]]$_.ManufacturerName).Trim([char]0)
        Model             = (-join[char[]]$_.UserFriendlyName).Trim([char]0)
        SerialNumber      = (-join[char[]]$_.SerialNumberID).Trim([char]0)
        WeekOfManufacture = $_.WeekOfManufacture
        YearOfManufacture = $_.YearOfManufacture
    }
}
