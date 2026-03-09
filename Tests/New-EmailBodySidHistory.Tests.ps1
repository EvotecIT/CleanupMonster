BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/New-EmailBodySidHistory.ps1')
}

Describe 'New-EmailBodySidHistory' {
    BeforeEach {
        $script:EmailConditionNames = [System.Collections.Generic.List[string]]::new()

        function EmailBody {
            param(
                [scriptblock] $EmailBody
            )

            & $EmailBody
            'EmailBody'
        }

        function EmailText {}
        function New-HTMLText {}

        function EmailList {
            param(
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function EmailListItem {}

        function EmailTable {
            param(
                $DataTable,
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function EmailTableCondition {
            param(
                [string] $Name
            )

            $null = $script:EmailConditionNames.Add($Name)
        }
    }

    It 'uses targeted SID counts for email highlighting' {
        $export = @{
            CurrentRun       = @(
                [PSCustomObject]@{
                    Enabled                = $true
                    SIDBeforeTargetedCount = 1
                    SIDAfterTargetedCount  = 0
                    Action                 = 'RemovePerSID'
                    ActionStatus           = 'Success'
                }
            )
            ProcessedObjects = 1
            ProcessedSIDs    = 1
        }

        $result = New-EmailBodySidHistory -Export $export

        $result | Should -Be 'EmailBody'
        $script:EmailConditionNames | Should -Contain 'SIDBeforeTargetedCount'
        $script:EmailConditionNames | Should -Contain 'SIDAfterTargetedCount'
        $script:EmailConditionNames | Should -Not -Contain 'SIDBeforeCount'
        $script:EmailConditionNames | Should -Not -Contain 'SIDAfterCount'
    }
}
