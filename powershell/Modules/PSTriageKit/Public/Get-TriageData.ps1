function Get-TriageData {
    [CmdletBinding(DefaultParameterSetName = 'Collection')]
    param(
        [Parameter(ParameterSetName = 'Collection', Mandatory)]
        $Collection,
        [Parameter(ParameterSetName = 'Path', Mandatory)]
        [string]$Path,
        [string]$Collector,
        [switch]$All,
        [Security.SecureString]$Password,
        [switch]$AsHashtable
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $Collection = Get-TriageCollection -Path $Path
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Collection' -and -not $Collection.Files -and $Collection.Path) {
        $Collection = Get-TriageCollection -Path $Collection.Path
    }

    $ptkFiles = $Collection.Files
    if (-not $All -and $Collector) {
        $ptkFiles = $ptkFiles | Where-Object { $_.BaseName -ieq $Collector }
    }

    $result = @{}
    foreach ($file in $ptkFiles) {
        $pkg = Read-PtkPackage -Path $file.FullName -Password $Password
        $name = if ($pkg.Header.collector) { $pkg.Header.collector } else { $file.BaseName }
        $result[$name] = $pkg.Data
    }

    if ($AsHashtable) { return $result }
    return $result.Values
}
