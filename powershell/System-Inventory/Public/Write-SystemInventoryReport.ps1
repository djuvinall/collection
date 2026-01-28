function Write-SystemInventoryReport {
    <#
    .SYNOPSIS
    Outputs a system inventory report in table, JSON, or CSV format and returns the inventory object.

    .DESCRIPTION
    Generates a concise inventory report and optionally writes it to a file.

    .PARAMETER Format
    Output format for the report: Table, Json, or Csv.

    .PARAMETER OutputPath
    Optional path to write the report output. The file must not already exist.

    .PARAMETER Inventory
    Optional inventory object to format. If omitted, Get-SystemInventory is called.

    .EXAMPLE
    Write-SystemInventoryReport

    .EXAMPLE
    Write-SystemInventoryReport -Format Json -OutputPath .\inventory.json
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [ValidateSet("Table", "Json", "Csv")]
        [string]$Format = "Table",

        [string]$OutputPath,

        [pscustomobject]$Inventory
    )

    if (-not $Inventory) {
        $Inventory = Get-SystemInventory
    }

    $content = switch ($Format) {
        "Json" { $Inventory | ConvertTo-Json -Depth 4 }
        "Csv" { ($Inventory | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine }
        default { $Inventory | Format-Table -AutoSize | Out-String }
    }

    if ($OutputPath) {
        if (Test-Path -Path $OutputPath) {
            throw "OutputPath already exists: $OutputPath"
        }

        Set-Content -Path $OutputPath -Value $content -Encoding UTF8
    } else {
        Write-Host $content
    }

    return $Inventory
}
