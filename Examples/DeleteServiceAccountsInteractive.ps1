Import-Module .\CleanupMonster.psd1 -Force

# Interactive script for MSA/GMSA cleanup with user prompts
Write-Host "MSA/GMSA Service Accounts Cleanup - Interactive Mode" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host ""

# Ask user for configuration
$DisableEnabled = Read-Host "Enable disable operation? (y/n) [default: y]"
if ($DisableEnabled -eq '' -or $DisableEnabled -eq 'y') {
    $Disable = $true
    $DisableDays = Read-Host "Disable accounts with password older than X days [default: 90]"
    if ($DisableDays -eq '') { $DisableDays = 90 } else { $DisableDays = [int]$DisableDays }

    $DisableLimit = Read-Host "Limit number of accounts to disable (0 = unlimited) [default: 5]"
    if ($DisableLimit -eq '') { $DisableLimit = 5 } else { $DisableLimit = [int]$DisableLimit }
} else {
    $Disable = $false
    $DisableDays = 90
    $DisableLimit = 0
}

$DeleteEnabled = Read-Host "Enable delete operation? (y/n) [default: y]"
if ($DeleteEnabled -eq '' -or $DeleteEnabled -eq 'y') {
    $Delete = $true
    $DeleteDays = Read-Host "Delete accounts with password older than X days [default: 180]"
    if ($DeleteDays -eq '') { $DeleteDays = 180 } else { $DeleteDays = [int]$DeleteDays }

    $DeleteLimit = Read-Host "Limit number of accounts to delete (0 = unlimited) [default: 3]"
    if ($DeleteLimit -eq '') { $DeleteLimit = 3 } else { $DeleteLimit = [int]$DeleteLimit }
} else {
    $Delete = $false
    $DeleteDays = 180
    $DeleteLimit = 0
}

$AccountTypes = Read-Host "Which account types to process? (MSA/GMSA/Both) [default: Both]"
switch ($AccountTypes.ToUpper()) {
    'MSA' { $IncludeTypes = @('MSA') }
    'GMSA' { $IncludeTypes = @('GMSA') }
    default { $IncludeTypes = @('MSA', 'GMSA') }
}

$ReportOnly = Read-Host "Report only mode (no actual changes)? (y/n) [default: y]"
$ReportOnly = ($ReportOnly -eq '' -or $ReportOnly -eq 'y')

$ShowReport = Read-Host "Show HTML report when complete? (y/n) [default: y]"
$ShowHTML = ($ShowReport -eq '' -or $ShowReport -eq 'y')

Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "- Disable: $Disable $(if($Disable){"(Password > $DisableDays days, Limit: $DisableLimit)"})" -ForegroundColor Cyan
Write-Host "- Delete: $Delete $(if($Delete){"(Password > $DeleteDays days, Limit: $DeleteLimit)"})" -ForegroundColor Cyan
Write-Host "- Account Types: $($IncludeTypes -join ', ')" -ForegroundColor Cyan
Write-Host "- Report Only: $ReportOnly" -ForegroundColor Cyan
Write-Host "- Show HTML: $ShowHTML" -ForegroundColor Cyan
Write-Host ""

$Confirm = Read-Host "Proceed with these settings? (y/n) [default: y]"
if ($Confirm -eq 'n') {
    Write-Host "Operation cancelled by user." -ForegroundColor Red
    exit
}

# Build configuration
$Configuration = @{
    Disable                                = $Disable
    DisableIsEnabled                       = $true
    DisablePasswordLastSetMoreThan         = $DisableDays
    DisableRequireWhenCreatedMoreThan      = 30
    DisableIncludeType                     = $IncludeTypes
    DisableLimit                           = $DisableLimit
    DisableModifyDescription               = $false
    DisableModifyAdminDescription          = $true

    Delete                                 = $Delete
    DeleteIsEnabled                        = $false
    DeletePasswordLastSetMoreThan          = $DeleteDays
    DeleteRequireWhenCreatedMoreThan       = 90
    DeleteListProcessedMoreThan            = 90
    DeleteIncludeType                      = $IncludeTypes
    DeleteLimit                            = $DeleteLimit

    Exclusions                             = @(
        '*OU=Protected Service Accounts*'
        '*Critical*'
        '*Production*'
    )

    Filter                                 = '*'
    WhatIfDisable                          = $true
    WhatIfDelete                           = $true
    ReportOnly                             = $ReportOnly
    LogPath                                = "$PSScriptRoot\Logs\ServiceAccountsInteractive_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                          = "$PSScriptRoot\ProcessedServiceAccounts.xml"
    ReportPath                             = "$PSScriptRoot\Reports\ServiceAccountsInteractive_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                               = $ShowHTML

    RemoveProtectedFromAccidentalDeletionFlag = $true
}

Write-Host "Starting MSA/GMSA cleanup operation..." -ForegroundColor Green
$Output = Invoke-ADServiceAccountsCleanup @Configuration

Write-Host ""
Write-Host "Operation completed. Summary:" -ForegroundColor Green
Write-Host "- Total Service Accounts Found: $($Output.Statistics.All)" -ForegroundColor Cyan
Write-Host "- Accounts to Disable: $($Output.Statistics.ToDisable)" -ForegroundColor $(if($Output.Statistics.ToDisable -gt 0){'Red'}else{'Green'})
Write-Host "- Accounts to Delete: $($Output.Statistics.ToDelete)" -ForegroundColor $(if($Output.Statistics.ToDelete -gt 0){'Red'}else{'Green'})

if ($Output.CurrentRun.Count -gt 0) {
    Write-Host "- Actions Performed: $($Output.CurrentRun.Count)" -ForegroundColor Cyan
}

$Output
