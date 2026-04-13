function Get-InitialCloudDevices {
    [CmdletBinding()]
    param(
        [nullable[int]] $SafetyEntraLimit,
        [nullable[int]] $SafetyIntuneLimit,
        [Array] $IncludeOperatingSystem,
        [Array] $ExcludeOperatingSystem,
        [Array] $Exclusions
    )

    Write-Color -Text '[i] ', 'Getting AzureAD registered devices from Microsoft Entra ID' -Color Yellow, Cyan, Green
    [Array] $entraDevices = Get-MyDevice -Type 'AzureAD registered' -WarningAction SilentlyContinue -WarningVariable warningVar
    if ($warningVar) {
        Write-Color -Text '[e] ', 'Error getting devices from Microsoft Entra ID: ', $warningVar, ' Terminating!' -Color Yellow, Red, Yellow, Red
        return $false
    }

    if ($entraDevices.Count -eq 0) {
        if ($null -ne $SafetyEntraLimit -and $SafetyEntraLimit -gt 0) {
            Write-Color -Text '[e] ', 'Only ', $entraDevices.Count, ' devices found in Microsoft Entra ID, this is less than the safety limit of ', $SafetyEntraLimit, '. Terminating!' -Color Yellow, Cyan, Red, Cyan
            return $false
        }
        Write-Color -Text '[i] ', 'No AzureAD registered devices found in Microsoft Entra ID. Continuing with Intune inventory to discover orphan records.' -Color Yellow, Yellow
    } elseif ($null -ne $SafetyEntraLimit -and $entraDevices.Count -lt $SafetyEntraLimit) {
        Write-Color -Text '[e] ', 'Only ', $entraDevices.Count, ' devices found in Microsoft Entra ID, this is less than the safety limit of ', $SafetyEntraLimit, '. Terminating!' -Color Yellow, Cyan, Red, Cyan
        return $false
    }

    Write-Color -Text '[i] ', 'AzureAD registered devices found in Microsoft Entra ID: ', $entraDevices.Count -Color Yellow, Cyan, Green

    Write-Color -Text '[i] ', 'Getting AzureAD registered devices from Intune' -Color Yellow, Cyan, Green
    [Array] $intuneDevices = Get-MyDeviceIntune -Type 'AzureAD registered' -WarningAction SilentlyContinue -WarningVariable warningVar
    if ($warningVar) {
        Write-Color -Text '[e] ', 'Error getting devices from Intune: ', $warningVar, ' Terminating!' -Color Yellow, Red, Yellow, Red
        return $false
    }

    if ($null -ne $SafetyIntuneLimit -and $intuneDevices.Count -lt $SafetyIntuneLimit) {
        Write-Color -Text '[e] ', 'Only ', $intuneDevices.Count, ' devices found in Intune, this is less than the safety limit of ', $SafetyIntuneLimit, '. Terminating!' -Color Yellow, Cyan, Red, Cyan
        return $false
    }

    Write-Color -Text '[i] ', 'AzureAD registered devices found in Intune: ', $intuneDevices.Count -Color Yellow, Cyan, Green

    $intuneByAzureDeviceId = [ordered] @{}
    $matchedIntuneManagedDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($intuneDevice in $intuneDevices) {
        if ($intuneDevice.AzureAdDeviceId -and -not $intuneByAzureDeviceId.Contains($intuneDevice.AzureAdDeviceId)) {
            $intuneByAzureDeviceId[$intuneDevice.AzureAdDeviceId] = $intuneDevice
        }
    }

    $outputDevices = [System.Collections.Generic.List[object]]::new()
    foreach ($entraDevice in $entraDevices) {
        $operatingSystem = $entraDevice.OperatingSystem
        $deviceInScope = Test-CloudDeviceInventoryScope -OperatingSystem $operatingSystem -IncludeOperatingSystem $IncludeOperatingSystem -ExcludeOperatingSystem $ExcludeOperatingSystem -Exclusions $Exclusions -Name $entraDevice.Name -DeviceId $entraDevice.DeviceId -EntraDeviceObjectId $entraDevice.EntraDeviceObjectId
        if (-not $deviceInScope) {
            continue
        }

        $intuneDevice = if ($entraDevice.DeviceId -and $intuneByAzureDeviceId.Contains($entraDevice.DeviceId)) {
            $intuneByAzureDeviceId[$entraDevice.DeviceId]
        } else {
            $null
        }

        if ($intuneDevice -and $intuneDevice.ManagedDeviceId) {
            $null = $matchedIntuneManagedDeviceIds.Add($intuneDevice.ManagedDeviceId)
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
            Enabled                 = $entraDevice.Enabled
            OperatingSystem         = if ($intuneDevice -and $intuneDevice.OperatingSystem) { $intuneDevice.OperatingSystem } else { $entraDevice.OperatingSystem }
            OperatingSystemVersion  = if ($intuneDevice -and $intuneDevice.OperatingSystemVersion) { $intuneDevice.OperatingSystemVersion } else { $entraDevice.OperatingSystemVersion }
            TrustType               = $entraDevice.TrustType
            EntraLastSeen           = $entraDevice.LastSeen
            EntraLastSeenDays       = $entraDevice.LastSeenDays
            IntuneLastSeen          = if ($intuneDevice) { $intuneDevice.LastSeen } else { $null }
            IntuneLastSeenDays      = if ($intuneDevice) { $intuneDevice.LastSeenDays } else { $null }
            FirstSeen               = $entraDevice.FirstSeen
            IsManaged               = $entraDevice.IsManaged
            IsCompliant             = $entraDevice.IsCompliant
            ManagementType          = $entraDevice.ManagementType
            EnrollmentType          = $entraDevice.EnrollmentType
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
            SelectionReason         = $null
        })
    }

    foreach ($intuneDevice in $intuneDevices) {
        if ($intuneDevice.ManagedDeviceId -and $matchedIntuneManagedDeviceIds.Contains($intuneDevice.ManagedDeviceId)) {
            continue
        }

        $operatingSystem = $intuneDevice.OperatingSystem
        $deviceInScope = Test-CloudDeviceInventoryScope -OperatingSystem $operatingSystem -IncludeOperatingSystem $IncludeOperatingSystem -ExcludeOperatingSystem $ExcludeOperatingSystem -Exclusions $Exclusions -Name $intuneDevice.Name -DeviceId $intuneDevice.AzureAdDeviceId -ManagedDeviceId $intuneDevice.ManagedDeviceId
        if (-not $deviceInScope) {
            continue
        }

        $outputDevices.Add([PSCustomObject] [ordered] @{
            Name                    = $intuneDevice.Name
            EntraDeviceObjectId     = $intuneDevice.EntraDeviceObjectId
            DeviceId                = $intuneDevice.AzureAdDeviceId
            ManagedDeviceId         = $intuneDevice.ManagedDeviceId
            HasEntraRecord          = [bool] $intuneDevice.EntraDeviceObjectId
            HasIntuneRecord         = $true
            RecordState             = 'IntuneOnly'
            RecordSource            = 'Intune only'
            Enabled                 = $null
            OperatingSystem         = $intuneDevice.OperatingSystem
            OperatingSystemVersion  = $intuneDevice.OperatingSystemVersion
            TrustType               = 'AzureAD registered'
            EntraLastSeen           = $null
            EntraLastSeenDays       = $null
            IntuneLastSeen          = $intuneDevice.LastSeen
            IntuneLastSeenDays      = $intuneDevice.LastSeenDays
            FirstSeen               = $intuneDevice.FirstSeen
            IsManaged               = $true
            IsCompliant             = $null
            ManagementType          = $null
            EnrollmentType          = $null
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
            SelectionReason         = $null
        })
    }

    @($outputDevices)
}
