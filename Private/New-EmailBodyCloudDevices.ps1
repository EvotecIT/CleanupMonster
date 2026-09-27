function New-EmailBodyCloudDevices {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun,
        [Array] $StageConfiguration = @()
    )

    Write-Color -Text '[i] ', 'Preparing optional cloud cleanup email body; this command does not send.' -Color Yellow, White
    $report = Get-CleanupEmailReport -CurrentRun $CurrentRun -StageConfiguration $StageConfiguration -Source Cloud
    New-EmailBodyCleanup -Title 'Cloud device cleanup summary' -Report $report
}