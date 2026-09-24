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
        ($script:statisticsLines -join "`n") | Should -Match 'Enabled state by OS:'
        ($script:statisticsLines -join "`n") | Should -Match 'Entra activity age by OS'
        ($script:statisticsLines -join "`n") | Should -Match 'Enabled with old Entra activity'
        $allRows = @($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' })
        $allRows | Should -HaveCount 3
        $allRows[0] | Should -Match '5\s+3\s+2\s+0$'
        $allRows[1] | Should -Match '1\s+1\s+2\s+1$'
        $allRows[2] | Should -Match '2\s+1$'
        $macRows = @($script:statisticsLines | Where-Object { $_ -match '^\[i\] macOS\s' })
        $macRows | Should -HaveCount 3
        $macRows[0] | Should -Match '2\s+1\s+1\s+0$'
        $macRows[1] | Should -Match '0\s+0\s+1\s+1$'
        $macRows[2] | Should -Match '1\s+1$'
        Assert-MockCalled Write-Color -ParameterFilter { $LogFile -eq 'inventory.log' } -Times $script:statisticsLines.Count -Exactly
    }

    It 'separates Intune sync ages and does not invent enabled state' {
        Write-CloudDeviceStatistics -Label 'Intune seen' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Android'; LastSeenDays = 20 }
            [pscustomobject] @{ OperatingSystem = 'macOS'; LastSeenDays = 250 }
            [pscustomobject] @{ OperatingSystem = 'macOS'; LastSeenDays = $null }
        ) -Mode Intune

        ($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' }) | Should -Match '1\s+0\s+1\s+1$'
        ($script:statisticsLines -join "`n") | Should -Match 'Intune sync age by OS'
        ($script:statisticsLines -join "`n") | Should -Not -Match 'Enabled state by OS'
    }

    It 'shows correlated scope separately from Entra and Intune source totals' {
        Write-CloudDeviceStatistics -Label 'Cleanup scope' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $true; EntraLastSeenDays = 200; HasEntraRecord = $true; RecordState = 'Matched'; IntuneLinkState = 'Healthy' }
            [pscustomobject] @{ OperatingSystem = 'iOS'; Enabled = $null; EntraLastSeenDays = $null; HasEntraRecord = $false; RecordState = 'IntuneOnly'; IntuneLinkState = 'IntuneOnly' }
        ) -Mode Scoped

        $allRows = @($script:statisticsLines | Where-Object { $_ -match '^\[i\] ALL\s' })
        $allRows | Should -HaveCount 3
        $allRows[0] | Should -Match '2\s+1\s+0\s+1$'
        $allRows[1] | Should -Match '0\s+0\s+1\s+0\s+1$'
        $allRows[2] | Should -Match '1\s+1$'
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
        ($script:statisticsLines -join "`n") | Should -Not -Match 'activity age by OS'
        ($script:statisticsLines -join "`n") | Should -Not -Match 'macOS'
        $script:statisticsLines[0] | Should -Match 'after rules'
    }

    It 'keeps every log message short enough for a typical log viewer' {
        Write-CloudDeviceStatistics -Label 'Entra seen (requested join types; before OS filters)' -Devices @(
            [pscustomobject] @{ OperatingSystem = 'Windows'; Enabled = $true; LastSeenDays = 200 }
        ) -Mode Entra

        ($script:statisticsLines | ForEach-Object Length | Measure-Object -Maximum).Maximum | Should -BeLessOrEqual 80
    }

    It 'explains the Other OS bucket without printing every raw label' {
        $devices = @(
            [pscustomobject] @{ OperatingSystem = 'Linux'; Enabled = $true; LastSeenDays = 10 }
            [pscustomobject] @{ OperatingSystem = 'Linux'; Enabled = $true; LastSeenDays = 20 }
            [pscustomobject] @{ OperatingSystem = 'Chrome OS'; Enabled = $true; LastSeenDays = 30 }
        )
        Write-CloudDeviceStatistics -Label 'Entra seen' -Devices $devices -Mode Entra

        ($script:statisticsLines -join "`n") | Should -Match 'Other OS labels in this source'
        ($script:statisticsLines -join "`n") | Should -Match 'Linux\s+2'
        ($script:statisticsLines -join "`n") | Should -Match 'Chrome OS\s+1'
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
