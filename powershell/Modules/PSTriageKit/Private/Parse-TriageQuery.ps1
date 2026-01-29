function Parse-TriageQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query
    )

    $collectorFilter = @()
    $whereText = $null
    $select = @()

    $parts = $Query -split '\|'
    $main = $parts[0].Trim()
    if ($parts.Count -gt 1) {
        $selectPart = $parts[1].Trim()
        if ($selectPart -match '(?i)^Select\s+(.+)$') {
            $select = $Matches[1].Split(',').Trim()
        }
    }

    if ($main -match '(?i)^Collector=(?<c>[^\s]+)\s+Where\s+(?<w>.+)$') {
        $collectorFilter = @($Matches['c'])
        $whereText = $Matches['w']
    }
    elseif ($main -match '(?i)^Where\s+(?<w>.+)$') {
        $whereText = $Matches['w']
    }
    elseif ($main -match '(?i)^Collector=(?<c>[^\s]+)$') {
        $collectorFilter = @($Matches['c'])
    }

    $conditions = @()
    if ($whereText) {
        $tokens = $whereText -split '(?i)\s+and\s+'
        foreach ($token in $tokens) {
            $token = $token.Trim()
            if ($token -match '^(?<f>\w+)\s*(?<op>=|!=|~|in)\s*(?<v>.+)$') {
                $field = $Matches['f']
                $op = $Matches['op']
                $val = $Matches['v'].Trim()
                if ($op -eq 'in') {
                    if ($val -match '^\((.+)\)$') {
                        $inner = $Matches[1]
                        $vals = $inner.Split(',') | ForEach-Object { $_.Trim().Trim('"') }
                        $conditions += [pscustomobject]@{ Field = $field; Operator = 'in'; Value = $vals }
                    }
                    else { throw 'Invalid in() syntax.' }
                }
                else {
                    $val = $val.Trim('"')
                    $conditions += [pscustomobject]@{ Field = $field; Operator = $op; Value = $val }
                }
            }
            else {
                throw "Invalid condition: $token"
            }
        }
    }

    return [pscustomobject]@{
        Collectors = $collectorFilter
        Conditions = $conditions
        Select     = $select
    }
}
