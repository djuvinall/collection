$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSTriageKit.psd1'
Import-Module $modulePath -Force
$privateRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\Private'
Get-ChildItem -Path $privateRoot -Filter '*.ps1' | ForEach-Object { . $_.FullName }

Describe 'PTK package roundtrip' {
    It 'roundtrips compress package' {
        $temp = Join-Path -Path $TestDrive -ChildPath 'sample.ptk'
        $obj = [pscustomobject]@{ Name = 'Test'; Value = 1 }
        Write-PtkPackage -Collector 'Test' -Data $obj -OutputPath $temp -Protect 'Compress' | Out-Null
        $read = Read-PtkPackage -Path $temp
        $read.Data.Name | Should Be 'Test'
    }

    It 'fails with wrong password' {
        $temp = Join-Path -Path $TestDrive -ChildPath 'sample2.ptk'
        $pw = New-Object System.Security.SecureString
        'secret'.ToCharArray() | ForEach-Object { $pw.AppendChar($_) }
        $pw.MakeReadOnly()
        $bad = New-Object System.Security.SecureString
        'bad'.ToCharArray() | ForEach-Object { $bad.AppendChar($_) }
        $bad.MakeReadOnly()
        $obj = [pscustomobject]@{ Name = 'Secret' }
        Write-PtkPackage -Collector 'Test' -Data $obj -OutputPath $temp -Protect 'Password' -Password $pw | Out-Null
        { Read-PtkPackage -Path $temp -Password $bad } | Should Throw
    }
}

Describe 'Invoke-TriageCollection' {
    It 'creates bundle with index and hashes' {
        $out = Join-Path -Path $TestDrive -ChildPath 'bundle'
        $result = Invoke-TriageCollection -OutputPath $out -Protect Compress -Force
        (Test-Path (Join-Path $out 'index.json')) | Should Be $true
        (Test-Path (Join-Path $out 'hashes.sha256')) | Should Be $true
    }
}

Describe 'Find-TriageData' {
    It 'matches simple query' {
        $data = @([pscustomobject]@{ Name = 'powershell'; Id = 1 }, [pscustomobject]@{ Name = 'cmd'; Id = 2 })
        $ptk = Join-Path $TestDrive 'proc.ptk'
        Write-PtkPackage -Collector 'Processes' -Data $data -Protect Compress -OutputPath $ptk | Out-Null
        $collection = [pscustomobject]@{
            Files = @(Get-Item $ptk)
            Index = @{ protect = 'Compress' }
            Path  = '.'
        }

        $matches = Find-TriageData -Collection $collection -Query 'Collector=Processes Where Name~powershell'
        $matches.Count | Should Be 1
        $matches[0].Collector | Should Be 'Processes'
    }
}

Describe 'EventLogs collector' {
    It 'honors window and records skip reason when not admin' {
        $now = Get-Date
        Mock -CommandName Test-IsAdmin { $false }
        Mock -CommandName Get-WinEvent -ParameterFilter { $FilterHashtable.LogName -eq 'System' } {
            @([pscustomobject]@{ LogName = 'System'; Id = 1; LevelDisplayName = 'Error'; ProviderName = 'Test'; TimeCreated = $now; Message = 'failure' })
        }
        Mock -CommandName Get-WinEvent -ParameterFilter { $FilterHashtable.LogName -eq 'Application' } {
            @([pscustomobject]@{ LogName = 'Application'; Id = 2; LevelDisplayName = 'Warning'; ProviderName = 'Test'; TimeCreated = $now; Message = 'warn' })
        }

        . (Join-Path -Path $PSScriptRoot -ChildPath '..\Collectors\EventLogs.ps1')
        $result = Invoke-Collector -SinceHours 1
        Remove-Item Function:\Invoke-Collector -ErrorAction SilentlyContinue

        @($result | Where-Object { $_.LogName -eq 'System' }).Count | Should Be 1
        (@($result | Where-Object { $_.LogName -eq 'Security' }).SkipReason) | Should Not BeNullOrEmpty
    }
}

