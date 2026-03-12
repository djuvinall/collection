#Tools to assist with and use symbolic links in windows#



function Move-SymbolicTarget {
    # Moves the specified $source to the $target parent folder and creates a symbolic link in the old location, pointing to the new
    [cmdletbinding(SupportsShouldProcess)]
	#root = An optional variable for the path where the source and target variables split.
	#source = The file that will be moved and replaced with a symbolic link referencing it's moved location
	#target = The directory you would like to move the Source file/folder to, with the symbolic link referencing this file.
    param (
        [parameter(Mandatory=$false)][string]$root,
        [parameter(Mandatory=$true)][string]$source,
        [parameter(Mandatory=$true)][string]$target
    )

    if ($root -ne "") {
        $source = Join-Path $root $source
        $target = Join-Path $root $target
    } else {
        $source = "$($source)"
        $target = "$($target)"
    }

    Move-Item -Path $source -Destination $target
    
    $target =  "$($target)/$(Split-Path $source -Leaf)"

    New-Item -ItemType SymbolicLink -Path $source -Target $target

}

Export-ModuleMember -Function Move-SymbolicTarget