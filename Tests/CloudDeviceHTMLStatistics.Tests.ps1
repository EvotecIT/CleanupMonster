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
                [pscustomobject] @{ OperatingSystem = 'Android'; Enabled = $true; LastSeenDays = $null }
            ) -PassThru
            $intune = Write-CloudDeviceStatistics -Label 'Intune seen' -Mode Intune -Devices @(
                [pscustomobject] @{ OperatingSystem = 'macOS'; LastSeenDays = 210 }
            ) -PassThru
            $scopeDevice = [pscustomobject] @{ Name = 'PC-01'; OperatingSystem = 'Windows'; Enabled = $true; HasEntraRecord = $true; EntraLastSeenDays = 200; RecordState = 'EntraOnly'; IntuneLinkState = 'NotClaimed' }
            $intuneOnlyDevice = [pscustomobject] @{ Name = 'TABLET-02'; OperatingSystem = 'Android'; Enabled = $null; HasEntraRecord = $false; EntraLastSeenDays = $null; RecordState = 'IntuneOnly'; IntuneLinkState = 'IntuneOnly' }
            $scope = Write-CloudDeviceStatistics -Label 'Cleanup scope' -Mode Scoped -Devices @($scopeDevice, $intuneOnlyDevice) -PassThru
            $candidate = Write-CloudDeviceStatistics -Label 'Disable candidates' -Mode Candidates -Devices @($scopeDevice) -PassThru
            $autopilotDevice = [pscustomobject] @{ Name = 'AP-03'; OperatingSystem = 'Windows'; Enabled = $false; HasEntraRecord = $true; EntraLastSeenDays = 210; RecordState = 'Matched'; IntuneLinkState = 'Healthy'; AutopilotDeviceId = 'autopilot-identity-03'; AutopilotSerialNumber = 'SERIAL-03' }
            $autopilotScope = Write-CloudDeviceStatistics -Label 'Autopilot removal scope' -Mode Scoped -Devices @($autopilotDevice) -PassThru
            $autopilotEntra = Write-CloudDeviceStatistics -Label 'Autopilot Entra seen' -Mode Entra -Devices @($autopilotDevice) -PassThru
            $autopilotIntune = Write-CloudDeviceStatistics -Label 'Autopilot Intune seen' -Mode Intune -Devices @([pscustomobject] @{ OperatingSystem = 'Windows'; LastSeenDays = 210 }) -PassThru
            $statistics = [ordered] @{
                Entra = $entra; Intune = $intune; Scope = $scope
                Candidates = @($candidate); CandidateTotals = [ordered] @{ Disable = 1; Delete = 0 }
                AutopilotScope = $autopilotScope; AutopilotEntra = $autopilotEntra; AutopilotIntune = $autopilotIntune
            }
            $preview = [pscustomobject] @{ Name = 'PC-01'; Action = 'Disable'; ActionStatus = 'WhatIf'; ActionDate = [datetime] '2026-09-25'; OperatingSystem = 'Windows'; SelectionReason = 'Entra age 200 days'; EntraDeviceObjectId = 'entra-1' }
            $autopilotPreview = [pscustomobject] @{ Name = 'AP-03'; Action = 'RemoveAutopilotIdentity'; ActionStatus = 'WhatIf'; ActionDate = [datetime] '2026-09-25'; OperatingSystem = 'Windows'; SelectionReason = 'Autopilot contact 210 days'; AutopilotDeviceId = 'autopilot-identity-03'; AutopilotSerialNumber = 'SERIAL-03' }
            $export = [ordered] @{ Version = 'test'; CurrentRun = @($preview, $autopilotPreview); History = @($preview, $autopilotPreview); PendingActions = [ordered] @{} }
            New-HTMLProcessedCloudDevices -Export $export -Devices @($scopeDevice, $intuneOnlyDevice, $autopilotDevice) -PrimaryDeviceCount 2 -Statistics $statistics -RetireOnlyIf ([ordered] @{ LastSeenEntraMoreThan = 90 }) -DisableOnlyIf ([ordered] @{ LastSeenEntraMoreThan = 90 }) -DeleteOnlyIf ([ordered] @{ LastSeenEntraMoreThan = 180 }) -FilePath $FilePath
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
        $html | Should -Match 'Overview'
        $html | Should -Match 'Entra inventory by OS'
        $html | Should -Match 'Intune inventory by OS'
        $html | Should -Match 'What entered cleanup scope'
        $html | Should -Match 'OS quick view'
        $html | Should -Match 'Detailed inventory counts'
        $html | Should -Match 'In cleanup scope, by OS'
        $html | Should -Match 'Enabled, Entra old 90d'
        $html | Should -Match 'macOS'
        $html | Should -Match 'What the rules selected'
        $html | Should -Match 'Entra seen'
        $html | Should -Match 'Separate Autopilot removal query'
        $html | Should -Match 'Source and link state within this scope'
        $html | Should -Match 'WhatIf preview'
        $html | Should -Match 'Entra age 200 days'
        $html | Should -Match 'Activity unknown'
        $html | Should -Match 'No Entra record'
        $html | Should -Match 'autopilot-identity-03'
        $html | Should -Match 'Autopilot removal only'
        $html | Should -Not -Match 'No action history has been recorded yet'
        $html | Should -Not -Match 'Entra records by OS'
    }
}
