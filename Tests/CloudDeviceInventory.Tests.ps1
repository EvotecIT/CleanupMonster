BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceJoinTypeFromRegistrationState.ps1')
    . (Get-CleanupMonsterPath 'Private/Test-CloudDeviceRegistrationScope.ps1')
    . (Get-CleanupMonsterPath 'Private/Test-CloudDeviceInventoryScope.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceRecordKeys.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDevicePropertyValue.ps1')
    . (Get-CleanupMonsterPath 'Private/Find-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-InitialCloudDevices.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceRecordKey.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceSelectionReason.ps1')
    . (Get-CleanupMonsterPath 'Private/Test-CloudDevicePendingActivity.ps1')
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
        ($devices | Where-Object { $_.Name -eq 'iPhone-01' }).IntuneLinkState | Should -Be 'Healthy'
        ($devices | Where-Object { $_.Name -eq 'Android-Orphan' }).IntuneLinkState | Should -Be 'IntuneOnly'
    }

    It 'marks Entra devices that claim Intune but have no managed-device match as broken links' {
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                = 'Windows-BrokenIntuneLink'
                    EntraDeviceObjectId = 'entra-broken'
                    DeviceId            = 'device-broken'
                    Enabled             = $true
                    OperatingSystem     = 'Windows'
                    TrustType           = 'AzureAD joined'
                    LastSeenDays        = 120
                    FirstSeen           = (Get-Date).AddDays(-300)
                    IsManaged           = $true
                    ManagementType      = 'mdm'
                }
                [PSCustomObject] @{
                    Name                = 'Windows-NotClaimed'
                    EntraDeviceObjectId = 'entra-not-claimed'
                    DeviceId            = 'device-not-claimed'
                    Enabled             = $true
                    OperatingSystem     = 'Windows'
                    TrustType           = 'AzureAD joined'
                    LastSeenDays        = 120
                    FirstSeen           = (Get-Date).AddDays(-300)
                    IsManaged           = $false
                    ManagementType      = 'none'
                }
                [PSCustomObject] @{
                    Name                = 'Windows-OtherMdm'
                    EntraDeviceObjectId = 'entra-other-mdm'
                    DeviceId            = 'device-other-mdm'
                    Enabled             = $true
                    OperatingSystem     = 'Windows'
                    TrustType           = 'AzureAD joined'
                    LastSeenDays        = 120
                    FirstSeen           = (Get-Date).AddDays(-300)
                    IsManaged           = $true
                    ManagementType      = 'jamf'
                }
            )
        }
        Mock Get-MyDeviceIntune { @() }

        $devices = @(Get-InitialCloudDevices -IncludeJoinType 'AzureAD joined' -IncludeOperatingSystem @('Windows*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices | Should -HaveCount 3
        ($devices | Where-Object { $_.Name -eq 'Windows-BrokenIntuneLink' }).IntuneLinkState | Should -Be 'Broken'
        ($devices | Where-Object { $_.Name -eq 'Windows-BrokenIntuneLink' }).ClaimsIntuneManagement | Should -BeTrue
        ($devices | Where-Object { $_.Name -eq 'Windows-NotClaimed' }).IntuneLinkState | Should -Be 'NotClaimed'
        ($devices | Where-Object { $_.Name -eq 'Windows-NotClaimed' }).ClaimsIntuneManagement | Should -BeFalse
        ($devices | Where-Object { $_.Name -eq 'Windows-OtherMdm' }).IntuneLinkState | Should -Be 'NotClaimed'
        ($devices | Where-Object { $_.Name -eq 'Windows-OtherMdm' }).ClaimsIntuneManagement | Should -BeFalse
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

    It 'keeps Entra Autopilot metadata when matched Intune fields are missing' {
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                       = 'Windows-Autopilot-Matched'
                    EntraDeviceObjectId        = 'entra-ap'
                    DeviceId                   = 'device-ap'
                    Enabled                    = $false
                    OperatingSystem            = 'Windows'
                    TrustType                  = 'AzureAD joined'
                    LastSeenDays               = 250
                    FirstSeen                  = (Get-Date).AddDays(-500)
                    AutopilotInventoryLoaded   = $true
                    AutopilotOnboarded         = $true
                    AutopilotDeviceId          = 'entra-autopilot-id'
                    AutopilotManagedDeviceId   = $null
                    AutopilotAzureAdDeviceId   = 'device-ap'
                    AutopilotResourceName      = 'Windows-Autopilot-Matched'
                    AutopilotGroupTag          = 'DoNotDelete-Ring'
                    AutopilotSerialNumber      = 'SERIAL-AP'
                    AutopilotLastContactedDays = 120
                    AutopilotUserPrincipalName = 'assigned.user@contoso.com'
                }
            )
        }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'Windows-Autopilot-Matched'
                    ManagedDeviceId         = 'managed-ap'
                    EntraDeviceObjectId     = 'entra-ap'
                    AzureAdDeviceId         = 'device-ap'
                    OperatingSystem         = 'Windows'
                    OperatingSystemVersion  = '10.0.22631.5624'
                    LastSeenDays            = 250
                    FirstSeen               = (Get-Date).AddDays(-500)
                    ManagedDeviceOwnerType  = 'company'
                    DeviceRegistrationState = 'joined'
                    AzureAdRegistered       = $true
                    ComplianceState         = 'unknown'
                    ManagementAgent         = 'mdm'
                    AutopilotInventoryLoaded = $null
                    AutopilotOnboarded       = $null
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeJoinType 'AzureAD joined' -IncludeOperatingSystem @('Windows*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices | Should -HaveCount 1
        $devices[0].AutopilotInventoryLoaded | Should -BeTrue
        $devices[0].AutopilotOnboarded | Should -BeTrue
        $devices[0].AutopilotDeviceId | Should -Be 'entra-autopilot-id'
        $devices[0].AutopilotManagedDeviceId | Should -BeNullOrEmpty
        $devices[0].AutopilotAzureAdDeviceId | Should -Be 'device-ap'
        $devices[0].AutopilotResourceName | Should -Be 'Windows-Autopilot-Matched'
        $devices[0].AutopilotGroupTag | Should -Be 'DoNotDelete-Ring'
        $devices[0].AutopilotSerialNumber | Should -Be 'SERIAL-AP'
        $devices[0].AutopilotLastContactedDays | Should -Be 120
        $devices[0].AutopilotUserPrincipalName | Should -Be 'assigned.user@contoso.com'
    }

    It 'computes Autopilot last-contact age when inventory only supplies the timestamp' {
        $autopilotLastContacted = (Get-Date).AddDays(-120).AddHours(-1)
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                       = 'Windows-Autopilot-Timestamp'
                    EntraDeviceObjectId        = 'entra-ap-timestamp'
                    DeviceId                   = 'device-ap-timestamp'
                    Enabled                    = $false
                    OperatingSystem            = 'Windows'
                    TrustType                  = 'AzureAD joined'
                    LastSeenDays               = 250
                    FirstSeen                  = (Get-Date).AddDays(-500)
                    AutopilotInventoryLoaded   = $true
                    AutopilotOnboarded         = $true
                    AutopilotDeviceId          = 'autopilot-timestamp'
                    AutopilotAzureAdDeviceId   = 'device-ap-timestamp'
                    AutopilotSerialNumber      = 'SERIAL-TIMESTAMP'
                    AutopilotLastContacted     = $autopilotLastContacted
                }
            )
        }
        Mock Get-MyDeviceIntune { @() }

        $devices = @(Get-InitialCloudDevices -IncludeJoinType 'AzureAD joined' -IncludeOperatingSystem @('Windows*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices | Should -HaveCount 1
        $devices[0].AutopilotLastContacted | Should -Be $autopilotLastContacted
        $devices[0].AutopilotLastContactedDays | Should -Be 120
    }

    It 'preserves explicit false Intune Autopilot state over Entra fallback' {
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                     = 'Windows-NotAutopilot'
                    EntraDeviceObjectId      = 'entra-not-ap'
                    DeviceId                 = 'device-not-ap'
                    Enabled                  = $false
                    OperatingSystem          = 'Windows'
                    TrustType                = 'AzureAD joined'
                    LastSeenDays             = 250
                    FirstSeen                = (Get-Date).AddDays(-500)
                    AutopilotInventoryLoaded = $true
                    AutopilotOnboarded       = $true
                }
            )
        }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                     = 'Windows-NotAutopilot'
                    ManagedDeviceId          = 'managed-not-ap'
                    AzureAdDeviceId          = 'device-not-ap'
                    OperatingSystem          = 'Windows'
                    OperatingSystemVersion   = '10.0.22631.5624'
                    DeviceRegistrationState  = 'joined'
                    AzureAdRegistered        = $true
                    ManagementAgent          = 'mdm'
                    AutopilotInventoryLoaded = $false
                    AutopilotOnboarded       = $false
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeJoinType 'AzureAD joined' -IncludeOperatingSystem @('Windows*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices | Should -HaveCount 1
        $devices[0].AutopilotInventoryLoaded | Should -BeFalse
        $devices[0].AutopilotOnboarded | Should -BeFalse
    }

    It 'excludes hybrid and joined records from cloud cleanup inventory' {
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                  = 'Hybrid-Windows'
                    EntraDeviceObjectId   = 'entra-hybrid'
                    DeviceId              = 'device-hybrid'
                    Enabled               = $true
                    OperatingSystem       = 'Windows'
                    TrustType             = 'Hybrid AzureAD'
                    IsSynchronized        = $true
                    LastSeen              = (Get-Date).AddDays(-200)
                    LastSeenDays          = 200
                }
                [PSCustomObject] @{
                    Name                  = 'Joined-Windows'
                    EntraDeviceObjectId   = 'entra-joined'
                    DeviceId              = 'device-joined'
                    Enabled               = $true
                    OperatingSystem       = 'Windows'
                    TrustType             = 'AzureAD joined'
                    IsSynchronized        = $false
                    LastSeen              = (Get-Date).AddDays(-200)
                    LastSeenDays          = 200
                }
                [PSCustomObject] @{
                    Name                  = 'Android-Registered'
                    EntraDeviceObjectId   = 'entra-registered'
                    DeviceId              = 'device-registered'
                    Enabled               = $true
                    OperatingSystem       = 'Android'
                    TrustType             = 'AzureAD registered'
                    IsSynchronized        = $false
                    LastSeen              = (Get-Date).AddDays(-200)
                    LastSeenDays          = 200
                }
            )
        }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'Hybrid-Intune'
                    ManagedDeviceId         = 'managed-hybrid'
                    EntraDeviceObjectId     = 'entra-hybrid-intune'
                    AzureAdDeviceId         = 'device-hybrid-intune'
                    OperatingSystem         = 'Windows'
                    TrustType               = 'Hybrid AzureAD'
                    IsSynchronized          = $true
                    AzureAdRegistered       = $true
                    LastSeen                = (Get-Date).AddDays(-200)
                    LastSeenDays            = 200
                    DeviceRegistrationState = 'registered'
                }
                [PSCustomObject] @{
                    Name                    = 'Joined-State-Intune'
                    ManagedDeviceId         = 'managed-joined-state'
                    EntraDeviceObjectId     = $null
                    AzureAdDeviceId         = 'device-joined-state'
                    OperatingSystem         = 'Android'
                    AzureAdRegistered       = $true
                    LastSeen                = (Get-Date).AddDays(-200)
                    LastSeenDays            = 200
                    DeviceRegistrationState = 'joined'
                }
                [PSCustomObject] @{
                    Name                    = 'Unknown-State-Intune'
                    ManagedDeviceId         = 'managed-unknown-state'
                    EntraDeviceObjectId     = $null
                    AzureAdDeviceId         = 'device-unknown-state'
                    OperatingSystem         = 'Android'
                    AzureAdRegistered       = $true
                    LastSeen                = (Get-Date).AddDays(-200)
                    LastSeenDays            = 200
                }
                [PSCustomObject] @{
                    Name                    = 'Android-Orphan'
                    ManagedDeviceId         = 'managed-registered'
                    EntraDeviceObjectId     = $null
                    AzureAdDeviceId         = 'device-orphan'
                    OperatingSystem         = 'Android'
                    TrustType               = 'AzureAD registered'
                    IsSynchronized          = $false
                    AzureAdRegistered       = $true
                    LastSeen                = (Get-Date).AddDays(-200)
                    LastSeenDays            = 200
                    DeviceRegistrationState = 'registered'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeOperatingSystem @('*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices.Name | Should -Contain 'Android-Registered'
        $devices.Name | Should -Contain 'Android-Orphan'
        $devices.Name | Should -Not -Contain 'Hybrid-Windows'
        $devices.Name | Should -Not -Contain 'Joined-Windows'
        $devices.Name | Should -Not -Contain 'Hybrid-Intune'
        $devices.Name | Should -Not -Contain 'Joined-State-Intune'
        $devices.Name | Should -Not -Contain 'Unknown-State-Intune'
    }

    It 'maps joined Intune-only registration state when AzureAD joined is included' {
        Mock Get-MyDevice { @() }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'Windows-Joined-Orphan'
                    ManagedDeviceId         = 'managed-joined-orphan'
                    EntraDeviceObjectId     = $null
                    AzureAdDeviceId         = 'device-joined-orphan'
                    OperatingSystem         = 'Windows'
                    OperatingSystemVersion  = '10.0.22631.5624'
                    LastSeen                = (Get-Date).AddDays(-190)
                    LastSeenDays            = 190
                    FirstSeen               = (Get-Date).AddDays(-400)
                    ManagedDeviceOwnerType  = 'personal'
                    DeviceRegistrationState = 'joined'
                    AzureAdRegistered       = $true
                    ComplianceState         = 'unknown'
                    ManagementAgent         = 'mdm'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeJoinType 'AzureAD joined' -IncludeOperatingSystem @('Windows*') -ExcludeOperatingSystem @() -Exclusions @())

        $devices.Count | Should -Be 1
        $devices[0].Name | Should -Be 'Windows-Joined-Orphan'
        $devices[0].TrustType | Should -Be 'AzureAD joined'
    }

    It 'maps blank Intune registration state to not available when included' {
        $device = [PSCustomObject] @{
            DeviceRegistrationState = $null
        }

        $result = Test-CloudDeviceRegistrationScope -Device $device -IncludeJoinType 'Not available'

        $result | Should -BeTrue
    }

    It 'maps missing Intune registration state to not available when included' {
        $device = [PSCustomObject] @{
            Name = 'Unknown-State-Intune'
        }

        $result = Test-CloudDeviceRegistrationScope -Device $device -IncludeJoinType 'Not available'

        $result | Should -BeTrue
    }

    It 'does not pass Not available to the Entra inventory query' {
        $script:CapturedEntraJoinType = $null
        Mock Get-MyDevice {
            param([string[]] $Type)
            $script:CapturedEntraJoinType = @($Type)
            @()
        }
        Mock Get-MyDeviceIntune { @() }

        Get-InitialCloudDevices -IncludeJoinType 'AzureAD registered', 'Not available' -IncludeOperatingSystem @('*') -ExcludeOperatingSystem @() -Exclusions @() | Out-Null

        $script:CapturedEntraJoinType | Should -Be @('AzureAD registered')
    }

    It 'skips Entra inventory when only Not available join type is requested' {
        Mock Get-MyDevice { throw 'Entra inventory should not be queried' }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'Unknown-State-Intune'
                    ManagedDeviceId         = 'managed-unknown-state'
                    AzureAdDeviceId         = 'device-unknown-state'
                    OperatingSystem         = 'Unknown'
                    OperatingSystemVersion  = 'Unknown'
                    LastSeenDays            = 400
                    FirstSeen               = (Get-Date).AddDays(-500)
                    ManagedDeviceOwnerType  = 'personal'
                    DeviceRegistrationState = ''
                    AzureAdRegistered       = $true
                    ComplianceState         = 'unknown'
                    ManagementAgent         = 'mdm'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeJoinType 'Not available' -IncludeOperatingSystem @('*') -ExcludeOperatingSystem @() -Exclusions @())

        Assert-MockCalled Get-MyDevice -Times 0 -Exactly
        $devices | Should -HaveCount 1
        $devices[0].Name | Should -Be 'Unknown-State-Intune'
    }

    It 'keeps synchronized or non-registered records out before mapping missing join metadata' {
        $synchronized = [PSCustomObject] @{
            DeviceRegistrationState = ''
            IsSynchronized          = $true
            AzureAdRegistered       = $true
        }
        $nonRegistered = [PSCustomObject] @{
            DeviceRegistrationState = ''
            AzureAdRegistered       = $false
        }

        Test-CloudDeviceRegistrationScope -Device $synchronized -IncludeJoinType 'Not available' | Should -BeFalse
        Test-CloudDeviceRegistrationScope -Device $nonRegistered -IncludeJoinType 'Not available' | Should -BeFalse
    }

    It 'applies managed-device exclusions to matched records' {
        Mock Get-MyDevice {
            @(
                [PSCustomObject] @{
                    Name                   = 'iPhone-ManagedExcluded'
                    EntraDeviceObjectId    = 'entra-managed-excluded'
                    DeviceId               = 'device-managed-excluded'
                    Enabled                = $true
                    OperatingSystem        = 'iOS'
                    OperatingSystemVersion = '17.0'
                    TrustType              = 'AzureAD registered'
                    LastSeen               = (Get-Date).AddDays(-100)
                    LastSeenDays           = 100
                    FirstSeen              = (Get-Date).AddDays(-300)
                    IsManaged              = $true
                    IsCompliant            = $true
                    ManagementType         = 'mdm'
                    EnrollmentType         = 'userEnrollment'
                    OwnerDisplayName       = @('User Managed')
                    OwnerUserPrincipalName = @('user.managed@contoso.com')
                }
            )
        }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'iPhone-ManagedExcluded'
                    ManagedDeviceId         = 'managed-excluded'
                    EntraDeviceObjectId     = 'entra-managed-excluded'
                    AzureAdDeviceId         = 'device-managed-excluded'
                    OperatingSystem         = 'iOS'
                    OperatingSystemVersion  = '17.0'
                    LastSeen                = (Get-Date).AddDays(-95)
                    LastSeenDays            = 95
                    FirstSeen               = (Get-Date).AddDays(-300)
                    UserDisplayName         = 'User Managed'
                    UserPrincipalName       = 'user.managed@contoso.com'
                    EmailAddress            = 'user.managed@contoso.com'
                    ManagedDeviceOwnerType  = 'personal'
                    DeviceRegistrationState = 'registered'
                    AzureAdRegistered       = $true
                    ComplianceState         = 'compliant'
                    ManagementAgent         = 'mdm'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeOperatingSystem @('iOS*') -ExcludeOperatingSystem @() -Exclusions @('managed-excluded'))

        $devices.Count | Should -Be 0
    }

    It 'applies Entra object-id exclusions during the Intune orphan sweep' {
        Mock Get-MyDevice { @() }
        Mock Get-MyDeviceIntune {
            @(
                [PSCustomObject] @{
                    Name                    = 'Android-Excluded'
                    ManagedDeviceId         = 'managed-excluded'
                    EntraDeviceObjectId     = 'entra-excluded'
                    AzureAdDeviceId         = 'device-excluded'
                    OperatingSystem         = 'Android'
                    OperatingSystemVersion  = '14'
                    LastSeen                = (Get-Date).AddDays(-90)
                    LastSeenDays            = 90
                    FirstSeen               = (Get-Date).AddDays(-200)
                    UserDisplayName         = 'User Excluded'
                    UserPrincipalName       = 'user.excluded@contoso.com'
                    EmailAddress            = 'user.excluded@contoso.com'
                    ManagedDeviceOwnerType  = 'personal'
                    DeviceRegistrationState = 'registered'
                    AzureAdRegistered       = $true
                    ComplianceState         = 'unknown'
                    ManagementAgent         = 'mdm'
                }
            )
        }

        $devices = @(Get-InitialCloudDevices -IncludeOperatingSystem @('Android*') -ExcludeOperatingSystem @() -Exclusions @('entra-excluded'))

        $devices.Count | Should -Be 0
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
        $candidates[0].ProcessedDeviceKey | Should -Be 'intune:managed-2'
    }

    It 'keeps Intune-only delete selection reasons aligned with the executor' {
        $device = [PSCustomObject] @{
            Name                 = 'Android-Orphan'
            EntraDeviceObjectId  = 'entra-2'
            DeviceId             = 'device-2'
            ManagedDeviceId      = 'managed-2'
            HasEntraRecord       = $true
            HasIntuneRecord      = $true
            RecordState          = 'IntuneOnly'
            ManagedDeviceOwnerType = 'personal'
            EntraLastSeenDays    = $null
            IntuneLastSeenDays   = 190
            Enabled              = $null
        }

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = 180
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $true
        }

        $reason = Get-CloudDeviceSelectionReason -Device $device -Type Delete -ActionIf $actionIf

        $reason | Should -Match 'Delete Intune orphan record'
        $reason | Should -Not -Match 'Entra device object'
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

    It 'only treats missing Autopilot as not onboarded when Autopilot inventory was loaded' {
        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-UnknownAutopilot'
                EntraDeviceObjectId      = 'entra-ap-unknown'
                DeviceId                 = 'device-ap-unknown'
                ManagedDeviceId          = 'managed-ap-unknown'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ManagedDeviceOwnerType   = 'personal'
                EntraLastSeenDays        = 300
                IntuneLastSeenDays       = 300
                Enabled                  = $true
                AutopilotInventoryLoaded = $false
                AutopilotOnboarded       = $null
            }
            [PSCustomObject] @{
                Name                     = 'Windows-NotAutopilot'
                EntraDeviceObjectId      = 'entra-ap-no'
                DeviceId                 = 'device-ap-no'
                ManagedDeviceId          = 'managed-ap-no'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ManagedDeviceOwnerType   = 'personal'
                EntraLastSeenDays        = 300
                IntuneLastSeenDays       = 300
                Enabled                  = $true
                AutopilotInventoryLoaded = $true
                AutopilotOnboarded       = $false
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = $null
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            AutopilotState         = 'NotOnboarded'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].Name | Should -Be 'Windows-NotAutopilot'
    }

    It 'selects stale Autopilot identities with missing Intune association for standalone removal' {
        $devices = @(
            [PSCustomObject] @{
                Name                          = 'Windows-Autopilot-Orphan'
                EntraDeviceObjectId           = 'entra-ap-orphan'
                DeviceId                      = 'device-ap-orphan'
                HasEntraRecord                = $true
                HasIntuneRecord               = $false
                RecordState                   = 'EntraOnly'
                ManagedDeviceOwnerType        = 'personal'
                AutopilotInventoryLoaded      = $true
                AutopilotOnboarded            = $true
                AutopilotDeviceId             = 'autopilot-orphan'
                AutopilotManagedDeviceId      = $null
                AutopilotAzureAdDeviceId      = 'device-ap-orphan'
                AutopilotResourceName         = 'SERIAL-ORPHAN'
                AutopilotSerialNumber         = 'SERIAL-ORPHAN'
                AutopilotLastContactedDays    = 120
            }
            [PSCustomObject] @{
                Name                          = 'Windows-Autopilot-Managed'
                EntraDeviceObjectId           = 'entra-ap-managed'
                DeviceId                      = 'device-ap-managed'
                HasEntraRecord                = $true
                HasIntuneRecord               = $true
                RecordState                   = 'Matched'
                ManagedDeviceOwnerType        = 'personal'
                AutopilotInventoryLoaded      = $true
                AutopilotOnboarded            = $true
                AutopilotDeviceId             = 'autopilot-managed'
                AutopilotManagedDeviceId      = 'managed-ap'
                AutopilotAzureAdDeviceId      = 'device-ap-managed'
                AutopilotResourceName         = 'SERIAL-MANAGED'
                AutopilotSerialNumber         = 'SERIAL-MANAGED'
                AutopilotLastContactedDays    = 120
            }
        )

        $actionIf = [ordered] @{
            AutopilotLastContactMoreThan      = 90
            IncludeUnknownActivity            = $false
            ExcludeCompanyOwned               = $true
            AutopilotState                    = 'Onboarded'
            AutopilotIntuneAssociationState   = 'Missing'
            AutopilotEntraAssociationState    = 'EqualsSerialNumber'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type RemoveAutopilotIdentity -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].Name | Should -Be 'Windows-Autopilot-Orphan'
        $candidates[0].SelectionReason | Should -Match 'AutopilotIntuneAssociationState=Missing'
        $candidates[0].SelectionReason | Should -Match 'AutopilotEntraAssociationState=EqualsSerialNumber'
    }

    It 'treats Autopilot Entra association as missing when only the resource name is present' {
        $devices = @(
            [PSCustomObject] @{
                Name                          = 'Windows-Autopilot-MissingEntra'
                EntraDeviceObjectId           = 'entra-missing-entra'
                DeviceId                      = 'device-missing-entra'
                HasEntraRecord                = $true
                HasIntuneRecord               = $false
                RecordState                   = 'EntraOnly'
                ManagedDeviceOwnerType        = 'personal'
                AutopilotInventoryLoaded      = $true
                AutopilotOnboarded            = $true
                AutopilotDeviceId             = 'autopilot-missing-entra'
                AutopilotManagedDeviceId      = $null
                AutopilotAzureAdDeviceId      = $null
                AutopilotResourceName         = 'SERIAL-MISSING-ENTRA'
                AutopilotSerialNumber         = 'SERIAL-MISSING-ENTRA'
                AutopilotLastContactedDays    = 120
            }
            [PSCustomObject] @{
                Name                          = 'Windows-Autopilot-AssociatedEntra'
                EntraDeviceObjectId           = 'entra-associated-entra'
                DeviceId                      = 'device-associated-entra'
                HasEntraRecord                = $true
                HasIntuneRecord               = $false
                RecordState                   = 'EntraOnly'
                ManagedDeviceOwnerType        = 'personal'
                AutopilotInventoryLoaded      = $true
                AutopilotOnboarded            = $true
                AutopilotDeviceId             = 'autopilot-associated-entra'
                AutopilotManagedDeviceId      = $null
                AutopilotAzureAdDeviceId      = 'device-associated-entra'
                AutopilotResourceName         = 'SERIAL-ASSOCIATED-ENTRA'
                AutopilotSerialNumber         = 'SERIAL-ASSOCIATED-ENTRA'
                AutopilotLastContactedDays    = 120
            }
        )

        $actionIf = [ordered] @{
            AutopilotLastContactMoreThan      = 90
            IncludeUnknownActivity            = $false
            ExcludeCompanyOwned               = $true
            AutopilotState                    = 'Onboarded'
            AutopilotIntuneAssociationState   = 'Missing'
            AutopilotEntraAssociationState    = 'Missing'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type RemoveAutopilotIdentity -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates | Should -HaveCount 1
        $candidates[0].Name | Should -Be 'Windows-Autopilot-MissingEntra'
        $candidates[0].SelectionReason | Should -Match 'AutopilotEntraAssociationState=Missing'
    }

    It 'filters action candidates to broken Intune links older than the configured threshold' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'Windows-BrokenIntuneLink'
                EntraDeviceObjectId    = 'entra-broken'
                DeviceId               = 'device-broken'
                HasEntraRecord         = $true
                HasIntuneRecord        = $false
                RecordState            = 'EntraOnly'
                IntuneLinkState        = 'Broken'
                ClaimsIntuneManagement = $true
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 120
                Enabled                = $true
            }
            [PSCustomObject] @{
                Name                   = 'Windows-NotClaimed'
                EntraDeviceObjectId    = 'entra-not-claimed'
                DeviceId               = 'device-not-claimed'
                HasEntraRecord         = $true
                HasIntuneRecord        = $false
                RecordState            = 'EntraOnly'
                IntuneLinkState        = 'NotClaimed'
                ClaimsIntuneManagement = $false
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 120
                Enabled                = $true
            }
            [PSCustomObject] @{
                Name                   = 'Windows-BrokenButFresh'
                EntraDeviceObjectId    = 'entra-broken-fresh'
                DeviceId               = 'device-broken-fresh'
                HasEntraRecord         = $true
                HasIntuneRecord        = $false
                RecordState            = 'EntraOnly'
                IntuneLinkState        = 'Broken'
                ClaimsIntuneManagement = $true
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 10
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 90
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = $null
            ListProcessedMoreThan  = $null
            IncludeUnknownActivity = $false
            ExcludeCompanyOwned    = $true
            IntuneLinkState        = 'Broken'
            IncludeEntraOnly       = $true
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].Name | Should -Be 'Windows-BrokenIntuneLink'
        $candidates[0].SelectionReason | Should -Match 'IntuneLinkState=Broken'
        $candidates[0].SelectionReason | Should -Match 'RequiredIntuneLinkState=Broken'
    }

    It 'filters action candidates by owner, management, compliance, and registration age' {
        $oldRegistration = (Get-Date).AddDays(-500)
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'Windows-Delete'
                EntraDeviceObjectId    = 'entra-delete'
                DeviceId               = 'device-delete'
                ManagedDeviceId        = 'managed-delete'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 400
                IntuneLastSeenDays     = 400
                FirstSeen              = $oldRegistration
                RegisteredDays         = 500
                Enabled                = $false
                OwnerDisplayName       = @()
                OwnerUserPrincipalName = @()
                IsManaged              = $true
                ManagementAgent        = 'mdm'
                IsCompliant            = $false
                ComplianceState        = 'noncompliant'
            }
            [PSCustomObject] @{
                Name                   = 'Windows-Keep-Owner'
                EntraDeviceObjectId    = 'entra-owner'
                DeviceId               = 'device-owner'
                ManagedDeviceId        = 'managed-owner'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 400
                IntuneLastSeenDays     = 400
                RegisteredDays         = 500
                Enabled                = $false
                OwnerDisplayName       = @('User One')
                IsManaged              = $true
                ManagementAgent        = 'mdm'
                IsCompliant            = $false
                ComplianceState        = 'noncompliant'
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = 365
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $false
            OwnerState             = 'WithoutOwner'
            ManagementState        = 'Mdm'
            ComplianceState        = 'NonCompliant'
            EnabledState           = 'Disabled'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].Name | Should -Be 'Windows-Delete'
        $candidates[0].SelectionReason | Should -Match 'RegisteredDays=500 > 365'
        $candidates[0].SelectionReason | Should -Match 'OwnerState=WithoutOwner'
    }

    It 'prefers Intune compliance state over Entra compliance flag' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'Windows-ConflictingCompliance'
                EntraDeviceObjectId    = 'entra-conflict'
                DeviceId               = 'device-conflict'
                ManagedDeviceId        = 'managed-conflict'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 400
                RegisteredDays         = 500
                Enabled                = $false
                IsCompliant            = $true
                ComplianceState        = 'noncompliant'
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = $null
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $false
            ComplianceState        = 'NonCompliant'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].Name | Should -Be 'Windows-ConflictingCompliance'
    }

    It 'skips Autopilot group-tag exclusion when Autopilot inventory was not loaded' {
        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-UnknownTag'
                EntraDeviceObjectId      = 'entra-unknown-tag'
                DeviceId                 = 'device-unknown-tag'
                ManagedDeviceId          = 'managed-unknown-tag'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ManagedDeviceOwnerType   = 'personal'
                OperatingSystem          = 'Windows'
                EntraLastSeenDays        = 300
                Enabled                  = $true
                AutopilotInventoryLoaded = $false
                AutopilotGroupTag        = $null
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan    = 180
            LastSeenIntuneMoreThan   = $null
            RegisteredMoreThan       = $null
            ListProcessedMoreThan    = $null
            ExcludeCompanyOwned      = $true
            IncludeEntraOnly         = $false
            ExcludeAutopilotGroupTag = @('DoNotDelete*')
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 0
    }

    It 'does not treat Windows devices as ownerless when Autopilot inventory state is unknown' {
        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-UnknownOwner'
                EntraDeviceObjectId      = 'entra-unknown-owner'
                DeviceId                 = 'device-unknown-owner'
                ManagedDeviceId          = 'managed-unknown-owner'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ManagedDeviceOwnerType   = 'personal'
                OperatingSystem          = 'Windows'
                EntraLastSeenDays        = 300
                Enabled                  = $true
                OwnerDisplayName         = @()
                OwnerUserPrincipalName   = @()
                IntuneUserDisplayName    = $null
                IntuneUserPrincipalName  = $null
                AutopilotInventoryLoaded = $null
                AutopilotUserPrincipalName = $null
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = $null
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            OwnerState             = 'WithoutOwner'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 0
    }

    It 'allows Windows devices with direct owner data through WithOwner when Autopilot inventory is unavailable' {
        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-WithOwner'
                EntraDeviceObjectId      = 'entra-with-owner'
                DeviceId                 = 'device-with-owner'
                ManagedDeviceId          = 'managed-with-owner'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ManagedDeviceOwnerType   = 'personal'
                OperatingSystem          = 'Windows'
                EntraLastSeenDays        = 300
                Enabled                  = $true
                OwnerDisplayName         = @('User One')
                AutopilotInventoryLoaded = $false
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = $null
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            OwnerState             = 'WithOwner'
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].Name | Should -Be 'Windows-WithOwner'
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
            'intune:managed-3' = [PSCustomObject] @{
                Action       = 'Retire'
                ActionStatus = 'WhatIf'
                ActionDate   = (Get-Date).AddDays(-5)
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Retire -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 1
        $candidates[0].ProcessedDeviceKey | Should -Be 'intune:managed-3'
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
            'intune:managed-4' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'WhatIf'
                ActionDate   = (Get-Date).AddDays(-45)
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }

    It 'does not promote pending-aged devices after new activity is observed' {
        $previousEntraLastSeen = (Get-Date).AddDays(-200)
        $previousIntuneLastSeen = (Get-Date).AddDays(-200)

        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-Reactivated'
                EntraDeviceObjectId    = 'entra-reactivated'
                DeviceId               = 'device-reactivated'
                ManagedDeviceId        = 'managed-reactivated'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeen          = (Get-Date).AddDays(-1)
                IntuneLastSeen         = (Get-Date).AddDays(-1)
                EntraLastSeenDays      = 1
                IntuneLastSeenDays     = 1
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $processedDevices = [ordered] @{
            'intune:managed-reactivated' = [PSCustomObject] @{
                Action              = 'Retire'
                ActionStatus        = 'True'
                ActionDate          = (Get-Date).AddDays(-31)
                ManagedDeviceId     = 'managed-reactivated'
                EntraDeviceObjectId = 'entra-reactivated'
                DeviceId            = 'device-reactivated'
                EntraLastSeen       = $previousEntraLastSeen
                IntuneLastSeen      = $previousIntuneLastSeen
                ProcessedDeviceKeys = @('intune:managed-reactivated', 'entra:entra-reactivated', 'device:device-reactivated')
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }

    It 'does not promote pending-aged devices with stale thresholds after new activity is observed' {
        $previousEntraLastSeen = (Get-Date).AddDays(-220)
        $previousIntuneLastSeen = (Get-Date).AddDays(-220)
        $currentEntraLastSeen = (Get-Date).AddDays(-190)
        $currentIntuneLastSeen = (Get-Date).AddDays(-190)

        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-ReactivatedButStillStale'
                EntraDeviceObjectId    = 'entra-reactivated-stale'
                DeviceId               = 'device-reactivated-stale'
                ManagedDeviceId        = 'managed-reactivated-stale'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeen          = $currentEntraLastSeen
                IntuneLastSeen         = $currentIntuneLastSeen
                EntraLastSeenDays      = 190
                IntuneLastSeenDays     = 190
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = 180
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $processedDevices = [ordered] @{
            'intune:managed-reactivated-stale' = [PSCustomObject] @{
                Action              = 'Retire'
                ActionStatus        = 'True'
                ActionDate          = (Get-Date).AddDays(-31)
                ManagedDeviceId     = 'managed-reactivated-stale'
                EntraDeviceObjectId = 'entra-reactivated-stale'
                DeviceId            = 'device-reactivated-stale'
                EntraLastSeen       = $previousEntraLastSeen
                IntuneLastSeen      = $previousIntuneLastSeen
                ProcessedDeviceKeys = @('intune:managed-reactivated-stale', 'entra:entra-reactivated-stale', 'device:device-reactivated-stale')
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }

    It 'does not promote pending-aged devices when current activity is missing' {
        $previousEntraLastSeen = (Get-Date).AddDays(-220)
        $previousIntuneLastSeen = (Get-Date).AddDays(-220)

        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-MissingActivity'
                EntraDeviceObjectId    = 'entra-missing-activity'
                DeviceId               = 'device-missing-activity'
                ManagedDeviceId        = 'managed-missing-activity'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeen          = $null
                IntuneLastSeen         = $previousIntuneLastSeen
                EntraLastSeenDays      = $null
                IntuneLastSeenDays     = 220
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $processedDevices = [ordered] @{
            'intune:managed-missing-activity' = [PSCustomObject] @{
                Action              = 'Retire'
                ActionStatus        = 'True'
                ActionDate          = (Get-Date).AddDays(-31)
                ManagedDeviceId     = 'managed-missing-activity'
                EntraDeviceObjectId = 'entra-missing-activity'
                DeviceId            = 'device-missing-activity'
                EntraLastSeen       = $previousEntraLastSeen
                IntuneLastSeen      = $previousIntuneLastSeen
                ProcessedDeviceKeys = @('intune:managed-missing-activity', 'entra:entra-missing-activity', 'device:device-missing-activity')
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }

    It 'does not treat unknown activity as stale unless explicitly included' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'Windows-UnknownActivity'
                EntraDeviceObjectId    = 'entra-unknown-activity'
                DeviceId               = 'device-unknown-activity'
                HasEntraRecord         = $true
                HasIntuneRecord        = $false
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = $null
                RegisteredDays         = 200
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 90
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = 90
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 0
    }

    It 'allows unknown activity to satisfy stale filters when explicitly included' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'Windows-UnknownActivityIncluded'
                EntraDeviceObjectId    = 'entra-unknown-activity-included'
                DeviceId               = 'device-unknown-activity-included'
                HasEntraRecord         = $true
                HasIntuneRecord        = $false
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = $null
                RegisteredDays         = 200
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 90
            LastSeenIntuneMoreThan = $null
            RegisteredMoreThan     = 90
            IncludeUnknownActivity = $true
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 1
        $candidates[0].SelectionReason | Should -Match 'EntraLastSeenDays=Unknown allowed'
    }

    It 'promotes pending-aged devices when activity has not advanced' {
        $staleEntraLastSeen = (Get-Date).AddDays(-200)
        $staleIntuneLastSeen = (Get-Date).AddDays(-200)

        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-StillStale'
                EntraDeviceObjectId    = 'entra-still-stale'
                DeviceId               = 'device-still-stale'
                ManagedDeviceId        = 'managed-still-stale'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeen          = $staleEntraLastSeen
                IntuneLastSeen         = $staleIntuneLastSeen
                EntraLastSeenDays      = 200
                IntuneLastSeenDays     = 200
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = $null
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $processedDevices = [ordered] @{
            'intune:managed-still-stale' = [PSCustomObject] @{
                Action              = 'Retire'
                ActionStatus        = 'True'
                ActionDate          = (Get-Date).AddDays(-31)
                ManagedDeviceId     = 'managed-still-stale'
                EntraDeviceObjectId = 'entra-still-stale'
                DeviceId            = 'device-still-stale'
                EntraLastSeen       = $staleEntraLastSeen
                IntuneLastSeen      = $staleIntuneLastSeen
                ProcessedDeviceKeys = @('intune:managed-still-stale', 'entra:entra-still-stale', 'device:device-still-stale')
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 1
        $candidates[0].ProcessedDeviceKey | Should -Be 'intune:managed-still-stale'
    }

    It 'excludes enabled Entra-backed delete candidates' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-Reenabled'
                EntraDeviceObjectId    = 'entra-5'
                DeviceId               = 'device-5'
                ManagedDeviceId        = 'managed-5'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 300
                IntuneLastSeenDays     = 300
                Enabled                = $true
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $false
        }

        $processedDevices = [ordered] @{
            'intune:managed-5' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-45)
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }

    It 'does not disable Entra-backed candidates when enabled state is unknown' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-UnknownEnabled'
                EntraDeviceObjectId    = 'entra-unknown-enabled'
                DeviceId               = 'device-unknown-enabled'
                ManagedDeviceId        = 'managed-unknown-enabled'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 300
                IntuneLastSeenDays     = 300
                Enabled                = $null
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 0
    }

    It 'does not delete Entra-backed candidates when enabled state is unknown' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-UnknownDeleteState'
                EntraDeviceObjectId    = 'entra-unknown-delete'
                DeviceId               = 'device-unknown-delete'
                ManagedDeviceId        = 'managed-unknown-delete'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'Matched'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 300
                IntuneLastSeenDays     = 300
                Enabled                = $null
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = $null
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $false
            IncludeIntuneOnly      = $false
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices ([ordered] @{}))

        $candidates.Count | Should -Be 0
    }

    It 'treats missing operating system as out of scope when include filters are present' {
        $result = Test-CloudDeviceInventoryScope -OperatingSystem $null -IncludeOperatingSystem @('iOS*') -ExcludeOperatingSystem @() -Exclusions @()

        $result | Should -BeFalse
    }

    It 'can keep missing operating system and version values when explicitly allowed' {
        $result = Test-CloudDeviceInventoryScope -OperatingSystem $null -OperatingSystemVersion $null -IncludeOperatingSystem @('Windows*') -ExcludeOperatingSystem @() -IncludeOperatingSystemVersion @('10.0*') -ExcludeOperatingSystemVersion @() -IncludeUnknownOperatingSystem -IncludeUnknownOperatingSystemVersion -Exclusions @()

        $result | Should -BeTrue
    }

    It 'does not include Intune-only records in disable selection' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'Android-Orphan'
                EntraDeviceObjectId    = 'entra-6'
                DeviceId               = 'device-6'
                ManagedDeviceId        = 'managed-6'
                HasEntraRecord         = $true
                HasIntuneRecord        = $true
                RecordState            = 'IntuneOnly'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 300
                IntuneLastSeenDays     = 300
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
            'intune:managed-6' = [PSCustomObject] @{
                Action       = 'Retire'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-45)
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 0
    }

    It 'prefers managed device id when building cloud device keys' {
        $device = [PSCustomObject] @{
            Name               = 'Android-Duplicate'
            ManagedDeviceId    = 'managed-7'
            EntraDeviceObjectId = 'entra-7'
            DeviceId           = 'device-7'
        }

        $key = Get-CloudDeviceRecordKey -Device $device

        $key | Should -Be 'intune:managed-7'
    }

    It 'finds prior pending state when a managed record falls back to Entra keys' {
        $devices = @(
            [PSCustomObject] @{
                Name                   = 'iPhone-Staged'
                EntraDeviceObjectId    = 'entra-8'
                DeviceId               = 'device-8'
                ManagedDeviceId        = $null
                HasEntraRecord         = $true
                HasIntuneRecord        = $false
                RecordState            = 'EntraOnly'
                ManagedDeviceOwnerType = 'personal'
                EntraLastSeenDays      = 200
                IntuneLastSeenDays     = $null
                Enabled                = $false
            }
        )

        $actionIf = [ordered] @{
            LastSeenEntraMoreThan  = 180
            LastSeenIntuneMoreThan = $null
            ListProcessedMoreThan  = 30
            ExcludeCompanyOwned    = $true
            IncludeEntraOnly       = $true
            IncludeIntuneOnly      = $false
        }

        $processedDevices = [ordered] @{
            'intune:managed-8' = [PSCustomObject] @{
                Action              = 'Disable'
                ActionStatus        = 'True'
                ActionDate          = (Get-Date).AddDays(-45)
                ManagedDeviceId     = 'managed-8'
                EntraDeviceObjectId = 'entra-8'
                DeviceId            = 'device-8'
                ProcessedDeviceKeys = @('intune:managed-8', 'entra:entra-8', 'device:device-8')
            }
        }

        $candidates = @(Get-CloudDevicesToProcess -Type Delete -Devices $devices -ActionIf $actionIf -ProcessedDevices $processedDevices)

        $candidates.Count | Should -Be 1
        $candidates[0].ProcessedDeviceKey | Should -Be 'entra:entra-8'
        $candidates[0].MatchedProcessedDeviceKey | Should -Be 'intune:managed-8'
    }
}
