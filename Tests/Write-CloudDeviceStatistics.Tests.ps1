BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Write-CloudDeviceStatistics.ps1')
    function Write-Color { param([object[]] $Text, [object[]] $Color, [string] $LogFile) }
}

Describe 'Write-CloudDeviceStatistics' {
    BeforeEach {
        $script:statisticsLines = [System.Collections.Generic.List[string]]::new()
        Mock Write-Color { $script:statisticsLines.Add(($Text -join '')) }
    }

    It 'shows every seen OS and its enabled stale counts before cleanup filtering' {
        $devices = @(
            [pscustomobject] @{ OperatingSystem = 'Windows 11'; Enabled = $true; LastSeenDays = 20 }
            [pscustomobject] @{ OperatingSystem = 'AndroidEnterprise'; Enabled = $false; LastSeenDays = 220 }
            [pscustomobject] @{ OperatingSystem = 'iOS'; Enabled = $true; LastSeenDays = 120 }
            [pscustomobject] @{ OperatingSystem = 'macOS'; Enabled = $true; LastSeenDays = 220 }
            [pscustomobject] @{ OperatingSystem = 'Mac OS X'; Enabled = $false; LastSeenDays = $null }
        )

        Write-CloudDeviceStatistics -Label 'Entra seen' -Devices $devices -Mode Entra -LogPath 'inventory.log'

        $script:statisticsLines[0] | Should -Match 'Entra seen: 5 record'
        ($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' }) | Should -Match '5\s+3\s+2\s+0\s+3\s+2\s+2\s+1\s+1$'
        ($script:statisticsLines | Where-Object { $_ -match '^\[i\] macOS\s' }) | Should -Match '2\s+1\s+1\s+0\s+1\s+1\s+1\s+1\s+1$'
        Assert-MockCalled Write-Color -ParameterFilter { $LogFile -eq 'inventory.log' } -Times $script:statisticsLines.Count -Exactly
    }

    It 'separates Intune sync ages and does not invent enabled state' {
        Write-CloudDeviceStatistics -Label 'Intune seen' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Android'; LastSeenDays = 20 }
            [pscustomobject] @{ OperatingSystem = 'macOS'; LastSeenDays = 250 }
            [pscustomobject] @{ OperatingSystem = 'macOS'; LastSeenDays = $null }
        ) -Mode Intune

        ($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' }) | Should -Match '3\s+1\s+0\s+1\s+1$'
        ($script:statisticsLines -join "`n") | Should -Not -Match 'On>90'
    }

    It 'shows correlated scope separately from Entra and Intune source totals' {
        Write-CloudDeviceStatistics -Label 'Cleanup scope' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $true; EntraLastSeenDays = 200; HasEntraRecord = $true; RecordState = 'Matched'; IntuneLinkState = 'Healthy' }
            [pscustomobject] @{ OperatingSystem = 'iOS'; Enabled = $null; EntraLastSeenDays = $null; HasEntraRecord = $false; RecordState = 'IntuneOnly'; IntuneLinkState = 'IntuneOnly' }
        ) -Mode Scoped

        ($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' }) | Should -Match '2\s+1\s+0\s+1\s+1\s+1\s+1\s+1\s+0$'
        ($script:statisticsLines -join "`n") | Should -Match 'NoEntra=1'
        ($script:statisticsLines -join "`n") | Should -Match 'Matched=1; EntraOnly=0; IntuneOnly=1'
        ($script:statisticsLines -join "`n") | Should -Not -Match '^\[i\] macOS\s'
    }

    It 'shows only selected candidates by OS and enabled state' {
        Write-CloudDeviceStatistics -Label 'Disable candidates (after rules)' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $true }
            [pscustomobject] @{ OperatingSystem = 'Android'; Enabled = $false }
        ) -Mode Candidates

        ($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' }) | Should -Match '2\s+1\s+1\s+0$'
        ($script:statisticsLines -join "`n") | Should -Not -Match 'macOS'
        $script:statisticsLines[0] | Should -Match 'after rules'
    }

    It 'keeps every log message short enough for a typical log viewer' {
        Write-CloudDeviceStatistics -Label 'Entra seen (requested join types; before OS filters)' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $true; LastSeenDays = 200 }
        ) -Mode Entra

        ($script:statisticsLines | ForEach-Object Length | Measure-Object -Maximum).Maximum | Should -BeLessOrEqual 98
    }

    It 'returns the same aggregate data for the HTML report without individual devices' {
        $summary = Write-CloudDeviceStatistics -Label 'Entra seen' -Mode Entra -Devices @(
            [pscustomobject] @{ Name = 'MAC-01'; OperatingSystem = 'macOS'; Enabled = $true; LastSeenDays = 210 }
            [pscustomobject] @{ Name = 'PC-01'; OperatingSystem = 'Windows'; Enabled = $false; LastSeenDays = 10 }
        ) -PassThru

        $summary.Total | Should -Be 2
        $mac = $summary.Rows | Where-Object OS -EQ macOS
        $mac.EnabledOver180 | Should -Be 1
        $mac.PSObject.Properties.Name | Should -Not -Contain 'Name'
        $summary.Rows | Should -HaveCount 3
    }
}
