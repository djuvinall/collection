Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$publicRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$privateRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Private'

Get-ChildItem -Path $privateRoot -Filter '*.ps1' | ForEach-Object { . $_.FullName }
Get-ChildItem -Path $publicRoot -Filter '*.ps1' | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function *-Triage*
