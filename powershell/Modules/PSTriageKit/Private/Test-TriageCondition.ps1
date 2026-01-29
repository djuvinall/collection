function Test-TriageCondition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Condition,
        [Parameter(Mandatory)]
        $Object
    )

    $value = $Object.$($Condition.Field)
    switch ($Condition.Operator) {
        '='  { return ($value -eq $Condition.Value) }
        '!=' { return ($value -ne $Condition.Value) }
        '~'  {
            if (-not $value) { return $false }
            return ($value.ToString() -like "*$($Condition.Value)*")
        }
        'in' {
            return ($Condition.Value -contains $value)
        }
        default { return $false }
    }
}
