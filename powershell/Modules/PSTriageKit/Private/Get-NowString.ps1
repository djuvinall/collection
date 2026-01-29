function Get-NowString {
    [CmdletBinding()]
    param()

    return (Get-Date).ToString('yyyyMMdd-HHmmss')
}
