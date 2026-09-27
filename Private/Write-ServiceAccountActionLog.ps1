function Write-ServiceAccountActionLog {
    [CmdletBinding()]
    param([Array] $Results = @(), [string] $LogPath)

    foreach ($account in $Results) {
        if ([string] $account.ActionStatus -eq 'ReportOnly') { continue }
        $outcome = Get-CleanupEmailActionOutcome -Record $account -Source ServiceAccount
        Write-Color -Text '[i] ', "Service account $($account.Action): $($account.SamAccountName) [$($account.DomainName)]; outcome: $($outcome.Label); DN: $($account.DistinguishedName); reason: $($account.SelectionReason); notes: $($account.ActionComment)" -Color Yellow, White -LogFile $LogPath
    }
}
