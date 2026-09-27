function New-EmailBodyComputers {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun,
        [Array] $StageConfiguration = @(),
        [switch] $DisableAndMove
    )

    Write-Color -Text '[i] ', 'Preparing optional AD cleanup email body; this command does not send.' -Color Yellow, White
    $report = Get-CleanupEmailReport -CurrentRun $CurrentRun -StageConfiguration $StageConfiguration -Source AD -DisableAndMove:$DisableAndMove
    New-EmailBodyCleanup -Title 'AD computer cleanup summary' -Report $report
}