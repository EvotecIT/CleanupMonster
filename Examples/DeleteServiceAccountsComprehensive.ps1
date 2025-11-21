Import-Module .\CleanupMonster.psd1 -Force

# Configuration for comprehensive cleanup
$Configuration = @{
    # Disable Configuration
    Disable                                = $true
    DisableIsEnabled                       = $true
    DisablePasswordLastSetMoreThan         = 90
    DisableRequireWhenCreatedMoreThan      = 30
    DisableIncludeType                     = @('MSA', 'GMSA')
    DisableLimit                           = 10 # Increase for comprehensive run
    DisableModifyDescription               = $true
    DisableModifyAdminDescription          = $true

    # Delete Configuration
    Delete                                 = $true
    DeleteIsEnabled                        = $false
    DeletePasswordLastSetMoreThan          = 180
    DeleteRequireWhenCreatedMoreThan       = 90
    DeleteListProcessedMoreThan            = 90
    DeleteIncludeType                      = @('MSA', 'GMSA')
    DeleteLimit                            = 5

    # Advanced Exclusions
    Exclusions                             = @(
        # Organizational Unit exclusions
        '*OU=Critical Service Accounts*'
        '*OU=Production Services*'
        '*OU=Exchange*'
        '*OU=SQL Server*'
        '*OU=SharePoint*'

        # Specific service account exclusions
        '*Exchange*'
        '*SQL*'
        '*SharePoint*'
        '*ADFS*'
        '*AADConnect*'
        '*Backup*'
        '*Monitor*'

        # Environment-specific exclusions
        'PROD-*'
        'CRITICAL-*'
        '*-PROD$'
        '*-CRITICAL$'
    )

    # Filtering and targeting
    Filter                                 = '*' # Can be used to target specific patterns

    # WhatIf and safety settings
    WhatIfDisable                          = $true
    WhatIfDelete                           = $true
    ReportOnly                             = $true # Set to $false for actual execution

    # Logging and reporting
    LogPath                                = "$PSScriptRoot\Logs\ComprehensiveServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                          = "$PSScriptRoot\ProcessedServiceAccounts.xml"
    ReportPath                             = "$PSScriptRoot\Reports\ComprehensiveServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                               = $true
    Online                                 = $false # Use offline mode for faster report generation

    # Security settings
    RemoveProtectedFromAccidentalDeletionFlag = $true
    DontWriteToEventLog                    = $false
    Suppress                               = $false
}

Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "- Target Account Types: MSA, GMSA" -ForegroundColor Cyan
Write-Host "- Disable Criteria: Enabled accounts with password > 90 days" -ForegroundColor Cyan
Write-Host "- Delete Criteria: Disabled accounts with password > 180 days, on pending list > 90 days" -ForegroundColor Cyan
Write-Host "- Disable Limit: $($Configuration.DisableLimit) accounts" -ForegroundColor Cyan
Write-Host "- Delete Limit: $($Configuration.DeleteLimit) accounts" -ForegroundColor Cyan
Write-Host "- Report Only Mode: $($Configuration.ReportOnly)" -ForegroundColor $(if($Configuration.ReportOnly){'Green'}else{'Red'})
Write-Host "- Total Exclusions: $($Configuration.Exclusions.Count)" -ForegroundColor Cyan
Write-Host ""

if ($Configuration.ReportOnly) {
    Write-Host "Running in REPORT ONLY mode - no changes will be made" -ForegroundColor Green
} else {
    Write-Host "WARNING: Running in LIVE mode - changes will be made to Active Directory!" -ForegroundColor Red
    $confirm = Read-Host "Are you sure you want to proceed? (type 'YES' to continue)"
    if ($confirm -ne 'YES') {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit
    }
}

Write-Host ""
Write-Host "Starting comprehensive MSA/GMSA cleanup operation..." -ForegroundColor Green

$StartTime = Get-Date
$Output = Invoke-ADServiceAccountsCleanup @Configuration
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host ""
Write-Host "Operation completed in $($Duration.TotalSeconds) seconds" -ForegroundColor Green
Write-Host ""

# Display comprehensive results
Write-Host "=== COMPREHENSIVE RESULTS ===" -ForegroundColor Green
Write-Host ""

