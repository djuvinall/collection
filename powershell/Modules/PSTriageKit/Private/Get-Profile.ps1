function Get-ProfileConfig {
    [CmdletBinding()]
    param(
        [string]$Profile = 'default'
    )

    $profilePath = $Profile
    if (-not (Test-Path -Path $profilePath)) {
        $profileDir = Join-Path -Path $PSScriptRoot -ChildPath '..\Profiles'
        $profilePath = Join-Path -Path $profileDir -ChildPath "$Profile.json"
    }
    if (-not (Test-Path -Path $profilePath)) {
        return [pscustomobject]@{
            Name = 'default'
            Collectors = @()
            Exclude = @()
        }
    }
    $content = Get-Content -Path $profilePath -Raw
    $obj = $content | ConvertFrom-Json
    return [pscustomobject]@{
        Name = $obj.name
        Collectors = $obj.collectors
        Exclude = $obj.exclude
    }
}
