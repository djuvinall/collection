# PSTriageKit Module Manifest
@{
    RootModule        = 'PSTriageKit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'c3c45b35-5c1b-4b9f-8b31-4ab5e1b17d6f'
    Author            = 'PSTriageKit'
    CompanyName       = 'PSTriageKit'
    Copyright         = '(c) PSTriageKit. All rights reserved.'
    PowerShellVersion = '5.1'
    Description       = 'Incident-response triage collector with protected PTK bundles and query tools.'
    FunctionsToExport = @(
        'Invoke-TriageCollection',
        'Get-TriageCollection',
        'Get-TriageData',
        'Export-TriageData',
        'Show-TriageSummary',
        'Find-TriageData',
        'Get-TriageCollector',
        'Test-TriagePrereq',
        'New-TriageProfile'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('triage', 'incident-response', 'ptk')
            LicenseUri = ''
            ProjectUri = ''
        }
    }
}
