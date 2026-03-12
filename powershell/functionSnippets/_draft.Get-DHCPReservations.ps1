Get-DhcpServerv4Scope |
  ForEach-Object { Get-DhcpServerv4Reservation -ScopeId $_.ScopeId } |
  Select-Object ScopeId,IPAddress,ClientId,Name,Description,Type
