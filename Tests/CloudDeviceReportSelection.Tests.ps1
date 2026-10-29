BeforeAll {
    . (Join-Path $PSScriptRoot '../Private/Test-CloudDeviceReportIdentity.ps1')
    . (Join-Path $PSScriptRoot '../Private/Get-CloudDeviceReportSelection.ps1')
}

Describe 'Bounded cloud device review selection' {
    It 'prioritizes current actions, pending records and actual rule candidates before inventory age' {
        $devices = @(
            [pscustomobject]@{Name='Inventory';EntraDeviceObjectId='old';EntraLastSeenDays=9000}
            [pscustomobject]@{Name='Candidate';EntraDeviceObjectId='candidate';EntraLastSeenDays=200}
            [pscustomobject]@{Name='Pending';EntraDeviceObjectId='pending';EntraLastSeenDays=100}
            [pscustomobject]@{Name='Current';EntraDeviceObjectId='current';EntraLastSeenDays=1}
        )
        $export = @{CurrentRun=@($devices[3]);PendingActions=@{pending=$devices[2]}}
        $rows = @(Get-CloudDeviceReportSelection -Devices $devices -Export $export -CandidateDevices @($devices[1]) -Limit 3)
        $rows.Count | Should -Be 3
        $rows[0].Device.Name | Should -Be 'Current'
        $rows[1].Device.Name | Should -Be 'Pending'
        $rows[2].Device.Name | Should -Be 'Candidate'
        $rows.Reason -join ',' | Should -Be 'Current run,Pending action,Rule candidate'
        $devices.Count | Should -Be 4
    }

    It 'caps default details at 500 while preserving oldest known activity and stable ties' {
        $devices = @(for ($i=0; $i -lt 510; $i++) {
            [pscustomobject]@{Name="Device-$i";EntraDeviceObjectId="object-$i";EntraLastSeenDays=$i}
        })
        $rows = @(Get-CloudDeviceReportSelection -Devices $devices -Export @{CurrentRun=@();PendingActions=@{}})
        $rows.Count | Should -Be 500
        $rows[0].Device.Name | Should -Be 'Device-509'
        $rows[-1].Device.Name | Should -Be 'Device-10'
        $rows[0].Reason | Should -Be 'Inventory sample'
        $devices[508].EntraLastSeenDays = 509
        $tied = @(Get-CloudDeviceReportSelection -Devices $devices -Export @{CurrentRun=@();PendingActions=@{}} -Limit 2)
        $tied.Device.Name -join ',' | Should -Be 'Device-508,Device-509'
    }

    It 'does not prioritize an unrelated target that shares an Azure alias' {
        $current = [pscustomobject]@{Name='Same';ManagedDeviceId='intune-one';DeviceId='shared';EntraLastSeenDays=1}
        $other = [pscustomobject]@{Name='Same';ManagedDeviceId='intune-two';DeviceId='shared';EntraLastSeenDays=9000}
        $rows = @(Get-CloudDeviceReportSelection -Devices @($other,$current) -Export @{CurrentRun=@($current);PendingActions=@{}} -Limit 1)
        $rows[0].Device.ManagedDeviceId | Should -Be 'intune-one'
        $rows[0].CurrentActions.Count | Should -Be 1
        $rows[0].Index | Should -Be 1
    }
}
