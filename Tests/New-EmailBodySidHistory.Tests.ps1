BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-SIDHistoryEmailReport.ps1')
    . (Get-CleanupMonsterPath 'Private/New-EmailBodySidHistory.ps1')
    function New-EmailBodyCleanup { param($Title,$Report,$ObjectLabel) $script:sidEmailReport=$Report; 'EmailBody' }
}
Describe 'New-EmailBodySidHistory' {
    It 'passes targeted per-SID outcomes to the shared email renderer' {
        $export=@{EmailMode='WhatIf';ObjectsToProcess=@();CurrentRun=@([pscustomobject] @{ObjectName='User';SIDAttempted='SID-1';SIDBeforeTargetedCount=2;ActionStatus='WhatIf'})}
        New-EmailBodySidHistory -Export $export | Should -Be 'EmailBody'
        $script:sidEmailReport.Actions[0].Reason | Should -Match 'SID-1'
        $script:sidEmailReport.Summary.WhatIf | Should -Be 1
        $script:sidEmailReport.Summary.Completed | Should -Be 0
    }
}
