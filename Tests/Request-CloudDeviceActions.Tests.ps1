BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Remove-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Set-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesRetire.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesDisable.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesDelete.ps1')

    function Invoke-MyDeviceRetire {}
    function Disable-MyDevice {}
    function Remove-MyDevice {}
    function Remove-MyDeviceIntuneRecord {}
}

Describe 'Request-CloudDevicesRetire' {
    BeforeEach {
        Mock Invoke-MyDeviceRetire { [PSCustomObject] @{ Success = $true; Message = 'Preview retire' } }
    }

    It 'does not store WhatIf retire results in pending actions' {
        $processedDevices = [ordered] @{}
        $devices = @(
            [PSCustomObject] @{
                Name                = 'iPhone-Preview'
                ManagedDeviceId     = 'managed-preview'
                ProcessedDeviceKey  = 'intune:managed-preview'
                ProcessedDeviceKeys = @('intune:managed-preview')
            }
        )

        $results = @(Request-CloudDevicesRetire -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -WhatIfRetire)

        $results.Count | Should -Be 1
        $results[0].ActionStatus | Should -Be 'WhatIf'
        $processedDevices.Count | Should -Be 0
    }

    It 'does not store report-only retire results in pending actions' {
        $processedDevices = [ordered] @{}
        $devices = @(
            [PSCustomObject] @{
                Name                = 'iPhone-ReportOnly'
                ManagedDeviceId     = 'managed-reportonly'
                ProcessedDeviceKey  = 'intune:managed-reportonly'
                ProcessedDeviceKeys = @('intune:managed-reportonly')
            }
        )

        $results = @(Request-CloudDevicesRetire -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -ReportOnly)

        $results.Count | Should -Be 1
        $results[0].ActionStatus | Should -Be 'ReportOnly'
        $processedDevices.Count | Should -Be 0
    }
}

Describe 'Request-CloudDevicesDisable' {
    BeforeEach {
        Mock Disable-MyDevice { [PSCustomObject] @{ Success = $true; Message = 'Preview disable' } }
    }

    It 'does not store WhatIf disable results in pending actions' {
        $processedDevices = [ordered] @{}
        $devices = @(
            [PSCustomObject] @{
                Name                = 'iPhone-Preview'
                ManagedDeviceId     = 'managed-preview'
                ProcessedDeviceKey  = 'intune:managed-preview'
                ProcessedDeviceKeys = @('intune:managed-preview')
            }
        )

        $results = @(Request-CloudDevicesDisable -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -WhatIfDisable)

        $results.Count | Should -Be 1
        $results[0].ActionStatus | Should -Be 'WhatIf'
        $processedDevices.Count | Should -Be 0
    }

    It 'does not store report-only disable results in pending actions' {
        $processedDevices = [ordered] @{}
        $devices = @(
            [PSCustomObject] @{
                Name                = 'iPhone-ReportOnly'
                ManagedDeviceId     = 'managed-reportonly'
                ProcessedDeviceKey  = 'intune:managed-reportonly'
                ProcessedDeviceKeys = @('intune:managed-reportonly')
            }
        )

        $results = @(Request-CloudDevicesDisable -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -ReportOnly)

        $results.Count | Should -Be 1
        $results[0].ActionStatus | Should -Be 'ReportOnly'
        $processedDevices.Count | Should -Be 0
    }
}

Describe 'Request-CloudDevicesDelete' {
    BeforeEach {
        Mock Remove-MyDevice {}
        Mock Remove-MyDeviceIntuneRecord {}
    }

    It 'marks delete as failed when no delete sub-action is applicable' {
        $processedDevices = [ordered] @{
            'device:device-2' = [PSCustomObject] @{
                Action       = 'Retire'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-35)
            }
        }

        $devices = @(
            [PSCustomObject] @{
                Name               = 'Android-Orphan'
                ProcessedDeviceKey = 'device:device-2'
                HasEntraRecord     = $false
                HasIntuneRecord    = $true
            }
        )

        $results = @(Request-CloudDevicesDelete -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -DeleteRemoveIntuneRecord:$false)

        $results.Count | Should -Be 1
        $results[0].ActionStatus | Should -Be 'False'
        $results[0].ActionNotes | Should -Match 'No delete sub-actions were applicable'
        $processedDevices.Contains('device:device-2') | Should -BeTrue
        Assert-MockCalled Remove-MyDevice -Times 0 -Exactly
        Assert-MockCalled Remove-MyDeviceIntuneRecord -Times 0 -Exactly
    }

    It 'does not remove Entra objects for Intune-only delete candidates' {
        Mock Remove-MyDeviceIntuneRecord { [PSCustomObject] @{ Success = $true; Message = 'Removed Intune record' } }

        $processedDevices = [ordered] @{
            'intune:managed-3' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-35)
            }
        }

        $devices = @(
            [PSCustomObject] @{
                Name                    = 'Android-IntuneOnly'
                ProcessedDeviceKey      = 'intune:managed-3'
                ProcessedDeviceKeys     = @('intune:managed-3', 'entra:entra-3', 'device:device-3')
                MatchedProcessedDeviceKey = 'intune:managed-3'
                RecordState             = 'IntuneOnly'
                HasEntraRecord          = $true
                HasIntuneRecord         = $true
            }
        )

        $results = @(Request-CloudDevicesDelete -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date))

        $results.Count | Should -Be 1
        $results[0].ActionStatus | Should -Be 'True'
        $results[0].ActionNotes | Should -Match 'Intune: Removed Intune record'
        Assert-MockCalled Remove-MyDevice -Times 0 -Exactly
        Assert-MockCalled Remove-MyDeviceIntuneRecord -Times 1 -Exactly
    }
}
