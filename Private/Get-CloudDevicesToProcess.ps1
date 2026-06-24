function Get-CloudDevicesToProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Retire', 'Disable', 'Delete', 'RemoveAutopilotIdentity')]
        [string] $Type,

        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ActionIf,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices
    )

    function Test-CloudDeviceValuePattern {
        param(
            [AllowNull()]
            [object[]] $Value,
            [AllowEmptyCollection()]
            [Array] $Include,
            [AllowEmptyCollection()]
            [Array] $Exclude
        )

        $values = @($Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
        if ($Include -and $Include.Count -gt 0) {
            $matched = $false
            foreach ($includePattern in $Include) {
                foreach ($deviceValue in $values) {
                    if ([string] $deviceValue -like $includePattern) {
                        $matched = $true
                        break
                    }
                }
                if ($matched) { break }
            }
            if (-not $matched) {
                return $false
            }
        }

        if ($Exclude -and $Exclude.Count -gt 0) {
            foreach ($excludePattern in $Exclude) {
                foreach ($deviceValue in $values) {
                    if ([string] $deviceValue -like $excludePattern) {
                        return $false
                    }
                }
            }
        }

        $true
    }

    function Test-CloudDeviceOwnerPresence {
        param([Parameter(Mandatory)] [object] $Device)

        $ownerValues = @(
            $Device.OwnerDisplayName
            $Device.OwnerUserPrincipalName
            $Device.IntuneUserDisplayName
            $Device.IntuneUserPrincipalName
            $Device.IntuneEmailAddress
            $Device.AutopilotUserPrincipalName
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }

        $ownerValues.Count -gt 0
    }

    function Test-CloudDeviceManagedState {
        param([Parameter(Mandatory)] [object] $Device)

        if ($Device.IsManaged -eq $true) {
            return $true
        }

        $managementValues = @($Device.ManagementType, $Device.ManagementAgent) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) -and [string] $_ -ne 'none' -and [string] $_ -ne 'unknown' }
        $managementValues.Count -gt 0
    }

    function Test-CloudDeviceMdmState {
        param([Parameter(Mandatory)] [object] $Device)

        $managementValues = @($Device.ManagementType, $Device.ManagementAgent) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }
        foreach ($managementValue in $managementValues) {
            if ([string] $managementValue -like '*mdm*' -or [string] $managementValue -like '*intune*') {
                return $true
            }
        }

        $false
    }

    function Get-CloudDeviceComplianceState {
        param([Parameter(Mandatory)] [object] $Device)

        if (-not [string]::IsNullOrWhiteSpace([string] $Device.ComplianceState)) {
            switch ([string] $Device.ComplianceState) {
                'compliant' { return 'Compliant' }
                { $_ -in @('noncompliant', 'inGracePeriod', 'configManager') } { return 'NonCompliant' }
                default { return 'Unknown' }
            }
        }

        if ($Device.IsCompliant -eq $true -or [string] $Device.ComplianceState -eq 'compliant') {
            return 'Compliant'
        }
        if ($Device.IsCompliant -eq $false -or [string] $Device.ComplianceState -in @('noncompliant', 'inGracePeriod', 'configManager')) {
            return 'NonCompliant'
        }

        'Unknown'
    }

    function Test-CloudDeviceAutopilotIntuneAssociationState {
        param(
            [Parameter(Mandatory)] [object] $Device,
            [string] $State
        )

        if (-not $State -or $State -eq 'Any') {
            return $true
        }

        $hasAssociation = -not [string]::IsNullOrWhiteSpace([string] $Device.AutopilotManagedDeviceId)
        if ($State -eq 'Missing') {
            return -not $hasAssociation
        }
        if ($State -eq 'Present') {
            return $hasAssociation
        }

        $true
    }

    function Test-CloudDeviceAutopilotEntraAssociationState {
        param(
            [Parameter(Mandatory)] [object] $Device,
            [string] $State
        )

        if (-not $State -or $State -eq 'Any') {
            return $true
        }

        $associationValue = [string] $Device.AutopilotResourceName
        $hasAssociation = -not [string]::IsNullOrWhiteSpace($associationValue) -or -not [string]::IsNullOrWhiteSpace([string] $Device.AutopilotAzureAdDeviceId)
        $serialNumber = [string] $Device.AutopilotSerialNumber
        if ($State -eq 'Missing') {
            return -not $hasAssociation
        }
        if ($State -eq 'Present') {
            return $hasAssociation
        }
        if ($State -eq 'EqualsSerialNumber') {
            return -not [string]::IsNullOrWhiteSpace($associationValue) -and -not [string]::IsNullOrWhiteSpace($serialNumber) -and $associationValue -eq $serialNumber
        }
        if ($State -eq 'NotEqualsSerialNumber') {
            return -not [string]::IsNullOrWhiteSpace($associationValue) -and -not [string]::IsNullOrWhiteSpace($serialNumber) -and $associationValue -ne $serialNumber
        }

        $true
    }

    Write-Color -Text '[i] ', "Applying following rules to $Type action:" -Color Yellow, Cyan, Green
    foreach ($key in $ActionIf.Keys) {
        if ($null -eq $ActionIf[$key] -or ($ActionIf[$key] -is [System.Array] -and $ActionIf[$key].Count -eq 0)) {
            Write-Color -Text '   [>] ', $key, ' is ', 'Not Set' -Color Yellow, Cyan, Yellow
        } else {
            Write-Color -Text '   [>] ', $key, ' is ', $ActionIf[$key] -Color Yellow, Cyan, Green
        }
    }

    $today = Get-Date
    $candidates = foreach ($device in $Devices) {
        $processedRecord = Find-ProcessedCloudDeviceRecord -Device $device -ProcessedDevices $ProcessedDevices
        $deviceKey = $processedRecord.CurrentDeviceKey
        $processedDevice = $processedRecord.ProcessedDevice
        $processedActionSucceeded = $false

        if ($processedDevice) {
            $processedActionSucceeded = $processedDevice.ActionStatus -is [bool] -and $processedDevice.ActionStatus
            if (-not $processedActionSucceeded) {
                $processedActionSucceeded = [string] $processedDevice.ActionStatus -eq 'True'
            }
        }

        if ($ActionIf.ExcludeCompanyOwned -and $device.ManagedDeviceOwnerType -eq 'company') {
            continue
        }

        if ($ActionIf.IntuneLinkState -and $ActionIf.IntuneLinkState -ne 'Any' -and $device.IntuneLinkState -ne $ActionIf.IntuneLinkState) {
            continue
        }

        if ($Type -eq 'Retire') {
            if (-not $device.HasIntuneRecord) {
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly' -and -not $ActionIf.IncludeIntuneOnly) {
                continue
            }
            if ($processedDevice -and $processedDevice.Action -eq 'Retire' -and $processedActionSucceeded) {
                continue
            }
        } elseif ($Type -eq 'Disable') {
            if (-not $device.HasEntraRecord -or $device.Enabled -ne $true) {
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly') {
                continue
            }
            if ($device.RecordState -eq 'EntraOnly' -and -not $ActionIf.IncludeEntraOnly) {
                continue
            }
        } elseif ($Type -eq 'Delete') {
            if (-not $device.HasEntraRecord -and -not $device.HasIntuneRecord) {
                continue
            }
            if ($device.HasEntraRecord -and $device.RecordState -ne 'IntuneOnly' -and $device.Enabled -ne $false) {
                continue
            }
            if ($device.RecordState -eq 'EntraOnly' -and -not $ActionIf.IncludeEntraOnly) {
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly' -and -not $ActionIf.IncludeIntuneOnly) {
                continue
            }
        } elseif ($Type -eq 'RemoveAutopilotIdentity') {
            if ($device.AutopilotOnboarded -ne $true -or [string]::IsNullOrWhiteSpace([string] $device.AutopilotDeviceId)) {
                continue
            }
        }

        if ($null -ne $ActionIf.ListProcessedMoreThan) {
            if (-not $processedDevice -or -not $processedDevice.ActionDate -or -not $processedActionSucceeded) {
                continue
            }

            $timeOnPendingList = (New-TimeSpan -Start $processedDevice.ActionDate -End $today).Days
            if ($timeOnPendingList -lt $ActionIf.ListProcessedMoreThan) {
                $processedDevice.TimeOnPendingList = $timeOnPendingList
                $processedDevice.TimeToNextAction = $ActionIf.ListProcessedMoreThan - $timeOnPendingList
                continue
            }

            if (-not (Test-CloudDevicePendingActivity -Device $device -ProcessedDevice $processedDevice)) {
                continue
            }
        }

        if ($null -ne $ActionIf.LastSeenEntraMoreThan) {
            if ($null -eq $device.EntraLastSeenDays) {
                if (-not $ActionIf.IncludeUnknownActivity) {
                    continue
                }
            } elseif ($device.EntraLastSeenDays -le $ActionIf.LastSeenEntraMoreThan) {
                continue
            }
        }

        if ($null -ne $ActionIf.LastSeenIntuneMoreThan) {
            if ($null -eq $device.IntuneLastSeenDays) {
                if (-not $ActionIf.IncludeUnknownActivity) {
                    continue
                }
            } elseif ($device.IntuneLastSeenDays -le $ActionIf.LastSeenIntuneMoreThan) {
                continue
            }
        }

        if ($null -ne $ActionIf.RegisteredMoreThan) {
            if ($null -eq $device.RegisteredDays -or $device.RegisteredDays -le $ActionIf.RegisteredMoreThan) {
                continue
            }
        }

        if ($null -ne $ActionIf.AutopilotLastContactMoreThan) {
            if ($null -eq $device.AutopilotLastContactedDays) {
                if (-not $ActionIf.IncludeUnknownActivity) {
                    continue
                }
            } elseif ($device.AutopilotLastContactedDays -le $ActionIf.AutopilotLastContactMoreThan) {
                continue
            }
        }

        if (-not (Test-CloudDeviceAutopilotIntuneAssociationState -Device $device -State $ActionIf.AutopilotIntuneAssociationState)) {
            continue
        }

        if (-not (Test-CloudDeviceAutopilotEntraAssociationState -Device $device -State $ActionIf.AutopilotEntraAssociationState)) {
            continue
        }

        if ($ActionIf.EnabledState -and $ActionIf.EnabledState -ne 'Any') {
            if ($ActionIf.EnabledState -eq 'Enabled' -and $device.Enabled -ne $true) {
                continue
            }
            if ($ActionIf.EnabledState -eq 'Disabled' -and $device.Enabled -ne $false) {
                continue
            }
            if ($ActionIf.EnabledState -eq 'Unknown' -and $null -ne $device.Enabled) {
                continue
            }
        }

        if ($ActionIf.AutopilotState -and $ActionIf.AutopilotState -ne 'Any') {
            if (-not $device.AutopilotInventoryLoaded) {
                continue
            }
            if ($ActionIf.AutopilotState -eq 'Onboarded' -and $device.AutopilotOnboarded -ne $true) {
                continue
            }
            if ($ActionIf.AutopilotState -eq 'NotOnboarded' -and $device.AutopilotOnboarded -ne $false) {
                continue
            }
        }

        if ($ActionIf.OwnerState -and $ActionIf.OwnerState -ne 'Any') {
            if ($ActionIf.OwnerState -eq 'WithoutOwner' -and $device.OperatingSystem -like 'Windows*' -and $device.AutopilotInventoryLoaded -ne $true) {
                continue
            }
            $hasOwner = Test-CloudDeviceOwnerPresence -Device $device
            if ($ActionIf.OwnerState -eq 'WithOwner' -and -not $hasOwner) {
                continue
            }
            if ($ActionIf.OwnerState -eq 'WithoutOwner' -and $hasOwner) {
                continue
            }
        }

        if ($ActionIf.ManagementState -and $ActionIf.ManagementState -ne 'Any') {
            $isManaged = Test-CloudDeviceManagedState -Device $device
            $isMdm = Test-CloudDeviceMdmState -Device $device
            if ($ActionIf.ManagementState -eq 'Managed' -and -not $isManaged) {
                continue
            }
            if ($ActionIf.ManagementState -eq 'Unmanaged' -and $isManaged) {
                continue
            }
            if ($ActionIf.ManagementState -eq 'Mdm' -and -not $isMdm) {
                continue
            }
            if ($ActionIf.ManagementState -eq 'NotMdm' -and $isMdm) {
                continue
            }
        }

        if ($ActionIf.ComplianceState -and $ActionIf.ComplianceState -ne 'Any') {
            if ((Get-CloudDeviceComplianceState -Device $device) -ne $ActionIf.ComplianceState) {
                continue
            }
        }

        if (-not (Test-CloudDeviceValuePattern -Value $device.ManagementAgent -Include $ActionIf.IncludeManagementAgent -Exclude $ActionIf.ExcludeManagementAgent)) {
            continue
        }

        if (-not (Test-CloudDeviceValuePattern -Value @($device.EnrollmentType, $device.DeviceEnrollmentType) -Include $ActionIf.IncludeEnrollmentType -Exclude $ActionIf.ExcludeEnrollmentType)) {
            continue
        }

        if (-not (Test-CloudDeviceValuePattern -Value $device.DeviceRegistrationState -Include $ActionIf.IncludeDeviceRegistrationState -Exclude $ActionIf.ExcludeDeviceRegistrationState)) {
            continue
        }

        $hasAutopilotGroupTagFilter = ($ActionIf.IncludeAutopilotGroupTag -and $ActionIf.IncludeAutopilotGroupTag.Count -gt 0) -or ($ActionIf.ExcludeAutopilotGroupTag -and $ActionIf.ExcludeAutopilotGroupTag.Count -gt 0)
        if ($hasAutopilotGroupTagFilter -and -not $device.AutopilotInventoryLoaded) {
            continue
        }

        if (-not (Test-CloudDeviceValuePattern -Value $device.AutopilotGroupTag -Include $ActionIf.IncludeAutopilotGroupTag -Exclude $ActionIf.ExcludeAutopilotGroupTag)) {
            continue
        }

        $candidate = $device | Select-Object *
        $selectionReason = Get-CloudDeviceSelectionReason -Device $device -Type $Type -ActionIf $ActionIf -ProcessedDevice $processedDevice
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'Action' -Value $Type -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'ProcessedDeviceKey' -Value $deviceKey -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'ProcessedDeviceKeys' -Value $processedRecord.CurrentDeviceKeys -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'MatchedProcessedDeviceKey' -Value $processedRecord.MatchedProcessedDeviceKey -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'TimeOnPendingList' -Value $(if ($processedDevice) { $processedDevice.TimeOnPendingList } else { $null }) -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'TimeToNextAction' -Value $(if ($processedDevice) { $processedDevice.TimeToNextAction } else { $null }) -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'SelectionReason' -Value $selectionReason -Force
        $candidate
    }

    @($candidates)
}
