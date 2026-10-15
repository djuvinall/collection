function Confirm-Action {
    [CmdletBinding()]
    param (
        [string]$Message = "Press ENTER to proceed or ESC to cancel..."
    )

    Write-Host $Message

    while ($true) {
        # Intercept a single keystroke without displaying it
        $keyInfo = [System.Console]::ReadKey($true)
        
        if ($keyInfo.Key -eq 'Enter') {
            return $true
        }
        if ($keyInfo.Key -eq 'Escape') {
            return $false
        }
    }
}
