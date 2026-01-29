function Get-CollectionPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ExtractPath
    )

    if (Test-Path -Path $Path -PathType Container) {
        return $Path
    }

    if ([System.IO.Path]::GetExtension($Path) -ieq '.zip') {
        $target = $ExtractPath
        if (-not $target) {
            $target = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($Path) + '-' + (Get-NowString))
        }
        if (-not (Test-Path -Path $target)) {
            New-Item -ItemType Directory -Path $target | Out-Null
        }
        Expand-Archive -Path $Path -DestinationPath $target -Force
        return $target
    }

    throw 'Path must be a folder or zip file.'
}
