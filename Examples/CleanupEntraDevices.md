# Entra and Intune device cleanup

Use [CleanupEntraDevices.ps1](CleanupEntraDevices.ps1) as a separate daily job beside the existing AD/Jamf computer cleanup. It follows the same pattern: connect to Microsoft Graph, set one splat, and call CleanupMonster. The operating-system scope includes Windows, Android, iOS, iPadOS, and macOS. The existing AD/Jamf job does not need to change.

## Reuse the existing Graph app

Keep the existing job's `Connect-MgGraph -ClientSecretCredential` block in the private scheduled script. Set `$TenantId` in the example to that job's tenant GUID. Do not copy its encrypted secret into this repository. The example checks the connected tenant before reading inventory or taking action. There is no need for a new app registration or Azure subscription resource if the existing app can be used.

Check the existing app's Microsoft Graph **application permissions** and tenant admin consent:

| Permission | Needed for |
| --- | --- |
| `Device.ReadWrite.All` | Entra device disable and delete |
| `DeviceManagementManagedDevices.ReadWrite.All` | Intune managed-device inventory and final record removal |
| `DeviceManagementServiceConfig.ReadWrite.All` | Autopilot identity inventory and final removal |

Release GraphEssentials **0.0.65** first, then a CleanupMonster release **3.1.17 or newer** containing this change. Install both on the scheduled host before running this example. These versions provide fail-closed cloud inventory paging, stop ambiguous Autopilot matches, stop Entra deletion after an Intune deletion failure, and protect recently synced Intune devices. Earlier releases do not contain all of these changes.

## Run it like the old job

1. Keep the existing Graph connection and log/transcript setup. Create the example's report, log, and script folders if they do not exist. Use its **new cloud datastore path**, never the AD job's `CleanupComputers_ListProcessed.xml`.
2. The old job used inventory minimums of `20,000` Entra and `19,000` Intune. The cloud job counts selected join types, so these numbers may not fit. Check its reported counts and adjust the two limits to stable, current cloud baselines before actions. Check the operating-system values in the report, especially for Macs and iPads, and adjust the patterns if this tenant uses different labels. Add approved cloud exclusions and protected Autopilot group tags to the splat.
3. Leave `ReportOnly = $true` for the first 30 daily runs and review the reports. The supplied category counts add up to **37,600**, while the headline says **38,600**; reconcile this before enabling actions. Unknown activity and hybrid joined devices remain outside action scope.
4. To preview actions, set `ReportOnly = $false`, `WhatIfDisable = $true`, and `WhatIfDelete = $true`. Then start disabling with `WhatIfDisable = $false` while leaving `WhatIfDelete = $true`. Enable deletion only after reviewing recovery, duplicates, Autopilot associations, and the first disabled cohort.

The policy disables Entra joined or registered devices on the selected platforms after more than 90 days of known Entra inactivity and registration age. It deletes only after more than 180 days of both, and after a successful CleanupMonster disable has remained in the new datastore for more than 90 days. The old already-disabled backlog is not automatically promoted. Keep the datastore across runs; do not run overlapping instances.

This cloud cmdlet uses Entra and Intune inventory. In this example, **both** Entra activity and, when an Intune record exists, Intune last sync must be older than 90 days for disable and 180 days for delete. A matching Intune record with unknown last sync is excluded. Entra-only records still use the Entra threshold. The cmdlet does not query Jamf or delete Jamf records. A recent Jamf check-in will not block cloud actions for a Mac. The old AD cleanup job continues to use Jamf for its AD computer decisions. The Autopilot identity option applies only to Windows or records whose operating system is unknown.

If an Intune device cleanup rule is set to 90 days, remember that Microsoft describes it as **hiding** stale devices from the portal and reports. It does not replace this Entra cleanup policy or prove an Intune object was deleted. See [Intune device cleanup rules](https://learn.microsoft.com/en-us/intune/governance/configure-cleanup-rules) and [Microsoft Entra stale-device guidance](https://learn.microsoft.com/en-us/entra/identity/devices/manage-stale-devices).
