<#
.SYNOPSIS
Safer service-account cleanup with explicit selectors and low limits.

.DESCRIPTION
This example targets managed service accounts using:
- explicit include/exclude patterns
- separate disable and delete criteria
- low action limits
- WhatIf previews

Use this as the starting point for gMSA/MSA hygiene. It is intentionally
safer than a broad destructive run.

Before running for real, review:
- IncludeAccounts and ExcludeAccounts filters
- disable/delete age thresholds
- limits and report path
- WhatIf settings
#>

Import-Module .\CleanupMonster.psd1 -Force

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
    ReportPath                     = "$PSScriptRoot\Reports\ServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    WhatIfDisable                  = $true
    WhatIfDelete                   = $true
}

# The same service account will not be disabled and deleted in the same run.
$Output = Invoke-ADServiceAccountsCleanup @invokeADServiceAccountsCleanupSplat
$Output
