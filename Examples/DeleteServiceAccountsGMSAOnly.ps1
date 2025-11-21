Import-Module .\CleanupMonster.psd1 -Force

# Example focused specifically on GMSA accounts only
$Configuration = @{
    Disable                                = $true
    DisableIsEnabled                       = $true
    DisablePasswordLastSetMoreThan         = 60 # More aggressive for GMSA
    DisableRequireWhenCreatedMoreThan      = 30
    DisableIncludeType                     = @('GMSA') # GMSA only
    DisableLimit                           = 5
    DisableModifyDescription               = $true
    DisableModifyAdminDescription          = $true

    Delete                                 = $true
    DeleteIsEnabled                        = $false
    DeletePasswordLastSetMoreThan          = 120 # More aggressive for GMSA
    DeleteRequireWhenCreatedMoreThan       = 60
    DeleteListProcessedMoreThan            = 60 # Shorter pending time for GMSA
    DeleteIncludeType                      = @('GMSA') # GMSA only
    DeleteLimit                            = 3

    Exclusions                             = @(
        '*OU=Critical GMSA*'
        '*OU=Production Services*'
        '*SQL*' # Exclude SQL service accounts
        '*Exchange*' # Exclude Exchange service accounts
        '*SharePoint*' # Exclude SharePoint service accounts
    )

    Filter                                 = '*'
    WhatIfDisable                          = $true
    WhatIfDelete                           = $true
    LogPath                                = "$PSScriptRoot\Logs\DeleteGMSA_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                          = "$PSScriptRoot\ProcessedGMSA.xml"
    ReportPath                             = "$PSScriptRoot\Reports\DeleteGMSA_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                               = $true

    RemoveProtectedFromAccidentalDeletionFlag = $true
}

Write-Host "Running GMSA-focused cleanup..." -ForegroundColor Yellow
Write-Host "This configuration targets only Group Managed Service Accounts (GMSA)" -ForegroundColor Cyan
Write-Host "with more aggressive timelines suitable for automated service accounts." -ForegroundColor Cyan
Write-Host ""

$Output = Invoke-ADServiceAccountsCleanup @Configuration

Write-Host ""
Write-Host "GMSA Cleanup Results:" -ForegroundColor Green
Write-Host "- GMSA Accounts Found: $($Output.Statistics.TotalGMSA)" -ForegroundColor Cyan
Write-Host "- GMSA to Disable: $($Output.Statistics.ToDisableGMSA)" -ForegroundColor $(if($Output.Statistics.ToDisableGMSA -gt 0){'Red'}else{'Green'})
Write-Host "- GMSA to Delete: $($Output.Statistics.ToDeleteGMSA)" -ForegroundColor $(if($Output.Statistics.ToDeleteGMSA -gt 0){'Red'}else{'Green'})

$Output
