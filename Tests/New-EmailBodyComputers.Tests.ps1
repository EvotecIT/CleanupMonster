BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    Import-Module PSWriteHTML -MinimumVersion 1.41.0 -ErrorAction Stop
    . (Get-CleanupMonsterPath 'Private/New-EmailBodyComputers.ps1')
    function Write-Color {}
}

Describe 'New-EmailBodyComputers current-run email' {
    It 'renders supplied actions and counts instead of a previous caller Output' {
        $Output = @{
            CurrentRun = @([pscustomobject]@{ Name = 'STALE-EMAIL-ROW'; Action = 'Disable' })
        }
        $currentRun = @(
            [pscustomobject]@{ Name = 'CURRENT-DISABLED'; Action = 'Disable'; ActionStatus = $true }
            [pscustomobject]@{ Name = 'CURRENT-PREVIEW'; Action = 'Delete'; ActionStatus = 'WhatIf' }
        )

        $body = New-EmailBodyComputers -CurrentRun $currentRun
        $text = [System.Net.WebUtility]::HtmlDecode(($body -replace '<[^>]+>', ' ')) -replace '\s+', ' '

        $text | Should -Match 'Objects actioned: 2'
        $text | Should -Match 'Objects deleted: 1'
        $text | Should -Match 'Objects disabled: 1'
        $text | Should -Match 'CURRENT-DISABLED Disable True'
        $text | Should -Match 'CURRENT-PREVIEW Delete WhatIf'
        $text | Should -Not -Match 'STALE-EMAIL-ROW'
    }

    It 'renders an empty current run without leaking previous actions' {
        $Output = @{
            CurrentRun = @([pscustomobject]@{ Name = 'STALE-EMAIL-ROW'; Action = 'Delete' })
        }

        $body = New-EmailBodyComputers -CurrentRun @()
        $text = [System.Net.WebUtility]::HtmlDecode(($body -replace '<[^>]+>', ' ')) -replace '\s+', ' '

        $text | Should -Match 'Objects actioned: 0'
        $text | Should -Match 'Objects deleted: 0'
        $text | Should -Match 'Objects disabled: 0'
        $text | Should -Not -Match 'STALE-EMAIL-ROW'
    }
}
