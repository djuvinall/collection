function New-TriageProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string[]]$Collectors,
        [string[]]$Exclude,
        [string]$Path
    )

    if (-not $Path) {
        $profileDir = Join-Path -Path $PSScriptRoot -ChildPath '..\Profiles'
        if (-not (Test-Path -Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        $Path = Join-Path -Path $profileDir -ChildPath "$Name.json"
    }

    $obj = [ordered]@{
        name       = $Name
        collectors = $Collectors
        exclude    = $Exclude
    }
    $json = $obj | ConvertTo-Json -Depth 4 -Compress
    Set-Content -Path $Path -Value $json
    return Get-Item -Path $Path
}
