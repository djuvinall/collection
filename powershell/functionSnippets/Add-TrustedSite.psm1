function Add-TrustedSite {
    param(
        [Parameter(Mandatory)]
        [string]$DomainOrPath,

        [ValidateSet('Trusted','Intranet','Internet','Restricted')]
        [string]$Zone = 'Trusted',

        [switch]$IsFilePath  # for file:// or UNC-like paths
    )

    $zoneMap = @{
        Trusted   = 2
        Intranet  = 1
        Internet  = 3
        Restricted= 4
    }[$Zone]

    if ($IsFilePath) {
        $rangeKeyRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Ranges"

        if (-not (Test-Path $rangeKeyRoot)) {
            New-Item -Path $rangeKeyRoot -Force | Out-Null
        }

        # Autoselect next RangeX name
        $existing = Get-ChildItem $rangeKeyRoot -Name -ErrorAction SilentlyContinue |
                    Where-Object { $_ -like 'Range*' }
        if ($existing) {
            $numbers = $existing | ForEach-Object { ($_ -replace 'Range','') -as [int] } | Where-Object { $_ -gt 0 }
            $next = ($numbers | Sort-Object | Select-Object -Last 1) + 1
        } else {
            $next = 1
        }

        $rangeName = "Range$next"
        $rangePath = Join-Path $rangeKeyRoot $rangeName

        New-Item -Path $rangePath -Force | Out-Null

        # Normalize path into a file:// URL-like format
        $value = if ($DomainOrPath -like "file://*") {
            $DomainOrPath
        } else {
            "file://$DomainOrPath"
        }

        New-ItemProperty -Path $rangePath -Name ":Range" -Value $value      -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $rangePath -Name "file"   -Value $zoneMap    -PropertyType DWord  -Force | Out-Null
    }
    else {
        # Domain-based entry (contoso.com, subdomain.contoso.com, etc.)
        $domain = $DomainOrPath
        $path   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\$domain"

        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        New-ItemProperty -Path $path -Name "*" -Value $zoneMap -PropertyType DWord -Force | Out-Null
    }
}

Export-ModuleMember -Function Add-TrustedSite   
