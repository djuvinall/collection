@{
    RootModule = 'System-Inventory.psm1'
    ModuleVersion = '0.1.0'
    GUID = '6d553d37-0b9d-4a8f-a56b-1bc3b2c8d9d5'
    Author = 'PowerShell-Forge'
    CompanyName = 'PowerShell-Forge'
    Copyright = '(c) 2026 PowerShell-Forge. All rights reserved.'
    Description = 'System inventory reporting module.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-SystemInventory', 'Write-SystemInventoryReport')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('inventory', 'system', 'reporting')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = ''
        }
    }
}
