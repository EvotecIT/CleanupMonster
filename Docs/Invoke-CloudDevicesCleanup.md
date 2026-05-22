---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version:
schema: 2.0.0
---

# Invoke-CloudDevicesCleanup

## SYNOPSIS
Stages cleanup for stale Microsoft Entra and Intune cloud devices from Microsoft Entra ID and Intune.

## DESCRIPTION
`Invoke-CloudDevicesCleanup` is the cloud-side companion to AD computer cleanup.
It targets Microsoft Entra registered mobile devices by default, builds a combined Entra and Intune inventory,
classifies records as matched or orphaned, and supports staged actions:

- `Retire` for Intune-managed devices
- `Disable` for Microsoft Entra device objects
- `Delete` for final record cleanup

The workflow keeps its own pending datastore so actions can be separated across multiple runs.
Real successful retire and disable actions are stored in `PendingActions`; `-ReportOnly`,
top-level `-WhatIf`, and action-specific preview switches do not mutate pending cleanup state.

Orphan records are still discovered by default, but actioning them is intentionally explicit:

- `-RetireIncludeIntuneOnly`
- `-DisableIncludeEntraOnly`
- `-DeleteIncludeEntraOnly`
- `-DeleteIncludeIntuneOnly`

Destructive cloud cleanup treats missing Graph data as unsafe:

- blank activity timestamps are excluded from destructive action selection
- only `AzureAD registered` records are included by default; add `-IncludeJoinType 'AzureAD joined'` explicitly for Windows cloud-joined cleanup
- pending devices are not promoted if current inventory loses activity that existed when staged
- Entra-backed disable requires `Enabled -eq $true`
- Entra-backed delete requires `Enabled -eq $false`
- unknown Entra enabled state is excluded from disable/delete
- `-AutopilotState NotOnboarded` only matches when Autopilot inventory was loaded successfully
- `-DeleteAutopilotIdentity` requires Autopilot inventory and removes the Autopilot identity before Intune/Entra records

## EXAMPLES

### Example 1
```powershell
Invoke-CloudDevicesCleanup -Retire -ReportOnly -WhatIf -ShowHTML
```

Preview stale cloud-device candidates without making changes.

### Example 2
```powershell
Invoke-CloudDevicesCleanup `
    -Retire `
    -Disable `
    -Delete `
    -RetireLastSeenIntuneMoreThan 120 `
    -DisableListProcessedMoreThan 30 `
    -DeleteListProcessedMoreThan 30
```

Run the staged lifecycle for stale mobile devices with explicit grace periods.

### Example 3
```powershell
Invoke-CloudDevicesCleanup `
    -Retire `
    -Disable `
    -Delete `
    -WhatIf `
    -SafetyEntraLimit 1000 `
    -SafetyIntuneLimit 1000 `
    -ReportPath C:\Reports\CloudDevices.html `
    -ShowHTML
```

Preview all stages, stop on suspiciously low Graph inventory, and generate an HTML report.

### Example 4
```powershell
Invoke-CloudDevicesCleanup `
    -Delete `
    -WhatIfDelete `
    -IncludeJoinType 'AzureAD joined' `
    -IncludeOperatingSystem 'Windows*' `
    -DeleteLastSeenEntraMoreThan 180 `
    -DeleteRegisteredMoreThan 365 `
    -DeleteAutopilotIdentity `
    -AutopilotState Onboarded `
    -OwnerState WithoutOwner `
    -ManagementState Mdm `
    -ComplianceState NonCompliant `
    -EnabledState Disabled `
    -SafetyEntraLimit 1000 `
    -SafetyIntuneLimit 1000 `
    -ShowHTML
```

Preview deletion of disabled, old, inactive Windows cloud-joined devices that are Autopilot onboarded, MDM-managed, noncompliant, and have no owner, including the Autopilot identity delete sub-action.

### Example 5
```powershell
Invoke-CloudDevicesCleanup `
    -Disable `
    -WhatIfDisable `
    -IncludeJoinType 'AzureAD joined' `
    -IncludeOperatingSystem 'Windows*' `
    -IncludeOperatingSystemVersion '10.0.19045*' `
    -AutopilotState NotOnboarded `
    -OwnerState WithoutOwner `
    -DisableLastSeenEntraMoreThan 180 `
    -ShowHTML
```

Preview disabling Windows 10 22H2 cloud-joined devices that are inactive, ownerless, and confirmed not present in Autopilot inventory.

## NOTES

- Designed primarily for `iOS` and `Android` Microsoft Entra registered devices, with explicit opt-in filters for Windows and AzureAD joined devices.
- Inventory includes `Matched`, `EntraOnly`, and `IntuneOnly` record states.
- Default behavior excludes company-owned devices unless explicitly included.
- Autopilot identity removal is opt-in via `-DeleteAutopilotIdentity`; use `-WhatIfDelete` to preview the full delete stage.
- Use `-Confirm` when running interactively and keep `RetireLimit`, `DisableLimit`, and `DeleteLimit` low during rollout.
