function Get-SearchMsUncPath {
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string]$SearchMsUri
  )
  $rest = ($SearchMsUri -replace '^[^:]+:','').TrimStart('?')  # drop "search-ms:"
  $m = [regex]::Match($rest, '(?:^|&)crumb=([^&]+)')
  if (-not $m.Success) { return $null }
  $encoded = $m.Groups[1].Value -replace '\+',' '              # just in case + is used for spaces
  $crumb = [uri]::UnescapeDataString($encoded)
  if ($crumb -like 'location:*') { $crumb.Substring('location:'.Length) } else { $crumb }
}

Export-ModuleMember -function Get-SearchMsUncPath
