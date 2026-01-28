$publicPath = Join-Path -Path $PSScriptRoot -ChildPath "Public"
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath "Private"

foreach ($file in Get-ChildItem -Path $publicPath -Filter "*.ps1" -ErrorAction SilentlyContinue) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path $privatePath -Filter "*.ps1" -ErrorAction SilentlyContinue) {
    . $file.FullName
}

Export-ModuleMember -Function (Get-ChildItem -Path $publicPath -Filter "*.ps1").BaseName
