function Get-UpperCase {
    <#
    .SYNOPSIS
        Converts one or more strings to uppercase.

    .DESCRIPTION
        Accepts string input directly or from the pipeline and returns each
        string converted to uppercase. Supports batch processing via pipeline.

    .PARAMETER Text
        The string value to convert to uppercase. Accepts pipeline input
        directly or by property name.

    .INPUTS
        System.String. Pipe strings directly or via a matching property name.

    .OUTPUTS
        System.String. One uppercase string per input value.

    .EXAMPLE
        Get-UpperCase -Text "hello world"

        Returns: HELLO WORLD

    .EXAMPLE
        "apple", "banana", "cherry" | Get-UpperCase

        Returns: APPLE, BANANA, CHERRY (one per line)

    .EXAMPLE
        @(
            [PSCustomObject]@{ Text = "john" }
            [PSCustomObject]@{ Text = "mary" }
        ) | Get-UpperCase

        Binds via ValueFromPipelineByPropertyName. Returns: JOHN, MARY

    .NOTES
        Author  : Devon
        Version : 1.0.0
        Requires: PowerShell 5.1+
        Notes   : ToUpper() uses the current culture. For culture-invariant
                  behavior, substitute $Text.ToUpperInvariant().
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Text
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand)] Begin — pipeline processing started."
    }

    process {
        try {
            Write-Verbose "[$($MyInvocation.MyCommand)] Processing: '$Text'"
            $Text.ToUpper()
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand)] End — pipeline processing complete."
    }
}
