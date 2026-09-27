function New-EmailBodyCloudDevices {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun,
        [Array] $StageConfiguration = @()
    )

    Write-Color -Text '[i] ', 'Preparing optional cloud cleanup email body; this command does not send.' -Color Yellow, White
    $reportParameters = @{
        Source             = 'Cloud'
        CurrentRun         = $CurrentRun
        StageConfiguration = $StageConfiguration
    }
    $report = Get-CleanupEmailReport @reportParameters

    # The PSWriteHTML header, summary table and result table live in this shared template.
    $emailParameters = @{
        Title  = 'Cloud device cleanup summary'
        Report = $report
    }
    New-EmailBodyCleanup @emailParameters
}
