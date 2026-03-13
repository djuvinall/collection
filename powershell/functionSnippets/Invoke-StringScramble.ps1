function Invoke-StringScramble {
    <#
    .SYNOPSIS
        Scrambles the characters of a string, with optional character exclusions.

    .DESCRIPTION
        Takes an input string and returns a new string with the same characters
        in a randomized order. Characters specified in the ExcludeCharacters
        parameter are pinned to their original positions and excluded from the
        shuffle pool.

    .PARAMETER InputString
        The string to scramble.

    .PARAMETER ExcludeCharacters
        One or more characters to pin in place. These characters will remain at
        their original index positions and will not participate in the shuffle.

    .PARAMETER Seed
        Optional integer seed for the random number generator. Use this for
        reproducible output during testing.

    .EXAMPLE
        Invoke-StringScramble -InputString 'HelloWorld'

        Returns 'HelloWorld' with all characters shuffled randomly.

    .EXAMPLE
        Invoke-StringScramble -InputString '(800) 555-1234' -ExcludeCharacters '(', ')', '-', ' '

        Shuffles only the digit characters; punctuation and spaces remain in place.

    .EXAMPLE
        'MyPassword123' | Invoke-StringScramble

        Accepts pipeline input and scrambles the full string.

    .EXAMPLE
        Invoke-StringScramble -InputString 'Reproducible' -Seed 42

        Returns a deterministic scramble using seed 42.

    .INPUTS
        System.String — accepts pipeline input for InputString.

    .OUTPUTS
        System.String — the scrambled string.

    .NOTES
        Author:  Senior PS Engineer
        Version: 1.0.0
        Uses Fisher-Yates shuffle on the mutable character pool.
        ExcludeCharacters matching is case-sensitive and character-exact.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $InputString,

        [Parameter()]
        [char[]] $ExcludeCharacters = @(),

        [Parameter()]
        [Nullable[int]] $Seed = $null
    )

    process {
        $rng = $Seed -ne $null ? [System.Random]::new($Seed) : [System.Random]::new()

        # Build the output buffer as a char array mirroring the input
        $result = $InputString.ToCharArray()

        # Collect indices that are free to shuffle (not excluded)
        $freeIndices = [System.Collections.Generic.List[int]]::new()
        for ($i = 0; $i -lt $result.Length; $i++) {
            if ($result[$i] -notin $ExcludeCharacters) {
                $freeIndices.Add($i)
            }
        }

        # Extract the pool of shuffleable characters
        $pool = $freeIndices | ForEach-Object { $result[$_] }

        # Fisher-Yates shuffle on the pool
        $poolArray = @($pool)
        for ($i = $poolArray.Count - 1; $i -gt 0; $i--) {
            $j = $rng.Next($i + 1)
            $poolArray[$i], $poolArray[$j] = $poolArray[$j], $poolArray[$i]
        }

        # Write shuffled characters back into the free index positions
        for ($i = 0; $i -lt $freeIndices.Count; $i++) {
            $result[$freeIndices[$i]] = $poolArray[$i]
        }

        return -join $result
    }
}
