---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version:
schema: 2.0.0
---

# Invoke-CloudDevicesCleanup

## SYNOPSIS
Stages cleanup for stale Microsoft Entra registered mobile devices from Microsoft Entra ID and Intune.

## DESCRIPTION
`Invoke-CloudDevicesCleanup` is the cloud-side companion to AD computer cleanup.
It targets Microsoft Entra registered mobile devices, builds a combined Entra and Intune inventory,
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
- hybrid Azure AD joined, Azure AD joined, synchronized, non-registered, and unknown registration states are excluded; use `Invoke-ADComputersCleanup` for hybrid device lifecycle cleanup
- pending devices are not promoted if current inventory loses activity that existed when staged
- Entra-backed disable requires `Enabled -eq $true`
- Entra-backed delete requires `Enabled -eq $false`
- unknown Entra enabled state is excluded from disable/delete

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

## NOTES

- Designed primarily for `iOS` and `Android` Microsoft Entra registered devices.
- Inventory includes `Matched`, `EntraOnly`, and `IntuneOnly` record states.
- Default behavior excludes company-owned devices unless explicitly included.
- Use `-Confirm` when running interactively and keep `RetireLimit`, `DisableLimit`, and `DeleteLimit` low during rollout.
