function New-EmailBodyServiceAccounts {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun = @(),
        [Array] $StageConfiguration = @()
    )

    $reportParameters = @{
        Source             = 'ServiceAccount'
        CurrentRun         = $CurrentRun
        StageConfiguration = $StageConfiguration
    }
    $report = Get-CleanupEmailReport @reportParameters

    # The PSWriteHTML header, summary table and result table live in this shared template.
    $emailParameters = @{
        Title       = 'Service account cleanup'
        Report      = $report
        ObjectLabel = 'Account'
    }
    New-EmailBodyCleanup @emailParameters
}
