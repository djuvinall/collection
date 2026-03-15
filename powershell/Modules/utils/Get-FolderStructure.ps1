function Get-FolderStructure {
  <#
  .SYNOPSIS
  Outputs a tree-style view of the folder structure for a specified directory.
  
  .DESCRIPTION
  Get-FolderStructure displays the directory structure of a given path using
  tree-style formatting characters. By default, only subdirectories are shown.
  If -IncludeFiles is specified, files are included in the output as well.
  
  .PARAMETER Path
  The root directory to scan and display.
  
  .PARAMETER IncludeFiles
  Includes files in the output in addition to folders.
  
  .EXAMPLE
  Get-FolderStructure -Path "C:\Projects\MyFolder"
  
  Displays the folder structure for C:\Projects\MyFolder, showing folders only.
  
  .EXAMPLE
  Get-FolderStructure -Path "C:\Projects\MyFolder" -IncludeFiles
  
  Displays the folder structure for C:\Projects\MyFolder, including both folders and files.
  
  .NOTES
  The function validates that the provided path exists and is a directory before
  processing. Output is written as formatted text suitable for console display
  or redirection to a text file.
  #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [switch]$IncludeFiles
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path does not exist: $Path"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $rootItem = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop

    if (-not $rootItem.PSIsContainer) {
        throw "Path is not a directory: $resolvedPath"
    }

    function Write-Tree {
        param(
            [Parameter(Mandatory)]
            [string]$CurrentPath,

            [string]$Prefix = ""
        )

        $items = Get-ChildItem -LiteralPath $CurrentPath -Force |
            Where-Object {
                if ($IncludeFiles) {
                    $true
                }
                else {
                    $_.PSIsContainer
                }
            } |
            Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name

        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $isLast = ($i -eq $items.Count - 1)

            $branch = if ($isLast) { "└── " } else { "├── " }
            $nextPrefix = if ($isLast) { "$Prefix    " } else { "$Prefix│   " }

            $name = if ($item.PSIsContainer) { "$($item.Name)\" } else { $item.Name }
            "$Prefix$branch$name"

            if ($item.PSIsContainer) {
                Write-Tree -CurrentPath $item.FullName -Prefix $nextPrefix
            }
        }
    }

    "$($rootItem.FullName)\"
    Write-Tree -CurrentPath $rootItem.FullName
}