Write-Host "Account Discovery:" -ForegroundColor Yellow
Write-Host "- Total Service Accounts Found: $($Output.Statistics.All)" -ForegroundColor Cyan
Write-Host "- MSA Accounts: $($Output.Statistics.TotalMSA)" -ForegroundColor Cyan
Write-Host "- GMSA Accounts: $($Output.Statistics.TotalGMSA)" -ForegroundColor Cyan
if ($Output.Statistics.TotalUnknown -gt 0) {
    Write-Host "- Unknown Type Accounts: $($Output.Statistics.TotalUnknown)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Actions Required:" -ForegroundColor Yellow
Write-Host "- Accounts to Disable: $($Output.Statistics.ToDisable)" -ForegroundColor $(if($Output.Statistics.ToDisable -gt 0){'Red'}else{'Green'})
if ($Output.Statistics.ToDisable -gt 0) {
    Write-Host "  - MSA to Disable: $($Output.Statistics.ToDisableMSA)" -ForegroundColor Cyan
    Write-Host "  - GMSA to Disable: $($Output.Statistics.ToDisableGMSA)" -ForegroundColor Cyan
}
Write-Host "- Accounts to Delete: $($Output.Statistics.ToDelete)" -ForegroundColor $(if($Output.Statistics.ToDelete -gt 0){'Red'}else{'Green'})
if ($Output.Statistics.ToDelete -gt 0) {
    Write-Host "  - MSA to Delete: $($Output.Statistics.ToDeleteMSA)" -ForegroundColor Cyan
    Write-Host "  - GMSA to Delete: $($Output.Statistics.ToDeleteGMSA)" -ForegroundColor Cyan
}
Write-Host ""

if ($Output.CurrentRun.Count -gt 0) {
    Write-Host "Current Run Results:" -ForegroundColor Yellow
    Write-Host "- Total Actions Performed: $($Output.CurrentRun.Count)" -ForegroundColor Cyan

    $SuccessCount = ($Output.CurrentRun | Where-Object { $_.ActionStatus -eq $true }).Count
    $FailureCount = ($Output.CurrentRun | Where-Object { $_.ActionStatus -eq $false }).Count
    $WhatIfCount = ($Output.CurrentRun | Where-Object { $_.ActionStatus -eq 'WhatIf' }).Count

    if ($WhatIfCount -gt 0) {
        Write-Host "- WhatIf Operations: $WhatIfCount" -ForegroundColor Blue
    }
    if ($SuccessCount -gt 0) {
        Write-Host "- Successful Operations: $SuccessCount" -ForegroundColor Green
    }
    if ($FailureCount -gt 0) {
        Write-Host "- Failed Operations: $FailureCount" -ForegroundColor Red
    }
    Write-Host ""
}

if ($Output.PendingDeletion -and $Output.PendingDeletion.Count -gt 0) {
    Write-Host "Pending List Information:" -ForegroundColor Yellow
    Write-Host "- Accounts on Pending List: $($Output.PendingDeletion.Count)" -ForegroundColor Cyan

    $PendingOver90 = ($Output.PendingDeletion.Values | Where-Object { $_.TimeOnPendingList -gt 90 }).Count
    $PendingOver30 = ($Output.PendingDeletion.Values | Where-Object { $_.TimeOnPendingList -gt 30 -and $_.TimeOnPendingList -le 90 }).Count

    if ($PendingOver90 -gt 0) {
        Write-Host "- Over 90 days on pending list: $PendingOver90" -ForegroundColor Red
    }
    if ($PendingOver30 -gt 0) {
        Write-Host "- 30-90 days on pending list: $PendingOver30" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Files Generated:" -ForegroundColor Yellow
Write-Host "- Log File: $($Configuration.LogPath)" -ForegroundColor Cyan
Write-Host "- HTML Report: $($Configuration.ReportPath)" -ForegroundColor Cyan
Write-Host "- Data Store: $($Configuration.DataStorePath)" -ForegroundColor Cyan
Write-Host ""

Write-Host "=== END RESULTS ===" -ForegroundColor Green

# Return the full output for further processing if needed
$Output
