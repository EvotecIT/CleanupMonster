function New-EmailBodyComputers {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun,
        [Array] $StageConfiguration = @(),
        [switch] $DisableAndMove
    )

    Write-Color -Text '[i] ', 'Preparing optional AD cleanup email body; this command does not send.' -Color Yellow, White
    $reportParameters = @{
        Source             = 'AD'
        CurrentRun         = $CurrentRun
        StageConfiguration = $StageConfiguration
        DisableAndMove     = $DisableAndMove
    }
    $report = Get-CleanupEmailReport @reportParameters

    # The PSWriteHTML header, summary table and result table live in this shared template.
    $emailParameters = @{
        Title  = 'AD computer cleanup summary'
        Report = $report
    }
    New-EmailBodyCleanup @emailParameters
}