Describe 'HardwareInventory collector' {
    It 'returns key properties even when data is sparse' {
        Mock -CommandName Get-CimInstance { @() }
        Mock -CommandName Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_Processor' } {
            @([pscustomobject]@{ Name = 'CPU-X'; Manufacturer = 'Contoso'; NumberOfCores = 4; NumberOfLogicalProcessors = 8; MaxClockSpeed = 3200 })
        }
        Mock -CommandName Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_VideoController' } {
            @([pscustomobject]@{ Name = 'GPU-Y'; AdapterRAM = 4096; DriverVersion = '1.0.0'; DriverDate = (Get-Date) })
        }
        Mock -CommandName Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_DiskDrive' } {
            @([pscustomobject]@{ Model = 'DiskZ'; Size = 1000000000; SerialNumber = '123'; MediaType = 'SSD'; InterfaceType = 'NVMe' })
        }
        Mock -CommandName Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_NetworkAdapter' -and $Filter -like 'PhysicalAdapter*' } {
            @([pscustomobject]@{ Name = 'NIC1'; Manufacturer = 'Fabrikam'; MACAddress = '00-11-22-33-44-55'; Speed = 1000000000; AdapterType = 'Ethernet' })
        }
        Mock -CommandName Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_PnPSignedDriver' } {
            @([pscustomobject]@{ DeviceName = 'Input Driver'; DriverVersion = '2.0'; DriverDate = (Get-Date); Manufacturer = 'Fabrikam'; DriverProviderName = 'Fabrikam'; DeviceID = 'DEV_1' })
        }
        Mock -CommandName Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_PnPEntity' } {
            @([pscustomobject]@{ Name = 'USB Device'; Manufacturer = 'Fabrikam'; PNPClass = 'USB'; DeviceID = 'DEV_1' })
        }

        . (Join-Path -Path $PSScriptRoot -ChildPath '..\Collectors\HardwareInventory.ps1')
        $result = Invoke-Collector
        Remove-Item Function:\Invoke-Collector -ErrorAction SilentlyContinue

        $result.Cpu[0].Name | Should Be 'CPU-X'
        $result.Gpu[0].Name | Should Be 'GPU-Y'
        $result.Disks.Count | Should BeGreaterThan 0
        $result.NetworkAdapters.Count | Should BeGreaterThan 0
        $result.Peripherals.Count | Should BeGreaterThan 0
    }
}

Describe 'Collector registration' {
    It 'runs HardwareInventory when not excluded' {
        $out = Join-Path -Path $TestDrive -ChildPath 'bundle-hw'
        $result = Invoke-TriageCollection -OutputPath $out -Protect Compress -Force -Collectors @('HardwareInventory')
        @($result.Collectors | Where-Object { $_.Name -eq 'HardwareInventory' }).Count | Should Be 1
    }
}

Describe 'Show-TriageSummary' {
    It 'surfaces hardware and event highlights' {
        Mock -CommandName Get-TriageData -ModuleName PSTriageKit {
            return @{
                SystemInfo       = [pscustomobject]@{ OS = 'Windows Test'; Version = '10.0'; Build = '9999'; Uptime = '1:00:00' }
                UsersAndGroups   = [pscustomobject]@{ Users = @(1,2,3); Administrators = @(1) }
                Services         = @(1,2,3,4)
                Processes        = @(1,2,3)
                DefenderStatus   = @([pscustomobject]@{ RealTimeProtectionEnabled = $true })
                EventLogs        = @([pscustomobject]@{ LogName = 'System'; Id = 42; Level = 'Error'; ProviderName = 'Test'; TimeCreated = (Get-Date); Message = 'bad' })
                HardwareInventory = [pscustomobject]@{
                    Cpu                = @([pscustomobject]@{ Name = 'CPU-X' })
                    Gpu                = @([pscustomobject]@{ Name = 'GPU-Y' })
                    Motherboard        = @()
                    Bios               = @()
                    Memory             = [pscustomobject]@{ TotalBytes = 0; Modules = @() }
                    Disks              = @([pscustomobject]@{ Model = 'DiskZ'; SizeBytes = 1000000000; MediaType = 'SSD' })
                    NetworkAdapters    = @()
                    StorageControllers = @()
                    Drivers            = @()
                    Peripherals        = @()
                }
            }
        }

        $summary = Show-TriageSummary -Collection ([pscustomobject]@{ Path = '.' })
        $summary.OS | Should Not BeNullOrEmpty
        $summary.Cpu | Should Be 'CPU-X'
        $summary.Gpu | Should Be 'GPU-Y'
        @($summary.RecentCriticalEvents).Count | Should Be 1
    }
}
