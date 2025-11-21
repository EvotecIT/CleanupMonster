function New-ADServiceAccountsStatistics {
    <#
    .SYNOPSIS
    Creates statistics for service accounts processing.

    .DESCRIPTION
    This function analyzes service accounts and creates comprehensive statistics
    about what actions will be taken, account types, and other relevant metrics.
    #>
    [CmdletBinding()]
    param(
        [Array] $ServiceAccountsToProcess
    )

    $Statistics = [ordered] @{
        All                          = $ServiceAccountsToProcess.Count

        ToDisable                    = 0
        ToDisableMSA                 = 0
        ToDisableGMSA                = 0
        ToDisableUnknown             = 0

        ToDelete                     = 0
        ToDeleteMSA                  = 0
        ToDeleteGMSA                 = 0
        ToDeleteUnknown              = 0

        TotalMSA                     = 0
        TotalGMSA                    = 0
        TotalUnknown                 = 0

        Delete                       = [ordered] @{
            PasswordLastChangedDays = [ordered] @{}
            ServiceAccountTypes     = [ordered] @{}
        }
        Disable                      = [ordered] @{
            PasswordLastChangedDays = [ordered] @{}
            ServiceAccountTypes     = [ordered] @{}
        }
        'Not required'               = [ordered] @{
            PasswordLastChangedDays = [ordered] @{}
            ServiceAccountTypes     = [ordered] @{}
        }
        'ExcludedBySetting'          = [ordered] @{
            PasswordLastChangedDays = [ordered] @{}
            ServiceAccountTypes     = [ordered] @{}
        }
        'ExcludedByFilter'           = [ordered] @{
            PasswordLastChangedDays = [ordered] @{}
            ServiceAccountTypes     = [ordered] @{}
        }
    }

    foreach ($ServiceAccount in $ServiceAccountsToProcess) {
        # Count by service account type
        if ($ServiceAccount.ServiceAccountType -eq "MSA") {
            $Statistics.TotalMSA++
        } elseif ($ServiceAccount.ServiceAccountType -eq "GMSA") {
            $Statistics.TotalGMSA++
        } else {
            $Statistics.TotalUnknown++
        }

        # Count by action
        if ($ServiceAccount.Action -eq 'Disable') {
            $Statistics.ToDisable++
            if ($ServiceAccount.ServiceAccountType -eq "MSA") {
                $Statistics.ToDisableMSA++
            } elseif ($ServiceAccount.ServiceAccountType -eq "GMSA") {
                $Statistics.ToDisableGMSA++
            } else {
                $Statistics.ToDisableUnknown++
            }
        } elseif ($ServiceAccount.Action -eq 'Delete') {
            $Statistics.ToDelete++
            if ($ServiceAccount.ServiceAccountType -eq "MSA") {
                $Statistics.ToDeleteMSA++
            } elseif ($ServiceAccount.ServiceAccountType -eq "GMSA") {
                $Statistics.ToDeleteGMSA++
            } else {
                $Statistics.ToDeleteUnknown++
            }
        }

        # Collect password age statistics
        if ($ServiceAccount.PasswordLastSetDays) {
            $PasswordDays = $ServiceAccount.PasswordLastSetDays
            $PasswordRange = switch ($PasswordDays) {
                { $_ -le 30 } { "0-30 days" }
                { $_ -le 60 } { "31-60 days" }
                { $_ -le 90 } { "61-90 days" }
                { $_ -le 180 } { "91-180 days" }
                { $_ -le 365 } { "181-365 days" }
                default { "Over 365 days" }
            }

            $ActionCategory = [string]$ServiceAccount.Action
            if (-not $ActionCategory) {
                $ActionCategory = 'Not required'
            }
            if (-not $Statistics[$ActionCategory]) {
                # Skip invalid action categories
                continue
            }
            if (-not $Statistics[$ActionCategory]['PasswordLastChangedDays'][$PasswordRange]) {
                $Statistics[$ActionCategory]['PasswordLastChangedDays'][$PasswordRange] = 0
            }
            $Statistics[$ActionCategory]['PasswordLastChangedDays'][$PasswordRange]++
        }

        # Collect service account type statistics by action
        $ActionCategory = [string]$ServiceAccount.Action
        if (-not $ActionCategory) {
            $ActionCategory = 'Not required'
        }
        if (-not $Statistics[$ActionCategory]) {
            # Skip invalid action categories
            continue
        }
        $AccountType = $ServiceAccount.ServiceAccountType
        if (-not $Statistics[$ActionCategory]['ServiceAccountTypes'][$AccountType]) {
            $Statistics[$ActionCategory]['ServiceAccountTypes'][$AccountType] = 0
        }
        $Statistics[$ActionCategory]['ServiceAccountTypes'][$AccountType]++
    }

    $Statistics
}
