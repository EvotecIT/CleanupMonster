function New-EmailBodyServiceAccounts {
    [CmdletBinding()]
    param([Array] $CurrentRun = @(), [Array] $StageConfiguration = @())

    $report = Get-CleanupEmailReport -Source ServiceAccount -CurrentRun $CurrentRun -StageConfiguration $StageConfiguration
    New-EmailBodyCleanup -Title 'Service account cleanup' -Report $report -ObjectLabel 'Account'
}
