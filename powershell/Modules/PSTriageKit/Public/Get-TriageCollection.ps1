function Get-TriageCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ExtractPath
    )

    $root = Get-CollectionPath -Path $Path -ExtractPath $ExtractPath
    $indexPath = Join-Path -Path $root -ChildPath 'index.json'
    if (-not (Test-Path -Path $indexPath)) {
        throw 'index.json not found in collection.'
    }
    $index = Get-Content -Path $indexPath -Raw | ConvertFrom-Json
    $collectorFolder = Join-Path -Path $root -ChildPath 'Collectors'
    $files = if (Test-Path $collectorFolder) { Get-ChildItem -Path $collectorFolder -Filter '*.ptk' } else { @() }

    return [pscustomobject]@{
        Path      = $root
        Index     = $index
        Files     = $files
        Protect   = $index.protect
        ZipSource = if (Test-Path -Path $Path -PathType Leaf) { $Path } else { $null }
    }
}
