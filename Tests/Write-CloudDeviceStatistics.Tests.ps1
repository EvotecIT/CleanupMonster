BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Write-CloudDeviceStatistics.ps1')
    function Write-Color { param([object[]] $Text, [object[]] $Color, [string] $LogFile) }
}

Describe 'Write-CloudDeviceStatistics' {
    It 'reports scoped OS, correlation, and activity counts without double-counting records' {
        $script:statisticsLines = [System.Collections.Generic.List[string]]::new()
        Mock Write-Color { $script:statisticsLines.Add(($Text -join '')) }

        $devices = @(
            [pscustomobject] @{ OperatingSystem = 'Windows 11'; RecordState = 'Matched'; IntuneLinkState = 'Healthy'; Enabled = $true; HasEntraRecord = $true; EntraLastSeenDays = 20 }
            [pscustomobject] @{ OperatingSystem = 'AndroidEnterprise'; RecordState = 'EntraOnly'; IntuneLinkState = 'Broken'; Enabled = $false; HasEntraRecord = $true; EntraLastSeenDays = 220 }
            [pscustomobject] @{ OperatingSystem = 'iOS'; RecordState = 'EntraOnly'; IntuneLinkState = 'NotClaimed'; Enabled = $true; HasEntraRecord = $true; EntraLastSeenDays = 120 }
            [pscustomobject] @{ OperatingSystem = 'iPadOS'; RecordState = 'IntuneOnly'; IntuneLinkState = 'IntuneOnly'; Enabled = $null; HasEntraRecord = $false; EntraLastSeenDays = $null }
            [pscustomobject] @{ OperatingSystem = 'macOS'; RecordState = 'EntraOnly'; IntuneLinkState = 'Broken'; Enabled = $true; HasEntraRecord = $true; EntraLastSeenDays = $null }
        )

        Write-CloudDeviceStatistics -Label 'Cloud inventory' -Devices $devices -IncludeActivityAge -LogPath 'inventory.log'

        $script:statisticsLines.Count | Should -Be 3
        $script:statisticsLines[0] | Should -Match '5 record\(s\); OS Windows=1, Android=1, iOS=1, iPadOS=1, macOS=1, Other=0, Unknown=0'
        $script:statisticsLines[1] | Should -Match 'Matched=1, EntraOnly=3, IntuneOnly=1, Other=0; IntuneLink Healthy=1, Broken=2, NotClaimed=1, IntuneOnly=1, Other=0; Enabled=3, Disabled=1, Unknown=1'
        $script:statisticsLines[2] | Should -Match '<=90d=1, 91-180d=1, >180d=1, Unknown=1, NoEntraRecord=1'
        Assert-MockCalled Write-Color -Times 3 -Exactly -ParameterFilter { $LogFile -eq 'inventory.log' }
    }

    It 'reports an empty scoped inventory without inventing device counts' {
        $script:statisticsLines = [System.Collections.Generic.List[string]]::new()
        Mock Write-Color { $script:statisticsLines.Add(($Text -join '')) }

        Write-CloudDeviceStatistics -Label 'Cloud inventory' -Devices @() -IncludeActivityAge

        $script:statisticsLines[0] | Should -Match '0 record\(s\)'
        $script:statisticsLines[2] | Should -Match '<=90d=0, 91-180d=0, >180d=0, Unknown=0, NoEntraRecord=0'
    }
}
