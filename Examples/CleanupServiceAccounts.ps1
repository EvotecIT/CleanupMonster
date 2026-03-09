Import-Module .\CleanupMonster.psd1 -Force

$invokeADServiceAccountsCleanupSplat = @{
    Disable                      = $true
    DisableLastLogonDateMoreThan = 90

    Delete                       = $true
    DeleteLastLogonDateMoreThan  = 180

    IncludeAccounts              = @('gmsa-*', 'msa-*')
    ExcludeAccounts              = @('gmsa-keep-*')
    ReportPath                   = "$PSScriptRoot\Reports\ServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    WhatIfDisable                = $true
    WhatIfDelete                 = $true
}

# The same service account will not be disabled and deleted in the same run.
$Output = Invoke-ADServiceAccountsCleanup @invokeADServiceAccountsCleanupSplat
$Output
