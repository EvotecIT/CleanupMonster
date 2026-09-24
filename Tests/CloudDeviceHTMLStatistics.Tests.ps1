Describe 'Cloud device HTML inventory overview' {
    It 'renders source, scoped, and candidate statistics with macOS visible in source data' {
        $reportPath = Join-Path $TestDrive 'CloudInventory.html'
        $root = Split-Path -Parent $PSScriptRoot
        $job = Start-Job -ScriptBlock {
            param($RepositoryRoot, $FilePath)

            $ErrorActionPreference = 'Stop'
            Import-Module PSWriteHTML -MinimumVersion 1.41.0 -ErrorAction Stop
            . (Join-Path $RepositoryRoot 'Private/Write-CloudDeviceStatistics.ps1')
            . (Join-Path $RepositoryRoot 'Private/New-HTMLCloudDeviceInventoryOverview.ps1')
            . (Join-Path $RepositoryRoot 'Private/New-HTMLProcessedCloudDevices.ps1')
            function Write-Color { param([object[]] $Text, [object[]] $Color, [string] $LogFile) }

            $entra = Write-CloudDeviceStatistics -Label 'Entra seen' -Mode Entra -Devices @(
                [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $true; LastSeenDays = 200 }
                [pscustomobject] @{ OperatingSystem = 'macOS'; Enabled = $true; LastSeenDays = 220 }
            ) -PassThru
            $intune = Write-CloudDeviceStatistics -Label 'Intune seen' -Mode Intune -Devices @(
                [pscustomobject] @{ OperatingSystem = 'macOS'; LastSeenDays = 210 }
            ) -PassThru
            $scopeDevice = [pscustomobject] @{ Name = 'PC-01'; OperatingSystem = 'Windows'; Enabled = $true; HasEntraRecord = $true; EntraLastSeenDays = 200; RecordState = 'EntraOnly'; IntuneLinkState = 'NotClaimed' }
            $scope = Write-CloudDeviceStatistics -Label 'Cleanup scope' -Mode Scoped -Devices @($scopeDevice) -PassThru
            $candidate = Write-CloudDeviceStatistics -Label 'Disable candidates' -Mode Candidates -Devices @($scopeDevice) -PassThru
            $autopilotDevice = [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $false; HasEntraRecord = $true; EntraLastSeenDays = 210; RecordState = 'Matched'; IntuneLinkState = 'Healthy' }
            $autopilotScope = Write-CloudDeviceStatistics -Label 'Autopilot removal scope' -Mode Scoped -Devices @($autopilotDevice) -PassThru
            $autopilotEntra = Write-CloudDeviceStatistics -Label 'Autopilot Entra seen' -Mode Entra -Devices @($autopilotDevice) -PassThru
            $autopilotIntune = Write-CloudDeviceStatistics -Label 'Autopilot Intune seen' -Mode Intune -Devices @([pscustomobject] @{ OperatingSystem = 'Windows'; LastSeenDays = 210 }) -PassThru
            $statistics = [ordered] @{
                Entra = $entra; Intune = $intune; Scope = $scope
                Candidates = @($candidate); CandidateTotals = [ordered] @{ Disable = 1; Delete = 0 }
                AutopilotScope = $autopilotScope; AutopilotEntra = $autopilotEntra; AutopilotIntune = $autopilotIntune
            }
            $export = [ordered] @{ Version = 'test'; CurrentRun = @(); History = @(); PendingActions = [ordered] @{} }
            New-HTMLProcessedCloudDevices -Export $export -Devices @($scopeDevice) -Statistics $statistics -RetireOnlyIf ([ordered] @{ LastSeenEntraMoreThan = 90 }) -DisableOnlyIf ([ordered] @{ LastSeenEntraMoreThan = 90 }) -DeleteOnlyIf ([ordered] @{ LastSeenEntraMoreThan = 180 }) -FilePath $FilePath
        } -ArgumentList $root, $reportPath

        try {
            $completed = $job | Wait-Job -Timeout 60
            $completed | Should -Not -BeNullOrEmpty
            $job.State | Should -Be 'Completed'
            Receive-Job -Job $job -ErrorAction Stop | Out-Null
        } finally {
            Remove-Job -Job $job -Force
        }

        Test-Path -LiteralPath $reportPath | Should -BeTrue
        $html = Get-Content -LiteralPath $reportPath -Raw
        $html | Should -Match 'Inventory Overview'
        $html | Should -Match 'Entra records by OS'
        $html | Should -Match 'Intune records by OS'
        $html | Should -Match 'Cleanup scope by OS'
        $html | Should -Match 'Enabled with old Entra activity by OS'
        $html | Should -Match 'macOS'
        $html | Should -Match 'Selected by action rules'
        $html | Should -Match 'Primary Entra seen'
        $html | Should -Match 'Autopilot Entra seen: 1 records'
        $html | Should -Match 'Autopilot Intune seen: 1 records'
        $html | Should -Match 'Record source within cleanup scope'
        $html | Should -Match 'Intune link within cleanup scope'
        $html | Should -Match 'Autopilot scope record source'
        $html | Should -Match 'Autopilot scope Intune link'
    }
}
