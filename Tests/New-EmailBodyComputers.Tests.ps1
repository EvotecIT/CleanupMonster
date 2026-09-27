BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    Import-Module PSWriteHTML -MinimumVersion 1.41.0 -ErrorAction Stop
    . (Get-CleanupMonsterPath 'Private/Get-ADComputerReportOutcome.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CleanupEmailActionOutcome.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CleanupEmailReport.ps1')
    . (Get-CleanupMonsterPath 'Private/New-EmailBodyCleanup.ps1')
    . (Get-CleanupMonsterPath 'Private/New-EmailBodyComputers.ps1')
    function Write-Color {}
}

Describe 'New-EmailBodyComputers current-run email' {
    It 'renders supplied actions and counts instead of a previous caller Output' {
        $Output = @{
            CurrentRun = @([pscustomobject]@{ Name = 'STALE-EMAIL-ROW'; Action = 'Disable' })
        }
        $currentRun = @(
            [pscustomobject]@{ SamAccountName = 'CURRENT-DISABLED'; Action = 'Disable'; ActionStatus = $true; ActionAttempted = $true }
            [pscustomobject]@{ SamAccountName = 'CURRENT-PREVIEW'; Action = 'Delete'; ActionStatus = 'WhatIf'; ActionAttempted = $true }
        )

        $stages = @(
            [pscustomobject] @{ Action = 'Disable'; Name = 'Disable'; Mode = 'Live'; Candidates = 1; Limit = 0 }
            [pscustomobject] @{ Action = 'Delete'; Name = 'Delete'; Mode = 'WhatIf'; Candidates = 1; Limit = 0 }
        )
        $body = New-EmailBodyComputers -CurrentRun $currentRun -StageConfiguration $stages
        $text = [System.Net.WebUtility]::HtmlDecode(($body -replace '<[^>]+>', ' ')) -replace '\s+', ' '

        $text | Should -Match 'Completed: 1'
        $text | Should -Match 'WhatIf: 1'
        $text | Should -Match 'CURRENT-DISABLED Disable Completed'
        $text | Should -Match 'CURRENT-PREVIEW Delete WhatIf preview'
        $text | Should -Not -Match 'STALE-EMAIL-ROW'
    }

    It 'renders an empty current run without leaking previous actions' {
        $Output = @{
            CurrentRun = @([pscustomobject]@{ Name = 'STALE-EMAIL-ROW'; Action = 'Delete' })
        }

        $body = New-EmailBodyComputers -CurrentRun @() -StageConfiguration @([pscustomobject] @{ Action = 'Delete'; Name = 'Delete'; Mode = 'Live'; Candidates = 0; Limit = 5 })
        $text = [System.Net.WebUtility]::HtmlDecode(($body -replace '<[^>]+>', ' ')) -replace '\s+', ' '

        $text | Should -Match 'Candidates: 0; limit: 5; results: 0'
        $text | Should -Match 'Completed: 0'
        $text | Should -Match 'No action results'
        $text | Should -Not -Match 'STALE-EMAIL-ROW'
    }
}

AfterAll { Remove-Module PSWriteHTML -ErrorAction SilentlyContinue }
