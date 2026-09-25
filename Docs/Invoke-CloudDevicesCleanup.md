---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version: https://github.com/EvotecIT/CleanupMonster
schema: 2.0.0
---
# Invoke-CloudDevicesCleanup
## SYNOPSIS
Cleans up stale Microsoft Entra registered cloud devices.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-CloudDevicesCleanup [[-RetireLastSeenIntuneMoreThan] <Int32>] [[-RetireLastSeenEntraMoreThan] <Int32>] [[-RetireRegisteredMoreThan] <Int32>] [[-RetireLimit] <int>] [[-DisableLastSeenEntraMoreThan] <Int32>] [[-DisableLastSeenIntuneMoreThan] <Int32>] [[-DisableRegisteredMoreThan] <Int32>] [[-DisableListProcessedMoreThan] <Int32>] [[-DisableLimit] <int>] [[-StageDisabledForDeleteLimit] <int>] [[-DeleteLastSeenEntraMoreThan] <Int32>] [[-DeleteLastSeenIntuneMoreThan] <Int32>] [[-DeleteRegisteredMoreThan] <Int32>] [[-DeleteListProcessedMoreThan] <Int32>] [[-DeleteLimit] <int>] [[-DeleteRemoveIntuneRecord] <bool>] [[-RemoveAutopilotIdentityLastContactMoreThan] <Int32>] [[-RemoveAutopilotIdentityIntuneAssociationState] <string>] [[-RemoveAutopilotIdentityEntraAssociationState] <string>] [[-RemoveAutopilotIdentityLimit] <int>] [[-IncludeJoinType] <string[]>] [[-IncludeOperatingSystem] <array>] [[-ExcludeOperatingSystem] <array>] [[-IncludeOperatingSystemVersion] <array>] [[-ExcludeOperatingSystemVersion] <array>] [[-IntuneLinkState] <string>] [[-AutopilotState] <string>] [[-OwnerState] <string>] [[-ManagementState] <string>] [[-ComplianceState] <string>] [[-EnabledState] <string>] [[-IncludeManagementAgent] <array>] [[-ExcludeManagementAgent] <array>] [[-IncludeEnrollmentType] <array>] [[-ExcludeEnrollmentType] <array>] [[-IncludeDeviceRegistrationState] <array>] [[-ExcludeDeviceRegistrationState] <array>] [[-IncludeAutopilotGroupTag] <array>] [[-ExcludeAutopilotGroupTag] <array>] [[-Exclusions] <array>] [[-PreserveDuplicateDeviceNames] <bool>] [[-DataStorePath] <string>] [[-LogPath] <string>] [[-LogMaximum] <int>] [[-LogTimeFormat] <string>] [[-ReportPath] <string>] [[-SafetyEntraLimit] <Int32>] [[-SafetyIntuneLimit] <Int32>] [-Retire] [-RetireIncludeIntuneOnly] [-Disable] [-DisableIncludeEntraOnly] [-StageDisabledForDelete] [-Delete] [-DeleteIncludeEntraOnly] [-DeleteIncludeIntuneOnly] [-DeleteAutopilotIdentity] [-RemoveAutopilotIdentity] [-IncludeUnknownOperatingSystem] [-IncludeUnknownOperatingSystemVersion] [-IncludeUnknownActivity] [-ProtectRecentIntuneActivity] [-IncludeCompanyOwned] [-ReportOnly] [-WhatIfRetire] [-WhatIfDisable] [-WhatIfStageDelete] [-WhatIfDelete] [-WhatIfRemoveAutopilotIdentity] [-LogShowTime] [-Suppress] [-ShowHTML] [-Online] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Handles staged cleanup for Microsoft Entra and Intune cloud device records.
The default operating-system scope is iOS and Android because these are the
intended mobile-device cleanup targets, but the scope can be changed with
IncludeOperatingSystem and ExcludeOperatingSystem.

The workflow supports three explicit stages:
- Retire: retires stale Intune managed devices.
- Disable: disables stale Microsoft Entra devices after matching criteria or pending-list age.
- Delete: removes stale Microsoft Entra devices and, by default, eligible Intune records.
- RemoveAutopilotIdentity: removes stale Windows Autopilot identities without deleting Entra or Intune records.

The cmdlet keeps a datastore with PendingActions and History so staged actions
can be reviewed over multiple runs. ReportOnly shows candidates without writing
updated cleanup state. WhatIf and action-specific WhatIf modes save attempted
previews in History, but do not add them to PendingActions.

