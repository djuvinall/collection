<#
.SYNOPSIS
Searches collected triage data using a lightweight query syntax.

.DESCRIPTION
Loads PTK collector outputs, filters them with the provided query, and returns matching items for downstream analysis. Use Collector filters to target specific collector names.

.EXAMPLE
Find-TriageData -Path '.\bundle' -Query "Collector=HardwareInventory Where Gpu.Name~NVIDIA Select Gpu"

.EXAMPLE
Find-TriageData -Path '.\bundle' -Query "Collector=EventLogs Where Level=Error Select LogName,Id,Message"
#>
function Find-TriageData {
    [CmdletBinding(DefaultParameterSetName = 'Collection')]
    param(
        [Parameter(ParameterSetName = 'Collection')]
        $Collection,
        [Parameter(ParameterSetName = 'Path')]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Query,
        [string[]]$Collector,
        [Security.SecureString]$Password,
        [int]$Limit = 200,
        [switch]$IncludeRaw
    )

    if (-not $Collection) {
        $Collection = Get-TriageCollection -Path $Path
    }

    $parsed = Parse-TriageQuery -Query $Query
    $collectorFilter = @()
    if ($Collector) { $collectorFilter += $Collector }
    if ($parsed.Collectors) { $collectorFilter += $parsed.Collectors }
    $collectorFilter = $collectorFilter | ForEach-Object { $_.ToString().ToLowerInvariant() }

    $data = Get-TriageData -Collection $Collection -All -Password $Password -AsHashtable
    if ($data -isnot [hashtable]) {
        $data = @{ Default = $data }
    }
    $matches = @()
    foreach ($key in $data.Keys) {
        $keyName = $key.ToString().ToLowerInvariant()
        if ($collectorFilter -and ($keyName -notin $collectorFilter)) { continue }
        $items = $data[$key]
        if ($items -isnot [System.Collections.IEnumerable]) { $items = @($items) }
        foreach ($item in $items) {
            $ok = $true
            foreach ($cond in $parsed.Conditions) {
                if (-not (Test-TriageCondition -Condition $cond -Object $item)) { $ok = $false; break }
            }
            if (-not $ok) { continue }
            $match = $item
            if ($parsed.Select.Count -gt 0) {
                $match = $item | Select-Object -Property $parsed.Select
            }
            $out = [pscustomobject]@{
                Collector = $key
                Path      = $item.PSObject.Properties.Name -join '.'
                Match     = $match
            }
            if ($IncludeRaw) { $out | Add-Member -MemberType NoteProperty -Name Raw -Value $item }
            $matches += $out
            if ($matches.Count -ge $Limit) { break }
        }
        if ($matches.Count -ge $Limit) { break }
    }
    return ,$matches
}
