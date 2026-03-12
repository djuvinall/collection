function Get-CompoundedValue {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [decimal]$Principal,

    [Parameter(Mandatory)]
    [decimal]$Rate,   # e.g. 0.05 for 5%

    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Period
  )

  $factor = [decimal][math]::Pow([double](1 + $Rate), $Period)
  $Principal * $factor
}