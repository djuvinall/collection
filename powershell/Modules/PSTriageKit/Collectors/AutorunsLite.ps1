[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    $runKeys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $items = foreach ($key in $runKeys) {
        try {
            Get-ItemProperty -Path $key | Select-Object PSPath, * -ExcludeProperty PS* | ForEach-Object {
                $_.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                    [pscustomobject]@{
                        Source = $key
                        Name   = $_.Name
                        Value  = $_.Value
                    }
                }
            }
        }
        catch { @() }
    }
    $startup = @()
    foreach ($dir in @($env:ProgramData, $env:AppData)) {
        $path = Join-Path -Path $dir -ChildPath 'Microsoft\Windows\Start Menu\Programs\Startup'
        if (Test-Path -Path $path) {
            $startup += Get-ChildItem -Path $path -File | Select-Object FullName, Name
        }
    }
    [pscustomobject]@{
        RunKeys = $items
        StartupFolder = $startup
    }
}

Invoke-Collector -SinceHours $SinceHours
