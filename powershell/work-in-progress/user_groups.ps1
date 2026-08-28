function Get-UserGroups {
  param (
      [string]$username
  )

  # Remove @domain.com if user inputs email address
  if ($username -like "*@*") {
      $username = $username.Split("@")[0]
  }

  # Test that the user exists in AD
  try {
    $u = get-aduser $username
    if ($null -eq $u) {
        throw "User does not exist"
    }
  } 
  catch {
      throw "User $username does not exist in Active Directory"
  }

  # Initialize output object
  $output_Object = [PSCustomObject]@{
      Username = $username
      Groups = [PSCustomObject]@{
      }
  }

  # Build Output Object and return
  $groups = Get-ADPrincipalGroupMembership $username | Select-Object Name
  $output_Object.Groups = $groups
  return $output_Object

}
