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
The cmdlet defaults to single-object safety limits unless you explicitly increase or remove them.

## EXAMPLES

### EXAMPLE 1
```powershell
$Output = Invoke-ADServiceAccountsCleanup -Disable -Delete -DisableLastLogonDateMoreThan 90 -DeleteLastLogonDateMoreThan 180 -ReportOnly
```

Review the service accounts that would be actioned without making changes.

### EXAMPLE 2
```powershell
$invokeADServiceAccountsCleanupSplat = @{
    Disable                        = $true
    DisableLastLogonDateMoreThan   = 90
    DisablePasswordLastSetMoreThan = 90
    DisableLimit                   = 2

    Delete                         = $true
    DeleteLastLogonDateMoreThan    = 180
    DeletePasswordLastSetMoreThan  = 180
    DeleteLimit                    = 1

    SafetyADLimit                  = 10
    IncludeAccounts                = @('gmsa-*', 'msa-*')
    ExcludeAccounts                = @('gmsa-keep-*')
    WhatIfDisable                  = $true
    WhatIfDelete                   = $true
}

$Output = Invoke-ADServiceAccountsCleanup @invokeADServiceAccountsCleanupSplat
```

Run a staged cleanup with explicit AD safety thresholds and per-action limits.

## KEY PARAMETERS

### -DisableLimit
Limit the number of service accounts disabled in a single run.
`0` means unlimited.
Default is `1`.

### -DeleteLimit
Limit the number of service accounts deleted in a single run.
`0` means unlimited.
Default is `1`.

### -SafetyADLimit
Stop processing if fewer than the expected number of service accounts are returned from AD.

### -IncludeAccounts
Filter the candidate set to matching `SamAccountName` values.
Wildcards are supported.

### -ExcludeAccounts
Exclude matching `SamAccountName` values from processing.
Wildcards are supported.
