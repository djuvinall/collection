function ConvertTo-StableJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()]$InputObject,
        [int]$Depth = 10
    )

    # Convert to JSON with compressed layout while preserving ordered properties.
    return ($InputObject | ConvertTo-Json -Depth $Depth -Compress)
}
