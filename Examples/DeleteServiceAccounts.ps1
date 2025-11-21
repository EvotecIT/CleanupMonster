Import-Module .\CleanupMonster.psd1 -Force

# Run the script for MSA/GMSA cleanup
$Configuration = @{
    Disable                                = $true
    DisableIsEnabled                       = $true
    DisablePasswordLastSetMoreThan         = 90
    DisableRequireWhenCreatedMoreThan      = 30
    DisableIncludeType                     = @('MSA', 'GMSA')
    DisableLimit                           = 2 # 0 means unlimited, ignored for reports
    DisableModifyDescription               = $false
    DisableModifyAdminDescription          = $true

    Delete                                 = $true
    DeleteIsEnabled                        = $false
    DeletePasswordLastSetMoreThan          = 180
    DeleteRequireWhenCreatedMoreThan       = 90
    DeleteListProcessedMoreThan            = 90 # 90 days since service account was added to list
    DeleteIncludeType                      = @('MSA', 'GMSA')
    DeleteLimit                            = 2 # 0 means unlimited, ignored for reports

    Exclusions                             = @(
        '*OU=Protected Service Accounts*'
        '*Critical*'
        'EVOMONSTER-GMSA$'
        'Important-MSA$'
    )

    Filter                                 = '*'
    WhatIfDisable                          = $true
    WhatIfDelete                           = $true
    LogPath                                = "$PSScriptRoot\Logs\DeleteServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                          = "$PSScriptRoot\ProcessedServiceAccounts.xml"
    ReportPath                             = "$PSScriptRoot\Reports\DeleteServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                               = $true

    RemoveProtectedFromAccidentalDeletionFlag = $true
}

# Run one time as admin: Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupServiceAccounts'
$Output = Invoke-ADServiceAccountsCleanup @Configuration
$Output
