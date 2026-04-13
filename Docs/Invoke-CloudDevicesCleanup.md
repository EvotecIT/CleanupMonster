---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version:
schema: 2.0.0
---

# Invoke-CloudDevicesCleanup

## SYNOPSIS
Stages cleanup for stale AzureAD registered mobile devices from Microsoft Entra ID and Intune.

## DESCRIPTION
`Invoke-CloudDevicesCleanup` is the cloud-side companion to AD computer cleanup.
It targets AzureAD registered mobile devices, builds a combined Entra and Intune inventory,
classifies records as matched or orphaned, and supports staged actions:

- `Retire` for Intune-managed devices
- `Disable` for Microsoft Entra device objects
- `Delete` for final record cleanup

The workflow keeps its own pending datastore so actions can be separated across multiple runs.

Orphan records are still discovered by default, but actioning them is intentionally explicit:

- `-RetireIncludeIntuneOnly`
- `-DisableIncludeEntraOnly`
- `-DeleteIncludeEntraOnly`
- `-DeleteIncludeIntuneOnly`

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

## NOTES

- Designed primarily for `iOS` and `Android` AzureAD registered devices.
- Inventory includes `Matched`, `EntraOnly`, and `IntuneOnly` record states.
- Default behavior excludes company-owned devices unless explicitly included.
