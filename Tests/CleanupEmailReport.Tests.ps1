BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    foreach ($helper in @('Get-ADComputerReportOutcome', 'Get-CloudDeviceAuditContext', 'Get-CleanupEmailActionOutcome', 'Get-CleanupEmailReport', 'Get-ADComputerEmailStageConfiguration', 'New-EmailBodyCleanup', 'New-EmailBodyCloudDevices', 'Request-CloudDevicesDelete', 'Request-CloudDevicesStageDelete')) {
        . (Get-CleanupMonsterPath "Private/$helper.ps1")
    }
    Import-Module PSWriteHTML -MinimumVersion 1.41.0 -ErrorAction Stop
    function Write-Color {}
    . (Get-CleanupMonsterPath 'Private/Request-ADComputersMove.ps1')
    function Move-ADObject { [pscustomobject] @{ DistinguishedName = 'CN=NEW,OU=Target,DC=test' } }
}

Describe 'Cleanup email outcome and limit reporting' {
    It 'reports observed AD move stops and already-at-target skips' -ForEach @(
        @{ Tail = 0; MissingTarget = $false; Stopped = $false; Skipped = 1 }
        @{ Tail = 1; MissingTarget = $false; Stopped = $true; Skipped = 1 }
        @{ Tail = 0; MissingTarget = $true; Stopped = $true; Skipped = 0 }
    ) {
        $computers = @('TARGET', 'NEW') | ForEach-Object {
            [pscustomobject] @{ SamAccountName=$_; Action='Move'; OrganizationalUnit=if ($_ -eq 'TARGET') {'OU=Target,DC=test'} else {'OU=Old,DC=test'}; DistinguishedName="CN=$_,DC=test"; DistinguishedNameAfterMove=$null; ProtectedFromAccidentalDeletion=$false; ActionDate=$null; ActionStatus=$null; ActionComment=$null }
        }
        if ($Tail) { $computers += [pscustomobject] @{Action='Move';OrganizationalUnit='OU=Old,DC=test'} }
        $domains = @{test=@{Computers=@($computers);Server='dc.test'}}
        $statistics = @{}
        $target = if ($MissingTarget) { @{other='OU=Target,DC=test'} } else { @{test='OU=Target,DC=test'} }
        $results = @(Request-ADComputersMove -Report $domains -MoveLimit 1 -RunStatistics $statistics -TargetOrganizationalUnit $target -WhatIfMove -DontWriteToEventLog -Today (Get-Date) -ProcessedComputers @{})
        $statistics.LimitStoppedIteration | Should -Be $Stopped
        $statistics.AlreadyAtTargetSkipped | Should -Be $Skipped
        $results.Count | Should -Be 1
        $stages = @(Get-ADComputerEmailStageConfiguration -Report $domains -Move $true -MoveLimit 1 -WhatIfMove $true -MoveRunStatistics $statistics)
        $report = Get-CleanupEmailReport -Source AD -CurrentRun $results -StageConfiguration $stages
        if ($Stopped) { $report.Summary.Note | Should -Match 'Limit reached' }
        else { $report.Summary.Note | Should -Not -Match 'Limit reached' }
        if ($Skipped) { $report.Summary.Note | Should -Match 'Already in target OU: 1' }
    }
    It 'distinguishes a real stage limit stop from already-pending skips at the result limit' -ForEach @(
        @{ Tail = 0; Stopped = $false }
        @{ Tail = 1; Stopped = $true }
    ) {
        $devices = @([pscustomobject] @{ ProcessedDeviceKey = 'pending' }, [pscustomobject] @{ ProcessedDeviceKey = 'new' })
        if ($Tail) { $devices += [pscustomobject] @{ ProcessedDeviceKey = 'tail' } }
        $statistics = @{}
        $results = @(Request-CloudDevicesStageDelete -Devices $devices -ProcessedDevices ([ordered] @{pending=@{}}) -Today (Get-Date) -StageLimit 1 -WhatIfStageDelete -RunStatistics $statistics)
        $statistics.AlreadyPendingSkipped | Should -Be 1
        $statistics.LimitStoppedIteration | Should -Be $Stopped
        $stage = [pscustomobject] @{ Action='StageDelete';Name='Stage for delete';Mode='WhatIf';Candidates=$devices.Count;Limit=1;AlreadyPendingSkipped=$statistics.AlreadyPendingSkipped;LimitStoppedIteration=$statistics.LimitStoppedIteration }
        $report = Get-CleanupEmailReport -Source Cloud -CurrentRun $results -StageConfiguration @($stage)
        $report.Summary.Note | Should -Match 'Already pending: 1'
        if ($Stopped) { $report.Summary.Note | Should -Match 'Limit reached' }
        else { $report.Summary.Note | Should -Not -Match 'Limit reached' }
    }
    It 'counts final assigned AD actions rather than overlapping rule match counters' {
        $domains = @{ 'one.test' = @{ ComputersToBeDisabled = 20; ComputersToBeDeleted = 19; Computers = @([pscustomobject] @{ Action = 'Disable' }) + @(1..19 | ForEach-Object { [pscustomobject] @{ Action = 'Delete' } }) } }
        $stages = @(Get-ADComputerEmailStageConfiguration -Report $domains -Disable $true -Delete $true -DisableLimit 1)
        $report = Get-CleanupEmailReport -Source AD -StageConfiguration $stages -CurrentRun @([pscustomobject] @{Action='Disable';ActionAttempted=$true;ActionStatus=$true})
        $disable = $report.Summary | Where-Object Action -eq 'Disable'
        $disable.Candidates | Should -Be 1
        $disable.Remaining | Should -Be 0
        $disable.Note | Should -Not -Match 'Limit reached'
    }

    It 'keeps blocked WhatIf deletes in needs-review results' -ForEach @(
        @{ Guard = @{IntuneMatchAmbiguous=$true} }
        @{ Guard = @{AutopilotMatchAmbiguous=$true} }
        @{ Guard = @{AutopilotOnboarded=$true; AutopilotDeviceId=''} }
        @{ Guard = @{AutopilotInventoryLoaded=$false} }
    ) {
        $record = [pscustomobject] (@{Name='BLOCKED';OperatingSystem='Windows';HasEntraRecord=$true} + $Guard)
        $results = @(Request-CloudDevicesDelete -Devices @($record) -ProcessedDevices @{} -Today (Get-Date) -DeleteAutopilotIdentity -WhatIfDelete)
        $results[0].ActionStatus | Should -Be 'WhatIf'
        $results[0].ActionBlocked | Should -BeTrue
        $report = Get-CleanupEmailReport -Source Cloud -CurrentRun $results -StageConfiguration @([pscustomobject]@{Action='Delete';Name='Delete';Candidates=1;Limit=1;Mode='WhatIf'})
        $report.Summary.WhatIf | Should -Be 0
        $report.Summary.NeedsReview | Should -Be 1
        $report.Actions[0].Outcome | Should -Be 'Blocked WhatIf (see notes)'
        $report.Actions[0].Details | Should -Match 'record delete was skipped'
    }
    It 'separates live, preview, failed and skipped AD rows with a global limit' {
        $records = @(
            [pscustomobject] @{ SamAccountName = 'DONE'; Action = 'Disable'; ActionAttempted = $true; ActionStatus = $true }
            [pscustomobject] @{ SamAccountName = 'PREVIEW'; Action = 'Disable'; ActionAttempted = $true; ActionStatus = 'WhatIf' }
            [pscustomobject] @{ SamAccountName = 'FAILED'; Action = 'Disable'; ActionAttempted = $true; ActionStatus = $false; ActionComment = 'Denied' }
            [pscustomobject] @{ SamAccountName = 'PROTECTED'; Action = 'Disable'; ActionAttempted = $false; ActionStatus = $false }
        )
        $stage = [pscustomobject] @{ Action = 'Disable'; Name = 'Disable'; Mode = 'Live'; Candidates = 20; Limit = 4 }
        $report = Get-CleanupEmailReport -Source AD -CurrentRun $records -StageConfiguration @($stage)
        $report.Summary.Completed | Should -Be 1
        $report.Summary.WhatIf | Should -Be 1
        $report.Summary.NeedsReview | Should -Be 1
        $report.Summary.Skipped | Should -Be 1
        $report.Summary.Remaining | Should -Be 16
        $report.Summary.Note | Should -Match 'Limit reached \(4\)'
    }

    It 'keeps partial disable-and-move and metadata errors out of completed totals' {
        $records = @(
            [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = $false; DisableActionResult = 'True'; MoveActionResult = 'False'; ActionComment = 'Move denied' }
            [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $true; ActionStatus = $true; DisableActionResult = 'True'; MoveActionResult = 'True'; ActionComment = 'Description denied' }
            [pscustomobject] @{ Action = 'Disable'; ActionAttempted = $false; ActionStatus = $true; DisableActionResult = 'AlreadySatisfied'; MoveActionResult = 'AlreadySatisfied' }
        )
        $report = Get-CleanupEmailReport -Source AD -CurrentRun $records -DisableAndMove -StageConfiguration @([pscustomobject] @{ Action = 'Disable'; Name = 'Disable and move'; Mode = 'Live'; Candidates = 3; Limit = 0 })
        $report.Summary.Completed | Should -Be 0
        $report.Summary.NeedsReview | Should -Be 2
        $report.Summary.AlreadySatisfied | Should -Be 1
        $report.Actions.Outcome | Should -Be @('Partially completed', 'Completed with issue', 'Already satisfied')
        $report.Actions[0].Details | Should -Match 'MoveActionResult: False'
    }

    It 'uses report-only mode for AD candidates and does not claim its ignored limit was hit' {
        $report = Get-CleanupEmailReport -Source AD -CurrentRun @([pscustomobject] @{ Action = 'Delete'; ActionStatus = $true }) -StageConfiguration @([pscustomobject] @{ Action = 'Delete'; Name = 'Delete'; Mode = 'Report only'; Candidates = 1; Limit = 1 })
        $report.Summary.Completed | Should -Be 0
        $report.Summary.ReportOnly | Should -Be 1
        $report.Summary.Limit | Should -Be '1 (not applied)'
    }

    It 'sums AD candidates across domains and reports fail-closed suppression' {
        $domains = @{ 'one.test' = @{ ComputersToBeDisabled = 3; Computers = @(1..3 | ForEach-Object { [pscustomobject] @{ Action = 'Disable' } }) }; 'two.test' = @{ ComputersToBeDisabled = 7; Computers = @(1..7 | ForEach-Object { [pscustomobject] @{ Action = 'Disable' } }) } }
        $stages = @(Get-ADComputerEmailStageConfiguration -Report $domains -Disable $true -DisableLimit 2 -Suppressed $true)
        $report = Get-CleanupEmailReport -Source AD -StageConfiguration $stages
        $report.Summary.Candidates | Should -Be 10
        $report.Summary.Remaining | Should -Be 10
        $report.Summary.Mode | Should -Be 'Suppressed'
        $report.Summary.Note | Should -Match 'inventory was incomplete'
        $report.Summary.Note | Should -Not -Match 'Limit reached'
    }

    It 'renders cloud audit fields, subaction failure notes and limit totals without treating previews as success' {
        $records = @(
            [pscustomobject] @{ Name = 'CLOUD-PREVIEW'; Action = 'Delete'; ActionStatus = 'WhatIf'; SelectionReason = 'Entra age=190 days'; EntraDeviceObjectId = 'entra-1'; HasEntraRecord = $true; HasIntuneRecord = $true; OwnerUserPrincipalName = 'owner@example.test'; ComplianceState = 'compliant'; IntuneLastSeenDays = 190 }
            [pscustomobject] @{ Name = 'CLOUD-FAILED'; Action = 'Delete'; ActionStatus = 'False'; ActionNotes = 'Intune: Record removed; Entra: Access denied'; AutopilotIdentityRemoved = $true }
        )
        $stages = @([pscustomobject] @{ Action = 'Delete'; Name = 'Delete'; Mode = 'Live'; Candidates = 10; Limit = 2 })
        $body = New-EmailBodyCloudDevices -CurrentRun $records -StageConfiguration $stages
        $text = [System.Net.WebUtility]::HtmlDecode(($body -replace '<[^>]+>', ' ')) -replace '\s+', ' '
        $text | Should -Match 'Candidates: 10; limit: 2; results: 2; remaining without a result: 8'
        $text | Should -Match 'Completed: 0; already satisfied: 0; WhatIf: 1'
        $text | Should -Match 'needs review: 1'
        $text | Should -Match 'Limit reached \(2\)'
        $text | Should -Match 'Failed overall \(check subactions\)'
        $text | Should -Match 'Intune: Record removed; Entra: Access denied'
        $audit = Get-CleanupEmailReport -Source Cloud -CurrentRun $records -StageConfiguration $stages
        $audit.Actions[0].Details | Should -Match 'owner@example.test'
        $audit.Actions[0].Details | Should -Match 'IntuneCompliance: compliant'
        $text | Should -Match 'Entra age=190 days'
    }

    It 'renders 500 results once in a static compact email table' {
        $records = @(1..500 | ForEach-Object {
            [pscustomobject] @{ Name = ('DEVICE-{0:0000}' -f $_); Action = 'Delete'; ActionStatus = 'True'; SelectionReason = 'Activity: 210 days; pending: 95 days' }
        })
        $body = New-EmailBodyCloudDevices -CurrentRun $records -StageConfiguration @([pscustomobject] @{ Action = 'Delete'; Name = 'Delete'; Mode = 'Live'; Candidates = 20000; Limit = 500 })
        [regex]::Matches($body, '>DEVICE-[0-9]{4}<').Count | Should -Be 500
        $body | Should -Match 'DEVICE-0500'
        $body | Should -Not -Match '<script'
        $text = [System.Net.WebUtility]::HtmlDecode(($body -replace '<[^>]+>', ' ')) -replace '\s+', ' '
        $text | Should -Match 'Completed: 500'
        $text | Should -Match 'Limit reached \(500\)'
        $text | Should -Match 'remaining without a result: 19500'
    }

    It 'distinguishes confirmation declined from a reached cloud limit' {
        $report = Get-CleanupEmailReport -Source Cloud -StageConfiguration @([pscustomobject] @{ Action = 'Disable'; Name = 'Disable'; Mode = 'Live'; Candidates = 50; Limit = 1; ConfirmationDeclined = $true })
        $report.Summary.Remaining | Should -Be 50
        $report.Summary.Note | Should -Match 'Confirmation declined'
        $report.Summary.Note | Should -Not -Match 'Limit reached'
    }

    It 'reports already-pending staging candidates without claiming a limit stop' {
        $report = Get-CleanupEmailReport -Source Cloud -CurrentRun @([pscustomobject] @{ Action = 'StageDelete'; ActionStatus = 'True' }) -StageConfiguration @([pscustomobject] @{ Action = 'StageDelete'; Name = 'Stage for delete'; Mode = 'Live'; Candidates = 5; Limit = 3 })
        $report.Summary.Completed | Should -Be 1
        $report.Summary.Remaining | Should -Be 4
        $report.Summary.Note | Should -Match 'skips or an early stop'
        $report.Summary.Note | Should -Not -Match 'Limit reached'
    }
}

AfterAll { Remove-Module PSWriteHTML -ErrorAction SilentlyContinue }
