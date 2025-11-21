function New-EmailBodyServiceAccounts {
    <#
    .SYNOPSIS
    Creates email body content for service accounts cleanup report.

    .DESCRIPTION
    This function generates formatted email body content that summarizes
    the service accounts cleanup operation and provides key statistics.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export,
        [Array] $ServiceAccountsToProcess,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [bool] $Delete,
        [bool] $Disable,
        [bool] $ReportOnly
    )

    $EmailBody = @"
Subject: CleanupMonster - Service Accounts Cleanup Report

Service Accounts Cleanup Report
==============================

General Information:
• Report Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
• Version: $($Export.Version)
• Report Only: $ReportOnly
• Disable Enabled: $Disable
• Delete Enabled: $Delete

Service Account Statistics:
• Total Service Accounts: $($Export.Statistics.All)
• MSA Accounts: $($Export.Statistics.TotalMSA)
• GMSA Accounts: $($Export.Statistics.TotalGMSA)
"@

    if ($Export.Statistics.TotalUnknown -gt 0) {
        $EmailBody += "`n• Unknown Type: $($Export.Statistics.TotalUnknown)"
    }

    $EmailBody += @"

Actions Summary:
"@

    if ($Export.Statistics.ToDisable -gt 0) {
        $EmailBody += "`n• Service Accounts to Disable: $($Export.Statistics.ToDisable)"
        if ($Export.Statistics.ToDisableMSA -gt 0) {
            $EmailBody += "`n  - MSA: $($Export.Statistics.ToDisableMSA)"
        }
        if ($Export.Statistics.ToDisableGMSA -gt 0) {
            $EmailBody += "`n  - GMSA: $($Export.Statistics.ToDisableGMSA)"
        }
        if ($Export.Statistics.ToDisableUnknown -gt 0) {
            $EmailBody += "`n  - Unknown: $($Export.Statistics.ToDisableUnknown)"
        }
    } else {
        $EmailBody += "`n• No service accounts to disable"
    }

    if ($Export.Statistics.ToDelete -gt 0) {
        $EmailBody += "`n• Service Accounts to Delete: $($Export.Statistics.ToDelete)"
        if ($Export.Statistics.ToDeleteMSA -gt 0) {
            $EmailBody += "`n  - MSA: $($Export.Statistics.ToDeleteMSA)"
        }
        if ($Export.Statistics.ToDeleteGMSA -gt 0) {
            $EmailBody += "`n  - GMSA: $($Export.Statistics.ToDeleteGMSA)"
        }
        if ($Export.Statistics.ToDeleteUnknown -gt 0) {
            $EmailBody += "`n  - Unknown: $($Export.Statistics.ToDeleteUnknown)"
        }
    } else {
        $EmailBody += "`n• No service accounts to delete"
    }

    # Current Run Results
    if ($Export.CurrentRun.Count -gt 0) {
        $SuccessCount = $Export.CurrentRun | Where-Object { $_.ActionStatus -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
        $FailureCount = $Export.CurrentRun | Where-Object { $_.ActionStatus -eq $false } | Measure-Object | Select-Object -ExpandProperty Count
        $WhatIfCount = $Export.CurrentRun | Where-Object { $_.ActionStatus -eq 'WhatIf' } | Measure-Object | Select-Object -ExpandProperty Count

        $EmailBody += @"

Current Run Results:
• Total Processed: $($Export.CurrentRun.Count)
"@
        if ($WhatIfCount -gt 0) {
            $EmailBody += "`n• WhatIf Operations: $WhatIfCount"
        }
        if ($SuccessCount -gt 0) {
            $EmailBody += "`n• Successful Operations: $SuccessCount"
        }
        if ($FailureCount -gt 0) {
            $EmailBody += "`n• Failed Operations: $FailureCount"
        }
    }

    # Pending List Information
    if ($Export.PendingDeletion -and $Export.PendingDeletion.Count -gt 0) {
        $PendingOver90 = $Export.PendingDeletion.Values | Where-Object { $_.TimeOnPendingList -gt 90 } | Measure-Object | Select-Object -ExpandProperty Count
        $PendingOver30 = $Export.PendingDeletion.Values | Where-Object { $_.TimeOnPendingList -gt 30 -and $_.TimeOnPendingList -le 90 } | Measure-Object | Select-Object -ExpandProperty Count

        $EmailBody += @"

Pending List Information:
• Service Accounts on Pending List: $($Export.PendingDeletion.Count)
"@
        if ($PendingOver90 -gt 0) {
            $EmailBody += "`n• Over 90 days on pending list: $PendingOver90"
        }
        if ($PendingOver30 -gt 0) {
            $EmailBody += "`n• 30-90 days on pending list: $PendingOver30"
        }
    }

    # Configuration Summary
    $EmailBody += @"

Configuration Summary:
"@
    if ($Disable) {
        $EmailBody += "`n• Disable Criteria:"
        foreach ($Key in $DisableOnlyIf.Keys) {
            if ($null -ne $DisableOnlyIf[$Key] -and $DisableOnlyIf[$Key] -ne '') {
                $EmailBody += "`n  - $Key`: $($DisableOnlyIf[$Key])"
            }
        }
    }
    if ($Delete) {
        $EmailBody += "`n• Delete Criteria:"
        foreach ($Key in $DeleteOnlyIf.Keys) {
            if ($null -ne $DeleteOnlyIf[$Key] -and $DeleteOnlyIf[$Key] -ne '') {
                $EmailBody += "`n  - $Key`: $($DeleteOnlyIf[$Key])"
            }
        }
    }

    # Top Service Accounts to Process (if any)
    if ($ServiceAccountsToProcess.Count -gt 0) {
        $TopServiceAccounts = $ServiceAccountsToProcess | Where-Object { $_.Action -in @('Delete', 'Disable') } | Select-Object -First 5
        if ($TopServiceAccounts.Count -gt 0) {
            $EmailBody += @"

Top Service Accounts for Action:
"@
            foreach ($ServiceAccount in $TopServiceAccounts) {
                $LastLogon = if ($ServiceAccount.LastLogonDate) { $ServiceAccount.LastLogonDate.ToString('yyyy-MM-dd') } else { 'Never' }
                $PasswordLastSet = if ($ServiceAccount.PasswordLastSet) { $ServiceAccount.PasswordLastSet.ToString('yyyy-MM-dd') } else { 'Never' }
                $EmailBody += "`n• $($ServiceAccount.Name) ($($ServiceAccount.ServiceAccountType)) - Action: $($ServiceAccount.Action), Last Logon: $LastLogon, Enabled: $($ServiceAccount.Enabled)"
            }
        }
    }

    # Warnings and Notes
    if ($Export.Statistics.ToDelete -gt 0 -or $Export.Statistics.ToDisable -gt 0) {
        $EmailBody += @"

Important Notes:
• Please review the full HTML report for detailed information
• Verify all actions before proceeding with actual cleanup
"@
        if (-not $ReportOnly) {
            $EmailBody += "`n• This was a live run - changes have been made to Active Directory"
        } else {
            $EmailBody += "`n• This was a report-only run - no changes were made"
        }
    }

    $EmailBody
}
