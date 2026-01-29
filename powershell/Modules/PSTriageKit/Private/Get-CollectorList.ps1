function Get-CollectorList {
    [CmdletBinding()]
    param(
        [string[]]$Include,
        [string[]]$Exclude
    )

    $collectorPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Collectors'
    $files = Get-ChildItem -Path $collectorPath -Filter '*.ps1' -File | Sort-Object Name
    $collectors = @()
    foreach ($file in $files) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($Include -and ($name -notin $Include)) { continue }
        if ($Exclude -and ($name -in $Exclude)) { continue }
        $collectors += [pscustomobject]@{
            Name = $name
            Path = $file.FullName
        }
    }
    return $collectors
}
