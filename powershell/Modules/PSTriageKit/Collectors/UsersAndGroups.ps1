[CmdletBinding()]
param(
    [int]$SinceHours = 24
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 24
    )

    $users = Get-LocalUser | Select-Object Name, Enabled, LastLogon
    $admins = @()
    try {
        $admins = Get-LocalGroupMember -Group 'Administrators' | Select-Object Name, ObjectClass, PrincipalSource
    }
    catch {}
    [pscustomobject]@{
        Users = $users
        Administrators = $admins
    }
}

Invoke-Collector -SinceHours $SinceHours
