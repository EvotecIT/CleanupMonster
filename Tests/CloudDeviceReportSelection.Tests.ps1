BeforeAll {
    . (Join-Path $PSScriptRoot '../Private/Test-CloudDeviceReportIdentity.ps1')
    . (Join-Path $PSScriptRoot '../Private/Get-CloudDeviceReportSelection.ps1')
}

Describe 'Complete cloud device report correlation' {
    It 'retains every device including inventory beyond the old sample boundary and candidates beyond action limits' {
        $devices = @(for ($i = 0; $i -lt 510; $i++) {
            [pscustomobject] @{ Name = "Device-$i"; EntraDeviceObjectId = "object-$i"; EntraLastSeenDays = $i }
        })
        $first = $devices[0] | Select-Object *
        $first | Add-Member Action Disable
        $first | Add-Member SelectionReason 'Entra age >90'
        $last = $devices[-1] | Select-Object *
        $last | Add-Member Action Delete
        $last | Add-Member SelectionReason 'Entra age >180; disabled'
        $rows = @(Get-CloudDeviceReportSelection -Devices $devices -Export @{CurrentRun=@($first);PendingActions=@{}} -CandidateDevices @($first, $last))
        $rows.Count | Should -Be 510
        $rows[0].Device.Name | Should -Be 'Device-0'
        $rows[-1].Device.Name | Should -Be 'Device-509'
        $rows[-1].CurrentActions.Count | Should -Be 0
        $rows[-1].Candidates[0].Action | Should -Be 'Delete'
        $rows[-1].Candidates[0].SelectionReason | Should -Match 'disabled'
        $rows[1].Candidates.Count | Should -Be 0
    }

    It 'correlates all stages once per target and rejects a conflicting target with a shared Azure alias' {
        $current = [pscustomobject] @{Name='Same';ManagedDeviceId='intune-one';DeviceId='shared';EntraDeviceObjectId='entra-one';Action='Disable'}
        $other = [pscustomobject] @{Name='Same';ManagedDeviceId='intune-two';DeviceId='shared'}
        $candidate = $current | Select-Object *
        $candidate.Action = 'Delete'
        $rows = @(Get-CloudDeviceReportSelection -Devices @($other,$current) -Export @{CurrentRun=@($current);PendingActions=@{pending=$current}} -CandidateDevices @($candidate))
        $rows.Count | Should -Be 2
        $rows[0].CurrentActions.Count | Should -Be 0
        $rows[0].Candidates.Count | Should -Be 0
        $rows[0].PendingAction | Should -BeNullOrEmpty
        $rows[1].CurrentActions.Count | Should -Be 1
        $rows[1].Candidates.Count | Should -Be 1
        $rows[1].PendingAction.ManagedDeviceId | Should -Be 'intune-one'
    }
}
