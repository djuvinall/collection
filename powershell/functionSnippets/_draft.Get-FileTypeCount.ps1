# Will show how many of each file type exists at $path
$path | Get-ChildItem -Recurse |
    Group-Object -Property Extension -NoElement |
    Sort-Object -Property Count -Descending
