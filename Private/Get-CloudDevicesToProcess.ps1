function Get-CloudDevicesToProcess {
    <#
    .SYNOPSIS
    Selects action candidates and optionally records the first unmet rule for each device.
    .DESCRIPTION
    Decisions describe this stage before action limits and confirmation. Recording them
    does not change selection, pending-state checks, or candidate ordering.
    #>
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
        [System.Collections.IDictionary] $ProcessedDevices,

        [System.Collections.Generic.List[object]] $Decisions
    )

    function Add-CloudDeviceDecision {
        param([string] $Classification, [string] $Reason)

        if ($null -eq $Decisions) { return }
        $Decisions.Add([pscustomobject] @{
            EntraDeviceObjectId = $device.EntraDeviceObjectId
            ManagedDeviceId = $device.ManagedDeviceId
            DeviceId = $device.DeviceId
            AutopilotDeviceId = $device.AutopilotDeviceId
            ProcessedDeviceKey = $deviceKey
            MatchedProcessedDeviceKey = $processedRecord.MatchedProcessedDeviceKey
            Classification = $Classification
            Reason = $Reason
        })
    }

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
        $hasAssociation = -not [string]::IsNullOrWhiteSpace([string] $Device.AutopilotAzureAdDeviceId)
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

    function Test-CloudDeviceDuplicateNameProtection {
        param([Parameter(Mandatory)] [object] $Device)

        if ($ActionIf.PreserveDuplicateDeviceNames -ne $true) {
            return $false
        }

        if ($Device.PSObject.Properties['PreserveDuplicateNameGroup'] -and $Device.PreserveDuplicateNameGroup -eq $true) {
            return $true
        }

        $false
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
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'Company-owned devices are excluded.'
            continue
        }

        if (Test-CloudDeviceDuplicateNameProtection -Device $device) {
            Add-CloudDeviceDecision -Classification 'Protected' -Reason "Duplicate-name protection: $($device.DuplicateNameProtectionReason)"
            continue
        }

        if ($Type -in @('Disable', 'Delete', 'RemoveAutopilotIdentity') -and $device.IntuneMatchAmbiguous) {
            Add-CloudDeviceDecision -Classification 'Protected' -Reason 'The Intune match is ambiguous.'
            continue
        }

        if ($ActionIf.IntuneLinkState -and $ActionIf.IntuneLinkState -ne 'Any' -and $device.IntuneLinkState -ne $ActionIf.IntuneLinkState) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason "Intune link is $($device.IntuneLinkState); requires $($ActionIf.IntuneLinkState)."
            continue
        }

        if ($Type -eq 'Retire') {
            if (-not $device.HasIntuneRecord) {
                Add-CloudDeviceDecision -Classification 'Not applicable' -Reason 'No Intune record to retire.'
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly' -and -not $ActionIf.IncludeIntuneOnly) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'Intune-only devices are not included in this stage.'
                continue
            }
            if ($processedDevice -and $processedDevice.Action -eq 'Retire' -and $processedActionSucceeded) {
                Add-CloudDeviceDecision -Classification 'Already processed' -Reason 'Retire already completed and is recorded as pending.'
                continue
            }
        } elseif ($Type -eq 'Disable') {
            if (-not $device.HasEntraRecord -or $device.Enabled -ne $true) {
                Add-CloudDeviceDecision -Classification 'Not applicable' -Reason 'Disable requires an Entra record with Enabled = Yes.'
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly') {
                Add-CloudDeviceDecision -Classification 'Not applicable' -Reason 'Intune-only devices have no Entra record to disable.'
                continue
            }
            if ($device.RecordState -eq 'EntraOnly' -and -not $ActionIf.IncludeEntraOnly) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'Entra-only devices are not included in this stage.'
                continue
            }
        } elseif ($Type -eq 'Delete') {
            if (-not $device.HasEntraRecord -and -not $device.HasIntuneRecord) {
                Add-CloudDeviceDecision -Classification 'Not applicable' -Reason 'No Entra or Intune record to delete.'
                continue
            }
            if ($device.HasEntraRecord -and $device.RecordState -ne 'IntuneOnly' -and $device.Enabled -ne $false) {
                Add-CloudDeviceDecision -Classification 'Not applicable' -Reason 'Delete requires the Entra device to be disabled first.'
                continue
            }
            if ($device.RecordState -eq 'EntraOnly' -and -not $ActionIf.IncludeEntraOnly) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'Entra-only devices are not included in this stage.'
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly' -and -not $ActionIf.IncludeIntuneOnly) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'Intune-only devices are not included in this stage.'
                continue
            }
        } elseif ($Type -eq 'RemoveAutopilotIdentity') {
            if ([string] $device.OperatingSystem -notlike 'Windows*' -or
                $device.AutopilotMatchAmbiguous -eq $true -or
                $device.AutopilotOnboarded -ne $true -or
                [string]::IsNullOrWhiteSpace([string] $device.AutopilotDeviceId)) {
                Add-CloudDeviceDecision -Classification 'Not applicable' -Reason 'Autopilot removal requires an unambiguous onboarded Windows identity.'
                continue
            }
        }

        if ($null -ne $ActionIf.ListProcessedMoreThan) {
            if (-not $processedDevice -or -not $processedDevice.ActionDate -or -not $processedActionSucceeded) {
                Add-CloudDeviceDecision -Classification 'Waiting for previous stage' -Reason 'A successfully completed previous action and pending date are required.'
                continue
            }

            $timeOnPendingList = (New-TimeSpan -Start $processedDevice.ActionDate -End $today).Days
            if ($timeOnPendingList -lt $ActionIf.ListProcessedMoreThan) {
                $processedDevice.TimeOnPendingList = $timeOnPendingList
                $processedDevice.TimeToNextAction = $ActionIf.ListProcessedMoreThan - $timeOnPendingList
                Add-CloudDeviceDecision -Classification 'Waiting for pending period' -Reason "Pending for $timeOnPendingList days; requires at least $($ActionIf.ListProcessedMoreThan) days."
                continue
            }

            if (-not (Test-CloudDevicePendingActivity -Device $device -ProcessedDevice $processedDevice)) {
                Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Activity resumed, is unknown, or does not agree with the pending action.'
                continue
            }
        }

        if ($null -ne $ActionIf.LastSeenEntraMoreThan) {
            if ($null -eq $device.EntraLastSeenDays) {
                if (-not $ActionIf.IncludeUnknownActivity) {
                    Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Entra activity is unknown and unknown activity is not included.'
                    continue
                }
            } elseif ($device.EntraLastSeenDays -le $ActionIf.LastSeenEntraMoreThan) {
                Add-CloudDeviceDecision -Classification 'Not required' -Reason "Entra inactivity is $($device.EntraLastSeenDays) days; requires more than $($ActionIf.LastSeenEntraMoreThan) days."
                continue
            }
        }

        if ($null -ne $ActionIf.LastSeenIntuneMoreThan) {
            if ($null -eq $device.IntuneLastSeenDays) {
                if (-not $ActionIf.IncludeUnknownActivity) {
                    Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Intune activity is unknown and unknown activity is not included.'
                    continue
                }
            } elseif ($device.IntuneLastSeenDays -le $ActionIf.LastSeenIntuneMoreThan) {
                Add-CloudDeviceDecision -Classification 'Not required' -Reason "Intune inactivity is $($device.IntuneLastSeenDays) days; requires more than $($ActionIf.LastSeenIntuneMoreThan) days."
                continue
            }
        }

        if ($null -ne $ActionIf.IntuneStaleWhenPresentMoreThan -and $device.HasIntuneRecord) {
            if ($null -eq $device.IntuneLastSeenDays -or $device.IntuneLastSeenDays -le $ActionIf.IntuneStaleWhenPresentMoreThan) {
                Add-CloudDeviceDecision -Classification 'Protected' -Reason "Recent-Intune protection requires known Intune inactivity greater than $($ActionIf.IntuneStaleWhenPresentMoreThan) days."
                continue
            }
        }

        if ($null -ne $ActionIf.RegisteredMoreThan) {
            if ($null -eq $device.RegisteredDays -or $device.RegisteredDays -le $ActionIf.RegisteredMoreThan) {
                if ($null -eq $device.RegisteredDays) {
                    Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Registration age is unknown; the registration requirement cannot be verified.'
                } else {
                    Add-CloudDeviceDecision -Classification 'Not required' -Reason "Registration age is $($device.RegisteredDays) days; requires more than $($ActionIf.RegisteredMoreThan) days."
                }
                continue
            }
        }

        if ($null -ne $ActionIf.AutopilotLastContactMoreThan) {
            if ($null -eq $device.AutopilotLastContactedDays) {
                if (-not $ActionIf.IncludeUnknownActivity) {
                    Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Autopilot contact age is unknown and unknown activity is not included.'
                    continue
                }
            } elseif ($device.AutopilotLastContactedDays -le $ActionIf.AutopilotLastContactMoreThan) {
                Add-CloudDeviceDecision -Classification 'Not required' -Reason "Autopilot contact age is $($device.AutopilotLastContactedDays) days; requires more than $($ActionIf.AutopilotLastContactMoreThan) days."
                continue
            }
        }

        if (-not (Test-CloudDeviceAutopilotIntuneAssociationState -Device $device -State $ActionIf.AutopilotIntuneAssociationState)) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason "Autopilot Intune association does not match $($ActionIf.AutopilotIntuneAssociationState)."
            continue
        }

        if (-not (Test-CloudDeviceAutopilotEntraAssociationState -Device $device -State $ActionIf.AutopilotEntraAssociationState)) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason "Autopilot Entra association does not match $($ActionIf.AutopilotEntraAssociationState)."
            continue
        }

        if ($ActionIf.EnabledState -and $ActionIf.EnabledState -ne 'Any') {
            if ($ActionIf.EnabledState -eq 'Enabled' -and $device.Enabled -ne $true) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The enabled-state filter requires Enabled = Yes.'
                continue
            }
            if ($ActionIf.EnabledState -eq 'Disabled' -and $device.Enabled -ne $false) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The enabled-state filter requires Enabled = No.'
                continue
            }
            if ($ActionIf.EnabledState -eq 'Unknown' -and $null -ne $device.Enabled) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The enabled-state filter requires unknown enabled state.'
                continue
            }
        }

        if ($ActionIf.AutopilotState -and $ActionIf.AutopilotState -ne 'Any') {
            if (-not $device.AutopilotInventoryLoaded) {
                Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Autopilot inventory was not loaded for the configured filter.'
                continue
            }
            if ($ActionIf.AutopilotState -eq 'Onboarded' -and $device.AutopilotOnboarded -ne $true) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The Autopilot filter requires an onboarded device.'
                continue
            }
            if ($ActionIf.AutopilotState -eq 'NotOnboarded' -and $device.AutopilotOnboarded -ne $false) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The Autopilot filter requires a device that is not onboarded.'
                continue
            }
        }

        if ($ActionIf.OwnerState -and $ActionIf.OwnerState -ne 'Any') {
            if ($ActionIf.OwnerState -eq 'WithoutOwner' -and $device.OperatingSystem -like 'Windows*' -and $device.AutopilotInventoryLoaded -ne $true) {
                Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Autopilot inventory is required to verify that this Windows device has no owner.'
                continue
            }
            $hasOwner = Test-CloudDeviceOwnerPresence -Device $device
            if ($ActionIf.OwnerState -eq 'WithOwner' -and -not $hasOwner) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The owner filter requires a device with an owner.'
                continue
            }
            if ($ActionIf.OwnerState -eq 'WithoutOwner' -and $hasOwner) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The owner filter requires a device without an owner.'
                continue
            }
        }

        if ($ActionIf.ManagementState -and $ActionIf.ManagementState -ne 'Any') {
            $isManaged = Test-CloudDeviceManagedState -Device $device
            $isMdm = Test-CloudDeviceMdmState -Device $device
            if ($ActionIf.ManagementState -eq 'Managed' -and -not $isManaged) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The management filter requires a managed device.'
                continue
            }
            if ($ActionIf.ManagementState -eq 'Unmanaged' -and $isManaged) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The management filter requires an unmanaged device.'
                continue
            }
            if ($ActionIf.ManagementState -eq 'Mdm' -and -not $isMdm) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The management filter requires MDM management.'
                continue
            }
            if ($ActionIf.ManagementState -eq 'NotMdm' -and $isMdm) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The management filter excludes MDM management.'
                continue
            }
        }

        if ($ActionIf.ComplianceState -and $ActionIf.ComplianceState -ne 'Any') {
            if ((Get-CloudDeviceComplianceState -Device $device) -ne $ActionIf.ComplianceState) {
                Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason "Compliance does not match $($ActionIf.ComplianceState)."
                continue
            }
        }

        if (-not (Test-CloudDeviceValuePattern -Value $device.ManagementAgent -Include $ActionIf.IncludeManagementAgent -Exclude $ActionIf.ExcludeManagementAgent)) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The management agent does not match the configured include/exclude filters.'
            continue
        }

        if (-not (Test-CloudDeviceValuePattern -Value @($device.EnrollmentType, $device.DeviceEnrollmentType) -Include $ActionIf.IncludeEnrollmentType -Exclude $ActionIf.ExcludeEnrollmentType)) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The enrollment type does not match the configured include/exclude filters.'
            continue
        }

        if (-not (Test-CloudDeviceValuePattern -Value $device.DeviceRegistrationState -Include $ActionIf.IncludeDeviceRegistrationState -Exclude $ActionIf.ExcludeDeviceRegistrationState)) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The registration state does not match the configured include/exclude filters.'
            continue
        }

        $hasAutopilotGroupTagFilter = ($ActionIf.IncludeAutopilotGroupTag -and $ActionIf.IncludeAutopilotGroupTag.Count -gt 0) -or ($ActionIf.ExcludeAutopilotGroupTag -and $ActionIf.ExcludeAutopilotGroupTag.Count -gt 0)
        if ($hasAutopilotGroupTagFilter -and -not $device.AutopilotInventoryLoaded) {
            Add-CloudDeviceDecision -Classification 'Protected' -Reason 'Autopilot inventory was not loaded to verify the group tag.'
            continue
        }

        if (-not (Test-CloudDeviceValuePattern -Value $device.AutopilotGroupTag -Include $ActionIf.IncludeAutopilotGroupTag -Exclude $ActionIf.ExcludeAutopilotGroupTag)) {
            Add-CloudDeviceDecision -Classification 'Excluded by setting' -Reason 'The Autopilot group tag does not match the configured include/exclude filters.'
            continue
        }

        $candidate = $device | Select-Object *
        $selectionReason = Get-CloudDeviceSelectionReason -Device $device -Type $Type -ActionIf $ActionIf -ProcessedDevice $processedDevice
        Add-CloudDeviceDecision -Classification 'Selected by rules' -Reason $selectionReason
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
