function Get-FileTypeCount {
    <#
    .SYNOPSIS
        Enumerates files under one or more paths and returns per-extension statistics.

    .DESCRIPTION
        Recursively (or shallowly) scans one or more directories and groups results
        by file extension. Each output object includes the extension, file count,
        aggregate size, average file size, newest and oldest LastWriteTime, and
        the percentage of total files that extension represents.

        Empty extensions (extensionless files) are reported as '<no extension>'.
        Symlinks are excluded by default to avoid double-counting on recursive scans.

    .PARAMETER Path
        One or more root paths to scan. Accepts pipeline input. Defaults to the
        current working directory if omitted.

    .PARAMETER Recurse
        When specified, scans all subdirectories. Omit for a shallow scan of the
        immediate directory only.

    .PARAMETER ExcludeExtension
        One or more extensions to exclude from results (e.g. '.tmp', '.log').
        Case-insensitive. Include the leading dot.

    .PARAMETER IncludeHidden
        When specified, includes hidden and system files in the scan.

    .PARAMETER MinCount
        Filters out any extension group with fewer than this many files.
        Useful for suppressing noise on large directory trees. Default: 1.

    .EXAMPLE
        Get-FileTypeCount -Path C:\Projects

        Shallow scan of C:\Projects, returns one object per extension found.

    .EXAMPLE
        Get-FileTypeCount -Path C:\Projects -Recurse

        Recursive scan of C:\Projects.

    .EXAMPLE
        Get-FileTypeCount -Path C:\Logs -Recurse -ExcludeExtension '.tmp', '.bak' -MinCount 5

        Recursive scan, excludes .tmp and .bak, suppresses any extension with fewer
        than 5 files.

    .EXAMPLE
        'C:\Projects', 'D:\Archive' | Get-FileTypeCount -Recurse

        Scans multiple paths via pipeline and aggregates results per path.

    .EXAMPLE
        Get-FileTypeCount -Path C:\Users -Recurse | Sort-Object TotalSizeMB -Descending | Select-Object -First 10

        Returns the top 10 extensions by total disk usage.

    .INPUTS
        System.String — path strings accepted from the pipeline.

    .OUTPUTS
        PSCustomObject with properties:
            Extension       [string]   — file extension including dot, or '<no extension>'
            FileCount       [int]      — number of files with this extension
            TotalSizeBytes  [long]     — aggregate size of all matching files in bytes
            TotalSizeMB     [double]   — aggregate size in megabytes, rounded to 2 decimal places
            AvgSizeKB       [double]   — average file size in kilobytes, rounded to 2 decimal places
            PctOfFiles      [double]   — percentage of total files in the scan this extension represents
            Newest          [datetime] — most recent LastWriteTime among matching files
            Oldest          [datetime] — oldest LastWriteTime among matching files
            ScannedPath     [string]   — the root path this result originates from

    .NOTES
        Author  : Devon
        Version : 1.0.0
        Caveats :
            - Get-ChildItem is Windows/cross-platform; no Windows-only cmdlets used here.
            - On very large trees, memory usage grows with file count. Consider -MinCount
              to filter aggressively if scanning system volumes.
            - Symlinks are skipped via -Attributes filtering to avoid double-counting.
              Set $IncludeSymlinks inside the function if you need them.
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Position          = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [string[]] $Path = @($PWD.Path),

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [string[]] $ExcludeExtension,

        [Parameter()]
        [switch] $IncludeHidden,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MinCount = 1
    )

    begin {
        # Normalize exclusions to lowercase for case-insensitive comparison
        $excludeSet = if ($ExcludeExtension) {
            [System.Collections.Generic.HashSet[string]]::new(
                ($ExcludeExtension | ForEach-Object { $_.ToLower() }),
                [System.StringComparer]::OrdinalIgnoreCase
            )
        }
        else {
            $null
        }
    }

    process {
        foreach ($scanPath in $Path) {
            Write-Verbose "Scanning: $scanPath  |  Recurse: $Recurse  |  IncludeHidden: $IncludeHidden"

            $gciParams = @{
                LiteralPath = $scanPath
                File        = $true
                Recurse     = $Recurse.IsPresent
                ErrorAction = 'Continue'   # Deliberate: skip access-denied dirs, keep scanning
            }

            if ($IncludeHidden) {
                $gciParams['Force'] = $true
            }

            # Collect files; skip symlinks to avoid double-counting in recursive scans
            try {
                $files = Get-ChildItem @gciParams |
                    Where-Object { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) }
            }
            catch {
                $PSCmdlet.WriteError($_)
                continue
            }

            if (-not $files) {
                Write-Verbose "No files found under: $scanPath"
                continue
            }

            $totalFiles = $files.Count
            Write-Verbose "Total files found: $totalFiles"

            # Group and compute per-extension stats
            $files |
                Group-Object -Property { if ($_.Extension) { $_.Extension.ToLower() } else { '<no extension>' } } |
                Where-Object {
                    $name = $_.Name
                    (-not $excludeSet -or -not $excludeSet.Contains($name)) -and
                    $_.Count -ge $MinCount
                } |
                ForEach-Object {
                    $group      = $_
                    $sizes      = $group.Group | ForEach-Object { $_.Length }
                    $totalBytes = ($sizes | Measure-Object -Sum).Sum
                    $dates      = $group.Group | ForEach-Object { $_.LastWriteTime }

                    [PSCustomObject]@{
                        Extension      = $group.Name
                        FileCount      = $group.Count
                        TotalSizeBytes = [long] $totalBytes
                        TotalSizeMB    = [Math]::Round($totalBytes / 1MB, 2)
                        AvgSizeKB      = [Math]::Round(($totalBytes / $group.Count) / 1KB, 2)
                        PctOfFiles     = [Math]::Round(($group.Count / $totalFiles) * 100, 2)
                        Newest         = ($dates | Measure-Object -Maximum).Maximum
                        Oldest         = ($dates | Measure-Object -Minimum).Minimum
                        ScannedPath    = $scanPath
                    }
                } |
                Sort-Object -Property FileCount -Descending
        }
    }

    end {}
}