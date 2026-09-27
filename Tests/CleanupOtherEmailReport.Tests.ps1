BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    foreach ($helper in @('Get-CleanupEmailActionOutcome','Get-CleanupEmailReport','Get-ServiceAccountSelectionReason','Get-ADServiceAccountsToProcess','Request-ADServiceAccountsDisable','Request-ADServiceAccountsDelete','Get-SIDHistoryEmailReport','Remove-ADSIDHistory')) {
        . (Get-CleanupMonsterPath "Private/$helper.ps1")
    }
    function Write-Color {}
    function Disable-ADAccount {}
    function Remove-ADObject {}
    function Set-ADObject {}
    function Get-ADObject {}
}
Describe 'Service account and SID cleanup email contracts' {
    It 'keeps per-domain service account limits and outcomes separate' {
        $stages = @('one.test','two.test') | ForEach-Object { [pscustomobject] @{Action='Disable';Name="Disable ($_; per-domain limit)";Domain=$_;Candidates=2;Limit=1;Mode='WhatIf'} }
        $records = @('one.test','two.test') | ForEach-Object { [pscustomobject] @{SamAccountName='gmsa';DomainName=$_;Action='Disable';ActionStatus='WhatIf'} }
        $report = Get-CleanupEmailReport -Source ServiceAccount -CurrentRun $records -StageConfiguration $stages
        $report.Summary.Count | Should -Be 2
        foreach ($stage in $report.Summary) {
            $stage.Results | Should -Be 1
            $stage.WhatIf | Should -Be 1
            $stage.Remaining | Should -Be 1
            $stage.Note | Should -Match 'Limit reached'
        }
    }
    It 'explains service-account ages and missing-date opt-ins' {
        $account = [pscustomobject] @{Name='gmsa';DistinguishedName='CN=gmsa,DC=test';LastLogonDate=$null;WhenCreated=(Get-Date).AddDays(-200)}
        $selected = Get-ADServiceAccountsToProcess -Type Disable -Accounts @($account) -ActionIf @{LastLogonDateMoreThan=90;TreatMissingLastLogonDateAsStale=$true;WhenCreatedMoreThan=180}
        $selected.SelectionReason | Should -Match 'LastLogonDays=unknown'
        $selected.SelectionReason | Should -Match 'WhenCreatedMoreThan=180'
    }
    It 'classifies service account errors and global WhatIf without claiming successful mutations' -ForEach @(
        @{Action='Disable'}
        @{Action='Delete'}
    ) {
        $account = [pscustomobject] @{SamAccountName='gmsa';DistinguishedName='CN=gmsa,DC=test';Action=$Action;ActionStatus=$null;ActionDate=$null;ActionComment=$null}
        $request = "Request-ADServiceAccounts$Action"
        $parameters = @{Accounts=@($account);Today=Get-Date;WhatIf=$true}
        $result = & $request @parameters
        $result.ActionStatus | Should -Be 'WhatIf'
        (Get-CleanupEmailActionOutcome -Record $result -Source ServiceAccount).Category | Should -Be 'WhatIf'
        $result.ActionComment='backend error'
        (Get-CleanupEmailActionOutcome -Record $result -Source ServiceAccount).Category | Should -Be 'NeedsReview'
    }
    It 'counts SID results individually despite cumulative removed SID snapshots' {
        $export = @{EmailMode='Live';ObjectsToProcess=@([pscustomobject] @{SIDHistoryToRemove=@('SID-1','SID-2','SID-3')});RemoveLimitObject=1;RemoveLimitSID=2;SIDLimitStoppedIteration=$true;ObjectCollectionLimitReached=$true;CurrentRun=@(
            [pscustomobject] @{ObjectName='User';SIDAttempted='SID-1';SIDRemoved=@('SID-1');ActionStatus='Success'}
            [pscustomobject] @{ObjectName='User';SIDAttempted='SID-2';SIDRemoved=@('SID-1');ActionStatus='Failed';ActionError='access denied'}
        )}
        $report=Get-SIDHistoryEmailReport -Export $export
        $report.Actions.Count | Should -Be 2
        $report.Summary.Completed | Should -Be 1
        $report.Summary.NeedsReview | Should -Be 1
        $report.Summary.Remaining | Should -Be 1
        $report.Summary.Note | Should -Match 'SID limit stopped'
        $report.Actions[1].Reason | Should -Match 'SID-2'
    }
    It 'shows selected report-only SID candidates without claiming removals' {
        $export=@{EmailMode='Report only';ObjectsToProcess=@([pscustomobject] @{Object=[pscustomobject] @{Name='User';Domain='test'};SIDHistoryToRemove=@('SID-1','SID-2')});CurrentRun=@();RemoveLimitObject=1;RemoveLimitSID=1}
        $report=Get-SIDHistoryEmailReport -Export $export
        $report.Summary.ReportOnly | Should -Be 2
        $report.Summary.Completed | Should -Be 0
        $report.Summary.Note | Should -Match 'SID removal limit is not applied'
    }
    It 'checks the attempted SID after successful removal while preserving preview semantics' -ForEach @(
        @{ Preview=$false; StillPresent=$true; NeedsReview=1; Completed=0; PreviewCount=0 }
        @{ Preview=$false; StillPresent=$false; NeedsReview=0; Completed=1; PreviewCount=0 }
        @{ Preview=$true; StillPresent=$true; NeedsReview=0; Completed=0; PreviewCount=1 }
    ) {
        Mock Set-ADObject {}
        Mock Get-ADObject { [pscustomobject] @{SIDHistory=if ($StillPresent) {@('SID-1','SID-OTHER')} else {@('SID-OTHER')}} }
        $export=@{History=[System.Collections.Generic.List[pscustomobject]]::new()}
        $items=@([pscustomobject] @{Object=[pscustomobject] @{Name='User';Domain='test';DistinguishedName='CN=User,DC=test';SIDHistory=@('SID-1','SID-OTHER')};SIDHistoryToRemove=@('SID-1');QueryServer='dc.test'})
        Remove-ADSIDHistory -ObjectsToProcess $items -Export $export -RemoveLimitSID 1 -Confirm:$false -WhatIf:$Preview
        $export.ObjectsToProcess=$items
        $export.EmailMode=if ($Preview) {'WhatIf'} else {'Live'}
        $report=Get-SIDHistoryEmailReport -Export $export
        $report.Summary.NeedsReview | Should -Be $NeedsReview
        $report.Summary.Completed | Should -Be $Completed
        $report.Summary.WhatIf | Should -Be $PreviewCount
        if ($NeedsReview) {
            $export.History[0].VerificationError | Should -Match 'SID-1 is still present'
            $export.CurrentRun[0].SIDAfterTargetedCount | Should -Be 1
            $report.Actions[0].Notes | Should -Not -Match 'counts are unknown'
        }
    }
    It 'records verification failure without zero remaining SID counts' {
        Mock Set-ADObject {}
        Mock Get-ADObject { throw 'reread failed' }
        $export=@{History=[System.Collections.Generic.List[pscustomobject]]::new()}
        $items=@([pscustomobject] @{Object=[pscustomobject] @{Name='User';Domain='test';DistinguishedName='CN=User,DC=test';SIDHistory=@('SID-1')};SIDHistoryToRemove=@('SID-1');QueryServer='dc.test'})
        Remove-ADSIDHistory -ObjectsToProcess $items -Export $export -RemoveLimitSID 1 -Confirm:$false
        $export.CurrentRun[0].SIDAttempted | Should -Be 'SID-1'
        $export.CurrentRun[0].SIDAfterTargetedCount | Should -BeNullOrEmpty
        $export.CurrentRun[0].VerificationError | Should -Be 'reread failed'
        $export.History[0].VerificationError | Should -Be 'reread failed'
        $export.ObjectsToProcess=$items
        $export.EmailMode='Live'
        $report=Get-SIDHistoryEmailReport -Export $export
        $report.Actions[0].Outcome | Should -Be 'Completed; verification failed'
        $report.Summary.NeedsReview | Should -Be 1
    }
}
