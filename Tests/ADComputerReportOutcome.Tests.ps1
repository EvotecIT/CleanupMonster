BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ADComputerReportOutcome.ps1')
}

Describe 'AD current-run report outcomes' {
    It 'counts only an attempted clean WhatIf as a preview' {
        $preview = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = 'WhatIf'; ActionComment = $null }
        $error = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = 'WhatIf'; ActionComment = 'Access denied' }
        $skipped = [pscustomobject] @{ Action = 'Delete'; ActionAttempted = $false; ActionStatus = 'WhatIf'; ActionComment = $null }

        (Get-ADComputerReportOutcome -Computer $preview).Group | Should -Be 'WhatIf'
        (Get-ADComputerReportOutcome -Computer $error).Label | Should -Be 'WhatIf error'
        (Get-ADComputerReportOutcome -Computer $error).Group | Should -Be 'NeedsReview'
        (Get-ADComputerReportOutcome -Computer $skipped).Label | Should -Be 'Skipped'
    }

    It 'shows partially completed disable-and-move instead of a successful action' {
        $partial = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = $false; DisableActionResult = 'True'; MoveActionResult = 'False' }
        $complete = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = $true; DisableActionResult = 'True'; MoveActionResult = 'True' }

        (Get-ADComputerReportOutcome -Computer $partial -DisableAndMove).Label | Should -Be 'Partially completed'
        (Get-ADComputerReportOutcome -Computer $partial -DisableAndMove).Group | Should -Be 'NeedsReview'
        (Get-ADComputerReportOutcome -Computer $complete -DisableAndMove).Group | Should -Be 'Completed'
    }

    It 'does not call a missing move step a complete WhatIf preview' {
        $incomplete = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = 'WhatIf'; DisableActionResult = 'WhatIf'; MoveActionResult = $null }
        $completePreview = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = 'WhatIf'; DisableActionResult = 'WhatIf'; MoveActionResult = 'WhatIf' }

        (Get-ADComputerReportOutcome -Computer $incomplete -DisableAndMove).Label | Should -Be 'Incomplete WhatIf'
        (Get-ADComputerReportOutcome -Computer $incomplete -DisableAndMove).Group | Should -Be 'NeedsReview'
        (Get-ADComputerReportOutcome -Computer $completePreview -DisableAndMove).Group | Should -Be 'WhatIf'
    }

    It 'flags a completed AD call with a subsequent metadata error for review' {
        $result = [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = $true; ActionComment = 'Description update failed' }

        (Get-ADComputerReportOutcome -Computer $result).Label | Should -Be 'Completed with issue'
        (Get-ADComputerReportOutcome -Computer $result).Group | Should -Be 'NeedsReview'
    }
}
