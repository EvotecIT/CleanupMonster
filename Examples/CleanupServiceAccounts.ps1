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
