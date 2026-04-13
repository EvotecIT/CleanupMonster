BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Test-CloudDeviceInventoryScope.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-InitialCloudDevices.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceRecordKey.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceSelectionReason.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDevicesToProcess.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Get-MyDevice {}
    function Get-MyDeviceIntune {}
}

Describe 'Cloud device inventory and selection helpers' {
    It 'includes Intune orphan records in inventory output' {
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                  = 'iPhone-01'
                    EntraDeviceObjectId   = 'entra-1'
                    DeviceId              = 'device-1'
                    Enabled               = $true
                    OperatingSystem       = 'iOS'
                    OperatingSystemVersion = '17.0'
                    TrustType             = 'AzureAD registered'
                    LastSeen              = (Get-Date).AddDays(-100)
                    LastSeenDays          = 100
                    FirstSeen             = (Get-Date).AddDays(-300)
                    IsManaged             = $true
                    IsCompliant           = $true
                    ManagementType        = 'mdm'
                    EnrollmentType        = 'userEnrollment'
                    OwnerDisplayName      = @('User One')
                    OwnerUserPrincipalName = @('user.one@contoso.com')
                }
            )
        }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                  = 'iPhone-01'
                    ManagedDeviceId       = 'managed-1'
                    EntraDeviceObjectId   = 'entra-1'
                    AzureAdDeviceId       = 'device-1'
                    OperatingSystem       = 'iOS'
                    OperatingSystemVersion = '17.0'
                    LastSeen              = (Get-Date).AddDays(-95)
                    LastSeenDays          = 95
                    FirstSeen             = (Get-Date).AddDays(-300)
                    UserDisplayName       = 'User One'
                    UserPrincipalName     = 'user.one@contoso.com'
                    EmailAddress          = 'user.one@contoso.com'
                    ManagedDeviceOwnerType = 'personal'
                    DeviceRegistrationState = 'registered'
                    AzureAdRegistered     = $true
                    ComplianceState       = 'compliant'
                    ManagementAgent       = 'mdm'
                }
                [PSCustomObject] @{
                    Name                  = 'Android-Orphan'
                    ManagedDeviceId       = 'managed-2'
                    EntraDeviceObjectId   = $null
                    AzureAdDeviceId       = 'device-2'
                    OperatingSystem       = 'Android'
                    OperatingSystemVersion = '14'
                    LastSeen              = (Get-Date).AddDays(-190)
                    LastSeenDays          = 190
                    FirstSeen             = (Get-Date).AddDays(-400)
                    UserDisplayName       = 'User Two'
                    UserPrincipalName     = 'user.two@contoso.com'
                    EmailAddress          = 'user.two@contoso.com'
                    ManagedDeviceOwnerType = 'personal'
                    DeviceRegistrationState = 'registered'
                    AzureAdRegistered     = $true
                    ComplianceState       = 'unknown'
                    ManagementAgent       = 'mdm'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeOperatingSystem @('iOS*', 'Android*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices.Count | Should -Be 2
        @($devices | Where-Object { $_.RecordState -eq 'IntuneOnly' }).Count | Should -Be 1
        ($devices | Where-Object { $_.Name -eq 'Android-Orphan' }).ManagedDeviceId | Should -Be 'managed-2'
    }

    It 'continues with Intune inventory when Entra inventory is empty' {
        Mock Get-MyDevice { @() }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'Android-Orphan'
                    ManagedDeviceId         = 'managed-2'
                    EntraDeviceObjectId     = $null
                    AzureAdDeviceId         = 'device-2'
                    OperatingSystem         = 'Android'
                    OperatingSystemVersion  = '14'
                    LastSeen                = (Get-Date).AddDays(-190)
                    LastSeenDays            = 190
                    FirstSeen               = (Get-Date).AddDays(-400)
                    UserDisplayName         = 'User Two'
                    UserPrincipalName       = 'user.two@contoso.com'
                    EmailAddress            = 'user.two@contoso.com'
                    ManagedDeviceOwnerType  = 'personal'
                    DeviceRegistrationState = 'registered'
                    AzureAdRegistered       = $true
                    ComplianceState         = 'unknown'
                    ManagementAgent         = 'mdm'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeOperatingSystem @('Android*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices.Count | Should -Be 1
        $devices[0].RecordState | Should -Be 'IntuneOnly'
        $devices[0].ManagedDeviceId | Should -Be 'managed-2'
    }

    It 'adds an orphan-aware selection reason for delete candidates' {
        $devices = @(
            [PSCustomObject] @{
                Name                = 'Android-Orphan'
                EntraDeviceObjectId = $null
                DeviceId            = 'device-2'
                ManagedDeviceId     = 'managed-2'
                HasEntraRecord      = $false
                HasIntuneRecord     = $true
                RecordState         = 'IntuneOnly'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays   = $null
                IntuneLastSeenDays  = 190
                Enabled             = $null
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = 180
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $true
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].SelectionReason | Should -Match 'Delete Intune orphan record'
        $candidates[0].SelectionReason | Should -Match 'IncludeIntuneOnly=True'
        $candidates[0].ProcessedDeviceKey | Should -Be 'device:device-2'
    }

    It 'excludes Intune-only delete candidates unless explicitly enabled' {
        $devices = @(
            [PSCustomObject] @{
                Name                 = 'Android-Orphan'
                EntraDeviceObjectId  = $null
                DeviceId             = 'device-2'
                ManagedDeviceId      = 'managed-2'
                HasEntraRecord       = $false
                HasIntuneRecord      = $true
                RecordState          = 'IntuneOnly'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays    = $null
                IntuneLastSeenDays   = 190
                Enabled              = $null
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = 180
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $false
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 0
    }

    It 'allows retire candidates after a WhatIf preview entry exists' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-Preview'
                EntraDeviceObjectId    = 'entra-3'
                DeviceId               = 'device-3'
                ManagedDeviceId        = 'managed-3'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 200
                IntuneLastSeenDays     = 200
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = 180
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeIntuneOnly      = $false
        }

        $processedDevices = [ordered] @{
            'entra:entra-3' = [PSCustomObject] @{
                Action       = 'Retire'
                ActionStatus = 'WhatIf'
                ActionDate   = (Get-Date).AddDays(-5)
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Retire -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 1
        $candidates[0].ProcessedDeviceKey | Should -Be 'entra:entra-3'
    }

    It 'does not promote WhatIf entries through pending-age gates' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-Staged'
                EntraDeviceObjectId    = 'entra-4'
                DeviceId               = 'device-4'
                ManagedDeviceId        = 'managed-4'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 200
                IntuneLastSeenDays     = 200
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $processedDevices = [ordered] @{
            'entra:entra-4' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'WhatIf'
                ActionDate   = (Get-Date).AddDays(-45)
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }
}
