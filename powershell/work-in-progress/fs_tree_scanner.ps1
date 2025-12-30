###My personal implementation of the Treesize scanner, for PowerShell V7
##This script collects all the items in the root directory, and then their child items and then theirs, etc. along with the size of each directory and file.

$root = "C:\"

$drives = @()
$possible_drives = @("A".."Z")

foreach ($drive in $possible_drives) {
    if (Test-Path $drive -eq $true) {
        $drive += $drives
    }
}