Same-name Windows Autopilot and hybrid/cloud-join duplicate groups are preserved
from destructive cloud actions by default. This protects the by-design duplicate
Entra objects created during Windows Autopilot Microsoft Entra hybrid deployments.
Use PreserveDuplicateDeviceNames:$false only after reviewing the duplicate group.

Blank activity timestamps are intentionally excluded from destructive actions by default.
This follows Microsoft guidance for stale-device cleanup where activity timestamps can be empty
even for active devices.
Hybrid Azure AD joined, Azure AD joined, synchronized, non-registered, and unknown registration
records are excluded by default. Use IncludeJoinType to opt in to supported joined-device cleanup paths,
and use Invoke-ADComputersCleanup for hybrid Active Directory device lifecycle cleanup.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-CloudDevicesCleanup -Retire -ReportOnly -ShowHTML
```

Builds a report of Intune retire candidates using the default stale threshold without changing devices or cleanup state.

### EXAMPLE 2
```powershell
PS > Invoke-CloudDevicesCleanup -Retire -Disable -Delete -RetireLastSeenIntuneMoreThan 120 -DisableListProcessedMoreThan 30 -DeleteListProcessedMoreThan 30
```

Runs the full staged workflow: retire stale Intune devices, disable pending devices after 30 days, and delete pending devices after 30 days.

### EXAMPLE 3
```powershell
PS > Invoke-CloudDevicesCleanup -Retire -Disable -Delete -WhatIf -SafetyEntraLimit 1000 -SafetyIntuneLimit 1000 -ReportPath C:\Reports\CloudDevices.html -ShowHTML
```

Previews all enabled stages, requires minimum inventory counts, writes an HTML report, and opens it for review.

### EXAMPLE 4
```powershell
PS > Invoke-CloudDevicesCleanup -Delete -DeleteIncludeIntuneOnly -DeleteRemoveIntuneRecord $true -DeleteLastSeenIntuneMoreThan 180 -WhatIfDelete
```

Previews cleanup of stale Intune-only orphan records without deleting anything or updating the pending-action datastore.

### EXAMPLE 5
```powershell
PS > Invoke-CloudDevicesCleanup -RemoveAutopilotIdentity -IncludeJoinType 'AzureAD joined','AzureAD registered' -IncludeOperatingSystem '*' -IncludeUnknownOperatingSystem -RemoveAutopilotIdentityIntuneAssociationState Missing -RemoveAutopilotIdentityLastContactMoreThan 90 -WhatIfRemoveAutopilotIdentity -ShowHTML
```

Previews removing stale Windows Autopilot identities whose associated Intune managed-device id is missing.

### EXAMPLE 6
```powershell
PS > Invoke-CloudDevicesCleanup -Disable -DisableIncludeEntraOnly -DisableListProcessedMoreThan $null -IntuneLinkState Broken -DisableLastSeenEntraMoreThan 90 -IncludeJoinType 'AzureAD joined','AzureAD registered' -IncludeOperatingSystem '*' -IncludeUnknownOperatingSystem -WhatIfDisable -ShowHTML
```

Previews disabling Entra devices older than 90 days that claim Intune/MDM management but have no matching Intune managed-device record.

### EXAMPLE 7
```powershell
PS > $cloudCleanup = Invoke-CloudDevicesCleanup -Disable -DisableLastSeenEntraMoreThan 180 -IncludeOperatingSystem 'Android*' -ExcludeOperatingSystem '*Dedicated*' -Confirm
$cloudCleanup.CurrentRun | Format-Table Name, Action, ActionStatus, ActionDate
```

Disables matching Android Entra-backed devices after confirmation and reviews the current run.

## PARAMETERS

### -AutopilotState
Filters action candidates by Windows Autopilot inventory state: Any, Onboarded, or NotOnboarded.
NotOnboarded only matches when Autopilot inventory was loaded successfully.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Onboarded, NotOnboarded

Required: False
Position: 26
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComplianceState
Filters action candidates by compliance state: Any, Compliant, NonCompliant, or Unknown.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Compliant, NonCompliant, Unknown

Required: False
Position: 29
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -DataStorePath
Path to the XML datastore that tracks PendingActions and History.
Defaults to ProcessedCloudDevices.xml next to this function.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 41
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Delete
Enables the final delete stage.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteAutopilotIdentity
Removes Windows Autopilot device identities before deleting Intune or Entra records.
When enabled, Autopilot inventory must load successfully. If an onboarded device cannot
have its Autopilot identity removed, the Intune and Entra record delete sub-actions are skipped.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIncludeEntraOnly
Allows delete-stage processing of Entra-only orphan records.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIncludeIntuneOnly
Allows delete-stage processing of Intune-only orphan records.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastSeenEntraMoreThan
Delete devices only when the Entra LastSeenDays value is greater than this number.
Entra-backed devices must have Enabled equal to $false; unknown enabled state is treated as unsafe.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastSeenIntuneMoreThan
Delete devices only when the Intune LastSeenDays value is greater than this number.
Devices with blank Intune activity are not selected by this criterion.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 11
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLimit
Maximum number of devices to delete in one run. 0 means unlimited. Default is 10.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 14
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteListProcessedMoreThan
Delete devices only after they were previously actioned and remained pending longer than this number of days.
Defaults to 30 days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 13
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteRegisteredMoreThan
Delete devices only when the device registration/enrollment age is greater than this number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteRemoveIntuneRecord
Controls whether delete-stage processing also removes eligible Intune managed-device records.
Defaults to $true.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 15
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -Disable
Enables the Microsoft Entra disable stage.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIncludeEntraOnly
Allows disable-stage processing of Entra-only records.
By default, Entra-only records are discovered and reported but not actioned.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastSeenEntraMoreThan
Disable devices only when the Entra LastSeenDays value is greater than this number.
Entra-backed devices must have Enabled equal to $true; unknown enabled state is treated as unsafe.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastSeenIntuneMoreThan
Disable devices only when the Intune LastSeenDays value is greater than this number.
Devices with blank Intune activity are not selected by this criterion.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLimit
Maximum number of devices to disable in one run. 0 means unlimited. Default is 10.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 8
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableListProcessedMoreThan
Disable devices only after they were previously actioned and remained pending longer than this number of days.
Defaults to 30 days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 7
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableRegisteredMoreThan
Disable devices only when the device registration/enrollment age is greater than this number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnabledState
Filters action candidates by Microsoft Entra enabled state: Any, Enabled, Disabled, or Unknown.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Enabled, Disabled, Unknown

Required: False
Position: 30
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeAutopilotGroupTag
Autopilot group-tag patterns to exclude for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 38
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeDeviceRegistrationState
Intune device-registration-state patterns to exclude for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 36
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeEnrollmentType
Enrollment-type patterns to exclude for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 34
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeManagementAgent
Management-agent patterns to exclude for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 32
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeOperatingSystem
Operating-system patterns to exclude when building cloud-device inventory.
Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 22
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeOperatingSystemVersion
Operating-system version patterns to exclude when building cloud-device inventory.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 24
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclusions
Device names, Entra object IDs, Intune managed-device IDs, or other supported identifiers to exclude from cleanup.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 39
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeAutopilotGroupTag
Autopilot group-tag patterns to include for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 37
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeCompanyOwned
Includes company-owned devices in candidate selection. By default company-owned devices are excluded from actions.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeDeviceRegistrationState
Intune device-registration-state patterns to include for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 35
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeEnrollmentType
Enrollment-type patterns to include for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 33
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeJoinType
Microsoft Entra join-type values to include when building cloud-device inventory.
Defaults to AzureAD registered. Add AzureAD joined explicitly for Windows cloud-joined cleanup.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Hybrid AzureAD, AzureAD joined, AzureAD registered, Not available

Required: False
Position: 20
Default value: @('AzureAD registered')
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeManagementAgent
Management-agent patterns to include for action candidates. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 31
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeOperatingSystem
Operating-system patterns to include when building cloud-device inventory.
Defaults to iOS and Android patterns. Wildcards are supported.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 21
Default value: @('iOS*', 'Android*')
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeOperatingSystemVersion
Operating-system version patterns to include when building cloud-device inventory.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 23
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeUnknownActivity
Allows blank Entra and Intune activity timestamps to satisfy configured LastSeen*MoreThan filters.
By default, unknown activity is treated as unsafe and excluded from destructive action selection.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeUnknownOperatingSystem
Allows records with blank operating-system values to remain in inventory.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeUnknownOperatingSystemVersion
Allows records with blank operating-system-version values when version filters are set.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -IntuneLinkState
Filters action candidates by the relationship between Microsoft Entra MDM metadata and Intune managed-device inventory.
Broken means the Entra device claims Intune/MDM management but no matching Intune managed-device record exists.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Healthy, Broken, NotClaimed, IntuneOnly

Required: False
Position: 25
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogMaximum
Maximum number of rotated log files to keep. Default is 5.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 43
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
Path to a log file. Summary lines show the configured inventory scope, OS and correlation counts, Entra activity age bands, and the mix of selected candidates for each enabled action.
Action entries include only attempted device IDs and outcomes, plus a per-stage count of candidates left without an action result.
When omitted, file logging is not enabled.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 42
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogShowTime
Includes timestamps in log output.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogTimeFormat
Date/time format used when LogShowTime is enabled.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 44
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ManagementState
Filters action candidates by management state: Any, Managed, Unmanaged, Mdm, or NotMdm.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Managed, Unmanaged, Mdm, NotMdm

Required: False
Position: 28
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -Online
Uses CDN-hosted CSS and JavaScript assets for the HTML report, reducing report file size.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -OwnerState
Filters action candidates by owner presence: Any, WithOwner, or WithoutOwner.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, WithOwner, WithoutOwner

Required: False
Position: 27
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -PreserveDuplicateDeviceNames
Preserves same-name Windows Autopilot and hybrid/cloud-join duplicate groups from retire, disable, delete, and standalone Autopilot identity removal.
Defaults to $true.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 40
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProtectRecentIntuneActivity
For disable and delete stages with an Entra last-seen threshold, also require any matching
Intune record to have a known last sync older than that stage's threshold. Entra-only
records remain eligible using the Entra threshold.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveAutopilotIdentity
Removes selected Windows Autopilot device identities without deleting matching Intune or Entra records.
Defaults to requiring a missing associated Intune managed-device id and a last-contact age greater than 90 days.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveAutopilotIdentityEntraAssociationState
Filters Autopilot identity removal by the Autopilot associated Microsoft Entra device value.
EqualsSerialNumber and NotEqualsSerialNumber compare the Autopilot resource/display name with the Autopilot serial number.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Missing, Present, EqualsSerialNumber, NotEqualsSerialNumber

Required: False
Position: 18
Default value: Any
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveAutopilotIdentityIntuneAssociationState
Filters Autopilot identity removal by the Autopilot associated Intune managed-device id.
Defaults to Missing.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Any, Missing, Present

Required: False
Position: 17
Default value: Missing
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveAutopilotIdentityLastContactMoreThan
Removes Autopilot identities only when the Autopilot LastContacted age is greater than this number of days.
Defaults to 90 days. Blank Autopilot last-contact values are excluded unless IncludeUnknownActivity is set.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 16
Default value: 90
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveAutopilotIdentityLimit
Maximum number of Autopilot identities to remove in one run. 0 means unlimited. Default is 10.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 19
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportOnly
Generates inventory and reports without executing retire, disable, or delete actions and without writing updated cleanup state.
Existing pending actions are still read so staged candidates can be reported accurately.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportPath
Path where the HTML report is written.
Defaults to ProcessedCloudDevices.html next to this function.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 45
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Retire
Enables the Intune retire stage.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetireIncludeIntuneOnly
Allows retire-stage processing of Intune-only orphan records.
By default, orphan Intune records are discovered and reported but not actioned.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetireLastSeenEntraMoreThan
Retire devices only when the Entra LastSeenDays value is greater than this number.
Devices with blank Entra activity are not selected by this criterion.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetireLastSeenIntuneMoreThan
Retire devices only when the Intune LastSeenDays value is greater than this number.
Defaults to 120 days. Devices with blank Intune activity are not selected by this criterion.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 0
Default value: 120
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetireLimit
Maximum number of devices to retire in one run. 0 means unlimited. Default is 10.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 3
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetireRegisteredMoreThan
Retire devices only when the device registration/enrollment age is greater than this number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyEntraLimit
Stops processing if the Entra inventory count is below this value.
Use this as a guard against partial Graph inventory responses.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 46
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyIntuneLimit
Stops processing if the Intune inventory count is below this value.
Use this as a guard against partial Graph inventory responses.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 47
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowHTML
Opens the generated HTML report after the run.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -StageDisabledForDelete
Adds already-disabled delete candidates to PendingActions without deleting them.
Use this for daily automation where pre-disabled stale devices should wait the
same DeleteListProcessedMoreThan grace period as devices disabled by CleanupMonster.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -StageDisabledForDeleteLimit
Maximum number of already-disabled devices to stage for later delete in one run.
0 means unlimited. Default is 10.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 9
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -Suppress
Suppresses returning the export object to the pipeline.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDelete
Previews delete actions only. Attempted previews are saved in History, not PendingActions.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDisable
Previews disable actions only. Attempted previews are saved in History, not PendingActions.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfRemoveAutopilotIdentity
Previews standalone Autopilot identity removal only. Attempted previews are saved in History, not PendingActions.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfRetire
Previews retire actions only. Attempted previews are saved in History, not PendingActions.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfStageDelete
Previews staging already-disabled delete candidates. Attempted previews are saved in History, not PendingActions.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
