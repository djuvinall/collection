[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'PSTriageKit.psd1'
Import-Module $modulePath -Force

Invoke-TriageCollection @PSBoundParameters
