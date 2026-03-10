<#
.SYNOPSIS
Switches a scheduled task to run under a gMSA.

.DESCRIPTION
Use this after validating that your cleanup automation should run under a
group managed service account instead of a normal user account.

Before running, confirm:
- the scheduled task name
- the gMSA name
- that the target host is allowed to use the gMSA
#>

schtasks /Change /TN Automation-CleanupComputers /RU "gmsa-cleanup$" /RP ""
