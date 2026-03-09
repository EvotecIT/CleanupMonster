---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version:
schema: 2.0.0
---

# Invoke-ADServiceAccountsCleanup

## SYNOPSIS
Clean up stale Active Directory service accounts.

## DESCRIPTION
Enumerates managed service accounts in Active Directory and can disable or delete them based on inactivity or age criteria.
Disable and delete selections are staged so the same account is not actioned twice in one run.

## EXAMPLES

### EXAMPLE 1
```powershell
$Output = Invoke-ADServiceAccountsCleanup -Disable -Delete -DisableLastLogonDateMoreThan 90 -DeleteLastLogonDateMoreThan 180 -ReportOnly
```

Review the service accounts that would be actioned without making changes.

### EXAMPLE 2
```powershell
$Output = Invoke-ADServiceAccountsCleanup -Disable -Delete -DisableLastLogonDateMoreThan 90 -DeleteLastLogonDateMoreThan 180 -WhatIfDisable -WhatIfDelete -ReportPath "$PSScriptRoot\Reports\ServiceAccounts.html"
```

Run a staged review where matching accounts stay in the disable stage instead of being disabled and deleted in the same invocation.
