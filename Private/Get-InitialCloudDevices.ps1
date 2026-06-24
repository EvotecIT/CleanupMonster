function Get-InitialCloudDevices {
    [CmdletBinding()]
    param(
        [nullable[int]] $SafetyEntraLimit,
        [nullable[int]] $SafetyIntuneLimit,
        [ValidateSet('Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', 'Not available')]
        [string[]] $IncludeJoinType = @('AzureAD registered'),
        [Array] $IncludeOperatingSystem,
        [Array] $ExcludeOperatingSystem,
        [Array] $IncludeOperatingSystemVersion = @(),
        [Array] $ExcludeOperatingSystemVersion = @(),
        [switch] $IncludeUnknownOperatingSystem,
        [switch] $IncludeUnknownOperatingSystemVersion,
        [Array] $Exclusions,
        [switch] $IncludeAutopilotInventory
    )

    $getAgeDays = {
        param([AllowNull()] $DateValue)

        if ($DateValue) {
            [math]::Floor((New-TimeSpan -Start $DateValue -End (Get-Date)).TotalDays)
        } else {
            $null
        }
    }

    $getFirstPropertyValue = {
        param(
            [AllowEmptyCollection()]
            [object[]] $InputObject,
            [string[]] $Name
        )

        foreach ($source in $InputObject) {
            $value = Get-CloudDevicePropertyValue -InputObject $source -Name $Name
            if (-not [string]::IsNullOrWhiteSpace([string] $value)) {
                return $value
            }
        }

        $null
    }

    $getFirstNonNullPropertyValue = {
        param(
            [AllowEmptyCollection()]
            [object[]] $InputObject,
            [string[]] $Name
        )

        foreach ($source in $InputObject) {
            $value = Get-CloudDevicePropertyValue -InputObject $source -Name $Name
            if ($null -ne $value) {
                return $value
            }
        }

        $null
    }

    $testIntuneManagementClaim = {
        param([AllowNull()] $Device)

        if (-not $Device) {
            return $false
        }

        if ($Device.IsManaged -eq $true) {
            return $true
        }

        $managementValues = @(
            Get-CloudDevicePropertyValue -InputObject $Device -Name 'ManagementType'
            Get-CloudDevicePropertyValue -InputObject $Device -Name 'ManagementAgent'
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }

        foreach ($managementValue in $managementValues) {
            if ([string] $managementValue -like '*mdm*' -or [string] $managementValue -like '*intune*') {
                return $true
            }
        }

        $false
    }

    [Array] $entraJoinType = @($IncludeJoinType | Where-Object { $_ -ne 'Not available' })
    [Array] $entraDevices = @()
    if ($entraJoinType.Count -gt 0) {
        Write-Color -Text '[i] ', 'Getting cloud devices from Microsoft Entra ID for join types: ', ($entraJoinType -join ', ') -Color Yellow, Cyan, Green
        $entraParameters = @{
            Type            = $entraJoinType
            WarningAction   = 'SilentlyContinue'
            WarningVariable = 'warningVar'
        }
        if ($IncludeAutopilotInventory) {
            $entraParameters.IncludeAutopilotInventory = $true
        }
        $warningVar = $null
        [Array] $entraDevices = Get-MyDevice @entraParameters
        if ($warningVar) {
            Write-Color -Text '[e] ', 'Error getting devices from Microsoft Entra ID: ', $warningVar, ' Terminating!' -Color Yellow, Red, Yellow, Red
            return $false
        }

        if ($entraDevices.Count -eq 0) {
            if ($null -ne $SafetyEntraLimit -and $SafetyEntraLimit -gt 0) {
                Write-Color -Text '[e] ', 'Only ', $entraDevices.Count, ' devices found in Microsoft Entra ID, this is less than the safety limit of ', $SafetyEntraLimit, '. Terminating!' -Color Yellow, Cyan, Red, Cyan
                return $false
            }
            Write-Color -Text '[i] ', 'No scoped devices found in Microsoft Entra ID. Continuing with Intune inventory to discover orphan records.' -Color Yellow, Yellow
        } elseif ($null -ne $SafetyEntraLimit -and $entraDevices.Count -lt $SafetyEntraLimit) {
            Write-Color -Text '[e] ', 'Only ', $entraDevices.Count, ' devices found in Microsoft Entra ID, this is less than the safety limit of ', $SafetyEntraLimit, '. Terminating!' -Color Yellow, Cyan, Red, Cyan
            return $false
        }
    } else {
        Write-Color -Text '[i] ', 'Skipping Microsoft Entra ID inventory because requested join type is only Not available. Continuing with Intune inventory.' -Color Yellow, Yellow
    }

    Write-Color -Text '[i] ', 'Cloud devices found in Microsoft Entra ID: ', $entraDevices.Count -Color Yellow, Cyan, Green

    $includeIntuneJoinType = @($IncludeJoinType + 'Not available') | Select-Object -Unique
    Write-Color -Text '[i] ', 'Getting cloud devices from Intune for join types: ', ($includeIntuneJoinType -join ', ') -Color Yellow, Cyan, Green
    $intuneParameters = @{
        Type          = $includeIntuneJoinType
        WarningAction = 'SilentlyContinue'
        WarningVariable = 'warningVar'
    }
    if ($IncludeAutopilotInventory) {
        $intuneParameters.IncludeAutopilotInventory = $true
    }
    [Array] $intuneDevices = Get-MyDeviceIntune @intuneParameters
    if ($warningVar) {
        Write-Color -Text '[e] ', 'Error getting devices from Intune: ', $warningVar, ' Terminating!' -Color Yellow, Red, Yellow, Red
        return $false
    }

    if ($null -ne $SafetyIntuneLimit -and $intuneDevices.Count -lt $SafetyIntuneLimit) {
        Write-Color -Text '[e] ', 'Only ', $intuneDevices.Count, ' devices found in Intune, this is less than the safety limit of ', $SafetyIntuneLimit, '. Terminating!' -Color Yellow, Cyan, Red, Cyan
        return $false
    }

    Write-Color -Text '[i] ', 'Cloud devices found in Intune: ', $intuneDevices.Count -Color Yellow, Cyan, Green

    $intuneByAzureDeviceId = [ordered] @{}
    $matchedIntuneManagedDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($intuneDevice in $intuneDevices) {
        if ($intuneDevice.AzureAdDeviceId -and -not $intuneByAzureDeviceId.Contains($intuneDevice.AzureAdDeviceId)) {
            $intuneByAzureDeviceId[$intuneDevice.AzureAdDeviceId] = $intuneDevice
        }
    }

    $outputDevices = [System.Collections.Generic.List[object]]::new()
    foreach ($entraDevice in $entraDevices) {
        if (-not (Test-CloudDeviceRegistrationScope -Device $entraDevice -IncludeJoinType $IncludeJoinType)) {
            continue
        }

        $intuneDevice = if ($entraDevice.DeviceId -and $intuneByAzureDeviceId.Contains($entraDevice.DeviceId)) {
            $intuneByAzureDeviceId[$entraDevice.DeviceId]
        } else {
            $null
        }

        $operatingSystem = if ($intuneDevice -and $intuneDevice.OperatingSystem) {
            $intuneDevice.OperatingSystem
        } else {
            $entraDevice.OperatingSystem
        }
        $operatingSystemVersion = if ($intuneDevice -and $intuneDevice.OperatingSystemVersion) {
            $intuneDevice.OperatingSystemVersion
        } else {
            $entraDevice.OperatingSystemVersion
        }
        $deviceInScope = Test-CloudDeviceInventoryScope -OperatingSystem $operatingSystem -OperatingSystemVersion $operatingSystemVersion -IncludeOperatingSystem $IncludeOperatingSystem -ExcludeOperatingSystem $ExcludeOperatingSystem -IncludeOperatingSystemVersion $IncludeOperatingSystemVersion -ExcludeOperatingSystemVersion $ExcludeOperatingSystemVersion -IncludeUnknownOperatingSystem:$IncludeUnknownOperatingSystem -IncludeUnknownOperatingSystemVersion:$IncludeUnknownOperatingSystemVersion -Exclusions $Exclusions -Name $entraDevice.Name -DeviceId $entraDevice.DeviceId -EntraDeviceObjectId $entraDevice.EntraDeviceObjectId -ManagedDeviceId $(if ($intuneDevice) { $intuneDevice.ManagedDeviceId } else { $null })
        if (-not $deviceInScope) {
            continue
        }

        if ($intuneDevice -and $intuneDevice.ManagedDeviceId) {
            $null = $matchedIntuneManagedDeviceIds.Add($intuneDevice.ManagedDeviceId)
        }

        $entraRegisteredDays = & $getAgeDays $entraDevice.FirstSeen
        $intuneRegisteredDays = if ($intuneDevice) { & $getAgeDays $intuneDevice.FirstSeen } else { $null }
        $autopilotInventoryLoaded = & $getFirstNonNullPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotInventoryLoaded'
        $autopilotOnboarded = & $getFirstNonNullPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotOnboarded'
        $claimsIntuneManagement = & $testIntuneManagementClaim $entraDevice
        $intuneLinkState = if ($intuneDevice) {
            'Healthy'
        } elseif ($claimsIntuneManagement) {
            'Broken'
        } else {
            'NotClaimed'
        }

        $outputDevices.Add([PSCustomObject] [ordered] @{
            Name                    = $entraDevice.Name
            EntraDeviceObjectId     = $entraDevice.EntraDeviceObjectId
            DeviceId                = $entraDevice.DeviceId
            ManagedDeviceId         = if ($intuneDevice) { $intuneDevice.ManagedDeviceId } else { $null }
            HasEntraRecord          = $true
            HasIntuneRecord         = [bool] $intuneDevice
            RecordState             = if ($intuneDevice) { 'Matched' } else { 'EntraOnly' }
            RecordSource            = if ($intuneDevice) { 'Microsoft Entra ID + Intune' } else { 'Microsoft Entra ID only' }
            IntuneLinkState         = $intuneLinkState
            ClaimsIntuneManagement  = $claimsIntuneManagement
            Enabled                 = $entraDevice.Enabled
            OperatingSystem         = if ($intuneDevice -and $intuneDevice.OperatingSystem) { $intuneDevice.OperatingSystem } else { $entraDevice.OperatingSystem }
            OperatingSystemVersion  = $operatingSystemVersion
            TrustType               = $entraDevice.TrustType
            EntraLastSeen           = $entraDevice.LastSeen
            EntraLastSeenDays       = $entraDevice.LastSeenDays
            IntuneLastSeen          = if ($intuneDevice) { $intuneDevice.LastSeen } else { $null }
            IntuneLastSeenDays      = if ($intuneDevice) { $intuneDevice.LastSeenDays } else { $null }
            FirstSeen               = $entraDevice.FirstSeen
            RegisteredDays          = if ($null -ne $entraRegisteredDays) { $entraRegisteredDays } else { $intuneRegisteredDays }
            EntraRegisteredDays     = $entraRegisteredDays
            IntuneRegisteredDays    = $intuneRegisteredDays
            IsManaged               = $entraDevice.IsManaged
            IsCompliant             = $entraDevice.IsCompliant
            ManagementType          = $entraDevice.ManagementType
            EnrollmentType          = $entraDevice.EnrollmentType
            DeviceEnrollmentType    = if ($intuneDevice) { $intuneDevice.DeviceEnrollmentType } else { $null }
            OwnerDisplayName        = $entraDevice.OwnerDisplayName
            OwnerUserPrincipalName  = $entraDevice.OwnerUserPrincipalName
            IntuneUserDisplayName   = if ($intuneDevice) { $intuneDevice.UserDisplayName } else { $null }
            IntuneUserPrincipalName = if ($intuneDevice) { $intuneDevice.UserPrincipalName } else { $null }
            IntuneEmailAddress      = if ($intuneDevice) { $intuneDevice.EmailAddress } else { $null }
            ManagedDeviceOwnerType  = if ($intuneDevice) { $intuneDevice.ManagedDeviceOwnerType } else { $null }
            DeviceRegistrationState = if ($intuneDevice) { $intuneDevice.DeviceRegistrationState } else { $null }
            AzureAdRegistered       = if ($intuneDevice) { $intuneDevice.AzureAdRegistered } else { $null }
            ComplianceState         = if ($intuneDevice) { $intuneDevice.ComplianceState } else { $null }
            ManagementAgent         = if ($intuneDevice) { $intuneDevice.ManagementAgent } else { $null }
            AutopilotInventoryLoaded = $autopilotInventoryLoaded
            AutopilotOnboarded      = $autopilotOnboarded
            AutopilotDeviceId       = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotDeviceId'
            AutopilotManagedDeviceId = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotManagedDeviceId'
            AutopilotAzureAdDeviceId = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotAzureAdDeviceId'
            AutopilotResourceName   = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotResourceName'
            AutopilotGroupTag       = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotGroupTag'
            AutopilotSerialNumber   = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotSerialNumber'
            AutopilotEnrollmentState = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotEnrollmentState'
            AutopilotLastContacted  = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotLastContacted'
            AutopilotLastContactedDays = & $getFirstNonNullPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotLastContactedDays'
            AutopilotUserPrincipalName = & $getFirstPropertyValue -InputObject @($intuneDevice, $entraDevice) -Name 'AutopilotUserPrincipalName'
            SelectionReason         = $null
        })
    }

    foreach ($intuneDevice in $intuneDevices) {
        if (-not (Test-CloudDeviceRegistrationScope -Device $intuneDevice -IncludeJoinType $IncludeJoinType)) {
            continue
        }

        if ($intuneDevice.ManagedDeviceId -and $matchedIntuneManagedDeviceIds.Contains($intuneDevice.ManagedDeviceId)) {
            continue
        }

        $operatingSystem = $intuneDevice.OperatingSystem
        $deviceInScope = Test-CloudDeviceInventoryScope -OperatingSystem $operatingSystem -OperatingSystemVersion $intuneDevice.OperatingSystemVersion -IncludeOperatingSystem $IncludeOperatingSystem -ExcludeOperatingSystem $ExcludeOperatingSystem -IncludeOperatingSystemVersion $IncludeOperatingSystemVersion -ExcludeOperatingSystemVersion $ExcludeOperatingSystemVersion -IncludeUnknownOperatingSystem:$IncludeUnknownOperatingSystem -IncludeUnknownOperatingSystemVersion:$IncludeUnknownOperatingSystemVersion -Exclusions $Exclusions -Name $intuneDevice.Name -DeviceId $intuneDevice.AzureAdDeviceId -EntraDeviceObjectId $intuneDevice.EntraDeviceObjectId -ManagedDeviceId $intuneDevice.ManagedDeviceId
        if (-not $deviceInScope) {
            continue
        }

        $intuneRegisteredDays = & $getAgeDays $intuneDevice.FirstSeen

        $outputDevices.Add([PSCustomObject] [ordered] @{
            Name                    = $intuneDevice.Name
            EntraDeviceObjectId     = $intuneDevice.EntraDeviceObjectId
            DeviceId                = $intuneDevice.AzureAdDeviceId
            ManagedDeviceId         = $intuneDevice.ManagedDeviceId
            HasEntraRecord          = [bool] $intuneDevice.EntraDeviceObjectId
            HasIntuneRecord         = $true
            RecordState             = 'IntuneOnly'
            RecordSource            = 'Intune only'
            IntuneLinkState         = 'IntuneOnly'
            ClaimsIntuneManagement  = $true
            Enabled                 = $null
            OperatingSystem         = $intuneDevice.OperatingSystem
            OperatingSystemVersion  = $intuneDevice.OperatingSystemVersion
            TrustType               = Get-CloudDeviceJoinTypeFromRegistrationState -DeviceRegistrationState $intuneDevice.DeviceRegistrationState
            EntraLastSeen           = $null
            EntraLastSeenDays       = $null
            IntuneLastSeen          = $intuneDevice.LastSeen
            IntuneLastSeenDays      = $intuneDevice.LastSeenDays
            FirstSeen               = $intuneDevice.FirstSeen
            RegisteredDays          = $intuneRegisteredDays
            EntraRegisteredDays     = $null
            IntuneRegisteredDays    = $intuneRegisteredDays
            IsManaged               = $true
            IsCompliant             = $null
            ManagementType          = $null
            EnrollmentType          = $null
            DeviceEnrollmentType    = $intuneDevice.DeviceEnrollmentType
            OwnerDisplayName        = $null
            OwnerUserPrincipalName  = $null
            IntuneUserDisplayName   = $intuneDevice.UserDisplayName
            IntuneUserPrincipalName = $intuneDevice.UserPrincipalName
            IntuneEmailAddress      = $intuneDevice.EmailAddress
            ManagedDeviceOwnerType  = $intuneDevice.ManagedDeviceOwnerType
            DeviceRegistrationState = $intuneDevice.DeviceRegistrationState
            AzureAdRegistered       = $intuneDevice.AzureAdRegistered
            ComplianceState         = $intuneDevice.ComplianceState
            ManagementAgent         = $intuneDevice.ManagementAgent
            AutopilotInventoryLoaded = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotInventoryLoaded'
            AutopilotOnboarded      = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotOnboarded'
            AutopilotDeviceId       = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotDeviceId'
            AutopilotManagedDeviceId = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotManagedDeviceId'
            AutopilotAzureAdDeviceId = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotAzureAdDeviceId'
            AutopilotResourceName   = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotResourceName'
            AutopilotGroupTag       = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotGroupTag'
            AutopilotSerialNumber   = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotSerialNumber'
            AutopilotEnrollmentState = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotEnrollmentState'
            AutopilotLastContacted  = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotLastContacted'
            AutopilotLastContactedDays = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotLastContactedDays'
            AutopilotUserPrincipalName = Get-CloudDevicePropertyValue -InputObject $intuneDevice -Name 'AutopilotUserPrincipalName'
            SelectionReason         = $null
        })
    }

    @($outputDevices)
}
