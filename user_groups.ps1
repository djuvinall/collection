$username = Read-Host "Username without domain (i.e. 'jdoe')"

$output_path = "C:\temp\user_groups\{0}_groups.txt" -f $username

$path_exists = Test-Path "C:\temp\user_groups"

#Create target directory if it does not already exist
if ($path_exists -eq $false) {
    mkdir "C:\temp\user_groups"
}

#Test is user exists, if not, displays a message that the wrong username was typed and re-runs the script
try {
get-aduser $username
}
catch {
Write-Host "User does not exist, Please verify Username and try agian"
Invoke-Expression -Command ($PSCommandPath)
}

Get-ADPrincipalGroupMembership $username | Select-Object name > $output_path
Write-host "$username groups sucessgully printed to file"
Break