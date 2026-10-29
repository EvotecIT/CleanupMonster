BeforeAll {
    . (Join-Path $PSScriptRoot '../Private/Get-CloudDeviceAuditContext.ps1')
    . (Join-Path $PSScriptRoot '../Private/ConvertTo-CloudDeviceReportRow.ps1')
    . (Join-Path $PSScriptRoot '../Private/Test-CloudDeviceReportIdentity.ps1')
}

Describe 'Cloud device review context' {
    It 'rejects shared Azure aliases when target records conflict and rejects empty GUID aliases' {
        $record = [pscustomobject]@{ ManagedDeviceId = 'intune-one'; DeviceId = '00000000-0000-0000-0000-000000000001' }
        $other = [pscustomobject]@{ ManagedDeviceId = 'intune-two'; DeviceId = $record.DeviceId }
        Test-CloudDeviceReportIdentity -Device $other -Record $record | Should -BeFalse
        Test-CloudDeviceReportIdentity -Device $record -Record $record | Should -BeTrue
        $empty = [pscustomobject]@{ DeviceId = '00000000-0000-0000-0000-000000000000' }
        Test-CloudDeviceReportIdentity -Device $empty -Record $empty | Should -BeFalse
        Test-CloudDeviceReportIdentity -Device ([pscustomobject]@{Name='Same'}) -Record ([pscustomobject]@{Name='Same'}) | Should -BeFalse
    }

    It 'preserves zero ages and false flags while distinguishing missing and unknown facts' {
        $device = [pscustomobject]@{
            Name = 'Recent'
            OperatingSystem = 'Windows'
            RecordState = 'EntraOnly'
            Enabled = $false
            EntraLastSeenDays = 0
            IntuneLastSeenDays = $null
            RegisteredDays = 0
            HasIntuneRecord = $false
            IntuneMatchAmbiguous = $false
        }
        $row = ConvertTo-CloudDeviceReportRow -Device $device -Scope 'Primary cleanup'
        $row.Enabled | Should -Be 'No'
        $row.'Entra age (days)' | Should -Be 0
        $row.'Registration age (days)' | Should -Be 0
        $row.'Intune age (days)' | Should -Be 'Unknown'
        $row.'Autopilot inventory loaded' | Should -Be 'Not captured'
        $row.'Ambiguous Intune match' | Should -Be 'No'
        $row.'Intune compliance' | Should -Be 'No Intune record'
        $row.'Recorded actions this run' | Should -Be 'None recorded'
        $row.'Pending action' | Should -Be 'None recorded'
    }

    It 'shows recorded action reasons, pending timing, and protection facts without an eligibility verdict' {
        $device = [pscustomobject]@{
            Name = 'Review'
            OperatingSystem = 'Windows'
            RecordState = 'Matched'
            Enabled = $true
            RegisteredDays = 680
            FirstSeen = [datetime]'2024-12-18'
            PreserveDuplicateNameGroup = $true
            DuplicateNameCount = 2
            DuplicateNameProtectionReason = 'Same-name Windows Autopilot duplicate'
            AutopilotInventoryLoaded = $false
            AutopilotMatchAmbiguous = $true
            OwnerUserPrincipalName = 'review@example.test'
        }
        $current = @([pscustomobject]@{Action='Disable';ActionStatus='WhatIf';SelectionReason='Entra age > 90';ActionNotes='Preview only'})
        $pending = [pscustomobject]@{Action='Disable';ActionDate=[datetime]'2026-10-01';TimeOnPendingList=28}
        $row = ConvertTo-CloudDeviceReportRow -Device $device -Scope 'Primary cleanup' -CurrentActions $current -PendingAction $pending
        $row.'Why selected this run' | Should -Be 'Disable: Entra age > 90'
        $row.'Action outcomes this run' | Should -Be 'Disable: WhatIf'
        $row.'Days pending' | Should -Be 28
        $row.'Pending since' | Should -Be '2026-10-01 00:00'
        $row.'Duplicate protection group' | Should -Be 'Yes'
        $row.'Duplicate protection reason' | Should -Be $device.DuplicateNameProtectionReason
        $row.'Ambiguous Autopilot match' | Should -Be 'Yes'
        $row.'Owner UPN' | Should -Be 'review@example.test'
        $row.PSObject.Properties.Name | Should -Not -Contain 'Safe to delete'
    }
}
