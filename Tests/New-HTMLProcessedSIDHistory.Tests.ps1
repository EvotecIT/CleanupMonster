BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/New-HTMLProcessedSIDHistory.ps1')
}

Describe 'New-HTMLProcessedSIDHistory' {
    BeforeEach {
        $script:HtmlConditionNames = [System.Collections.Generic.List[string]]::new()

        function New-HTML {
            param(
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function New-HTMLSectionStyle {}
        function New-HTMLTableOption {}
        function New-HTMLTabStyle {}

        function New-HTMLHeader {
            param(
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function New-HTMLSection {
            param(
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function New-HTMLPanel {
            param(
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function New-HTMLText {}

        function New-HTMLList {
            param(
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function New-HTMLListItem {}

        function New-HTMLTab {
            param(
                [string] $Name,
                [scriptblock] $Content
            )

            if ($Content) {
                & $Content
            }
        }

        function New-HTMLTable {
            param(
                $DataTable,
                [scriptblock] $Filtering
            )

            if ($Filtering) {
                & $Filtering
            }
        }

        function New-HTMLTableCondition {
            param(
                [string] $Name
            )

            $null = $script:HtmlConditionNames.Add($Name)
        }

        function New-HTMLCodeBlock {}
    }

    It 'uses targeted SID counts for HTML highlighting' {
        $export = @{
            Version          = '3.1.7'
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

        $forestInformation = @{
            Forest = 'contoso.com'
        }

        $output = @{
            All          = @()
            Statistics   = [PSCustomObject]@{
                TotalUsers      = 0
                TotalGroups     = 0
                TotalComputers  = 0
                EnabledObjects  = 0
                DisabledObjects = 0
                InternalSIDs    = 0
                ExternalSIDs    = 0
                UnknownSIDs     = 0
            }
            Trusts       = @()
            DomainSIDs   = @{}
            DuplicateSIDs = @()
        }

        New-HTMLProcessedSIDHistory -Export $export -ForestInformation $forestInformation -Output $output -FilePath 'report.html' -Configuration @{}

        $script:HtmlConditionNames | Should -Contain 'SIDBeforeTargetedCount'
        $script:HtmlConditionNames | Should -Contain 'SIDAfterTargetedCount'
        $script:HtmlConditionNames | Should -Not -Contain 'SIDBeforeCount'
        $script:HtmlConditionNames | Should -Not -Contain 'SIDAfterCount'
    }
}
