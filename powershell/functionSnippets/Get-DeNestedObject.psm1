function Get-DeNestedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject,

        [int]$Depth = 0
    )

    process {
        if ($InputObject -is [string]) {
            $InputObject = $InputObject | ConvertFrom-Json
        }

        $indent = "  " * $Depth
        $properties = $InputObject | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

        # Alignment for this level
        $maxLen = ($properties | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

        foreach ($prop in $properties) {
            $value = $InputObject.$prop
            $childProps = $value | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue

            if ($null -ne $childProps) {
                # Check if this is a "pivoted" object (all properties are arrays of equal length)
                $childNames = $childProps | Select-Object -ExpandProperty Name
                $lengths = $childNames | ForEach-Object { @($value.$_).Count }
                $allEqual = ($lengths | Select-Object -Unique).Count -eq 1
                $firstLen = @($value.($childNames[0])).Count

                if ($allEqual -and $firstLen -gt 1) {
                    # Pivoted array-of-objects — reconstruct individual objects
                    Write-Host "$indent$($prop.ToUpper())" -ForegroundColor Yellow
                    for ($i = 0; $i -lt $firstLen; $i++) {
                        $rebuilt = [PSCustomObject]@{}
                        foreach ($cn in $childNames) {
                            $rebuilt | Add-Member -NotePropertyName $cn -NotePropertyValue @($value.$cn)[$i]
                        }
                        Get-DeNestedObject -InputObject $rebuilt -Depth ($Depth + 1)
                        Write-Host ""
                    }
                }
                else {
                    # Regular nested object
                    Write-Host "$indent$($prop.ToUpper())" -ForegroundColor Yellow
                    Get-DeNestedObject -InputObject $value -Depth ($Depth + 1)
                }
            }
            elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                $firstItem = $value | Select-Object -First 1
                $itemProps = $firstItem | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue

                if ($null -ne $itemProps) {
                    Write-Host "$indent$($prop.ToUpper())" -ForegroundColor Yellow
                    foreach ($item in $value) {
                        Get-DeNestedObject -InputObject $item -Depth ($Depth + 1)
                        Write-Host ""
                    }
                }
                else {
                    $padded = $prop.PadRight($maxLen)
                    Write-Host "$indent$padded : $($value -join ', ')"
                }
            }
            else {
                $padded = $prop.PadRight($maxLen)
                Write-Host "$indent$padded : $value"
            }
        }
    }
}

Export-ModuleMember -Function Get-DeNestedObject
