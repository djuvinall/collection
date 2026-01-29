function Export-TriageData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Collection,
        [string]$Collector,
        [Parameter(Mandatory)]
        [string]$Path,
        [ValidateSet('Json','Csv')]
        [string]$Format = 'Json',
        [Security.SecureString]$Password
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    $data = Get-TriageData -Collection $Collection -Collector $Collector -All:(!$Collector) -Password $Password -AsHashtable

    foreach ($key in $data.Keys) {
        $value = $data[$key]
        $outFile = Join-Path -Path $Path -ChildPath "$key.$($Format.ToLower())"
        switch ($Format) {
            'Json' { $value | ConvertTo-Json -Depth 20 | Set-Content -Path $outFile }
            'Csv'  { $value | Export-Csv -Path $outFile -NoTypeInformation }
        }
    }
    return Get-ChildItem -Path $Path
}
