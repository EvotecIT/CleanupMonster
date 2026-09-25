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

Describe 'AD current-run report layout' {
    It 'renders one expandable action table for the selected computers' {
        $reportPath = Join-Path $TestDrive 'ADCurrentRun.html'
        $root = Split-Path -Parent $PSScriptRoot
        $job = Start-Job -ScriptBlock {
            param($RepositoryRoot, $FilePath)
            $ErrorActionPreference = 'Stop'
            Import-Module PSWriteHTML -MinimumVersion 1.41.0 -ErrorAction Stop
            . (Join-Path $RepositoryRoot 'Private/Get-ADComputerReportOutcome.ps1')
            . (Join-Path $RepositoryRoot 'Private/New-HTMLADComputerCurrentRun.ps1')
            $actions = @(
                [pscustomobject] @{ SamAccountName = 'LAB-PC-01$'; DNSHostName = 'LAB-PC-01.example.test'; Action = 'Disable'; ActionAttempted = $true; ActionStatus = 'True'; LastLogonDays = 130; OperatingSystem = 'Windows'; SelectionReason = 'Last logon 130 days ago'; ActionComment = '' }
                [pscustomobject] @{ SamAccountName = 'LAB-PC-02$'; DNSHostName = 'LAB-PC-02.example.test'; Action = 'Delete'; ActionAttempted = $true; ActionStatus = 'WhatIf'; LastLogonDays = 240; OperatingSystem = 'Windows'; SelectionReason = 'Last logon 240 days ago'; ActionComment = ''; DisableActionResult = 'Later row only'; MoveActionResult = 'WhatIf' }
            )
            New-HTML {
                New-HTMLTab -Name 'Devices Current Run' {
                    New-HTMLADComputerCurrentRun -Actions $actions
                }
            } -FilePath $FilePath
        } -ArgumentList $root, $reportPath
        try {
            $job | Wait-Job -Timeout 60 | Should -Not -BeNullOrEmpty
            $job.State | Should -Be 'Completed'
            Receive-Job -Job $job -ErrorAction Stop | Out-Null
        } finally {
            Remove-Job -Job $job -Force
        }

        $html = Get-Content -LiteralPath $reportPath -Raw
        ([regex]::Matches($html, '<table[^>]*id="DT-')).Count | Should -Be 1
        $html | Should -Match 'Actions this run'
        $html | Should -Match 'SelectionReason'
        $html | Should -Match 'DisableActionResult'
        $html | Should -Match 'Later row only'
        $html | Should -Match 'MoveActionResult'
        $html | Should -Not -Match 'Quick view'
    }
}
