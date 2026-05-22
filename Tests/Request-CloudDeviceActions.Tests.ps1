BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Remove-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Set-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesRetire.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesDisable.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesDelete.ps1')

    function Invoke-MyDeviceRetire {}
    function Disable-MyDevice {}
    function Remove-MyAutopilotDevice {}
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

    It 'counts failed retire attempts toward the retire limit' {
        Mock Invoke-MyDeviceRetire { [PSCustomObject] @{ Success = $false; Message = 'Retire failed' } }

        $processedDevices = [ordered] @{}
        $devices = 1..3 | ForEach-Object {
            [PSCustomObject] @{
                Name                = "iPhone-Fail-$_"
                ManagedDeviceId     = "managed-fail-$_"
                ProcessedDeviceKey  = "intune:managed-fail-$_"
                ProcessedDeviceKeys = @("intune:managed-fail-$_")
            }
        }

        $results = @(Request-CloudDevicesRetire -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -RetireLimit 1)

        $results | Should -HaveCount 1
        $results[0].ActionStatus | Should -Be 'False'
        Assert-MockCalled Invoke-MyDeviceRetire -Times 1 -Exactly
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

    It 'counts failed disable attempts toward the disable limit' {
        Mock Disable-MyDevice { [PSCustomObject] @{ Success = $false; Message = 'Disable failed' } }

        $processedDevices = [ordered] @{}
        $devices = 1..3 | ForEach-Object {
            [PSCustomObject] @{
                Name                = "iPhone-Fail-$_"
                ManagedDeviceId     = "managed-fail-$_"
                ProcessedDeviceKey  = "intune:managed-fail-$_"
                ProcessedDeviceKeys = @("intune:managed-fail-$_")
            }
        }

        $results = @(Request-CloudDevicesDisable -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -DisableLimit 1)

        $results | Should -HaveCount 1
        $results[0].ActionStatus | Should -Be 'False'
        Assert-MockCalled Disable-MyDevice -Times 1 -Exactly
    }
}

Describe 'Request-CloudDevicesDelete' {
    BeforeEach {
        Mock Remove-MyAutopilotDevice {}
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
        Assert-MockCalled Remove-MyAutopilotDevice -Times 0 -Exactly
    }

    It 'removes an Autopilot identity before deleting Intune and Entra records when requested' {
        Mock Remove-MyAutopilotDevice { [PSCustomObject] @{ Success = $true; Message = 'Removed Autopilot identity' } }
        Mock Remove-MyDeviceIntuneRecord { [PSCustomObject] @{ Success = $true; Message = 'Removed Intune record' } }
        Mock Remove-MyDevice { [PSCustomObject] @{ Success = $true; Message = 'Removed Entra record' } }

        $processedDevices = [ordered] @{
            'entra:entra-ap' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-35)
            }
        }

        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-Autopilot'
                EntraDeviceObjectId      = 'entra-ap'
                ManagedDeviceId          = 'managed-ap'
                AutopilotInventoryLoaded = $true
                AutopilotOnboarded       = $true
                AutopilotDeviceId        = 'autopilot-ap'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ProcessedDeviceKey       = 'entra:entra-ap'
                ProcessedDeviceKeys      = @('entra:entra-ap', 'intune:managed-ap')
            }
        )

        $results = @(Request-CloudDevicesDelete -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -DeleteAutopilotIdentity)

        $results | Should -HaveCount 1
        $results[0].ActionStatus | Should -Be 'True'
        $results[0].ActionNotes | Should -Match 'Autopilot: Removed Autopilot identity'
        $results[0].ActionNotes | Should -Match 'Intune: Removed Intune record'
        $results[0].ActionNotes | Should -Match 'Entra: Removed Entra record'
        Assert-MockCalled Remove-MyAutopilotDevice -Times 1 -Exactly
        Assert-MockCalled Remove-MyDeviceIntuneRecord -Times 1 -Exactly
        Assert-MockCalled Remove-MyDevice -Times 1 -Exactly
        $processedDevices.Contains('entra:entra-ap') | Should -BeFalse
    }

    It 'does not delete records when requested Autopilot inventory is unavailable' {
        $processedDevices = [ordered] @{
            'entra:entra-unknown-ap' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-35)
            }
        }

        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-UnknownAutopilot'
                EntraDeviceObjectId      = 'entra-unknown-ap'
                ManagedDeviceId          = 'managed-unknown-ap'
                AutopilotInventoryLoaded = $false
                AutopilotOnboarded       = $null
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ProcessedDeviceKey       = 'entra:entra-unknown-ap'
                ProcessedDeviceKeys      = @('entra:entra-unknown-ap', 'intune:managed-unknown-ap')
            }
        )

        $results = @(Request-CloudDevicesDelete -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -DeleteAutopilotIdentity)

        $results | Should -HaveCount 1
        $results[0].ActionStatus | Should -Be 'False'
        $results[0].ActionNotes | Should -Match 'Autopilot: Inventory was not loaded'
        Assert-MockCalled Remove-MyAutopilotDevice -Times 0 -Exactly
        Assert-MockCalled Remove-MyDeviceIntuneRecord -Times 0 -Exactly
        Assert-MockCalled Remove-MyDevice -Times 0 -Exactly
        $processedDevices.Contains('entra:entra-unknown-ap') | Should -BeTrue
    }

    It 'does not delete records when an onboarded Autopilot identity cannot be removed' {
        Mock Remove-MyAutopilotDevice { [PSCustomObject] @{ Success = $false; Message = 'Autopilot removal failed' } }

        $processedDevices = [ordered] @{
            'entra:entra-ap-fail' = [PSCustomObject] @{
                Action       = 'Disable'
                ActionStatus = 'True'
                ActionDate   = (Get-Date).AddDays(-35)
            }
        }

        $devices = @(
            [PSCustomObject] @{
                Name                     = 'Windows-Autopilot-Fail'
                EntraDeviceObjectId      = 'entra-ap-fail'
                ManagedDeviceId          = 'managed-ap-fail'
                AutopilotInventoryLoaded = $true
                AutopilotOnboarded       = $true
                AutopilotDeviceId        = 'autopilot-ap-fail'
                HasEntraRecord           = $true
                HasIntuneRecord          = $true
                RecordState              = 'Matched'
                ProcessedDeviceKey       = 'entra:entra-ap-fail'
                ProcessedDeviceKeys      = @('entra:entra-ap-fail', 'intune:managed-ap-fail')
            }
        )

        $results = @(Request-CloudDevicesDelete -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -DeleteAutopilotIdentity)

        $results | Should -HaveCount 1
        $results[0].ActionStatus | Should -Be 'False'
        $results[0].ActionNotes | Should -Match 'Autopilot: Autopilot removal failed'
        Assert-MockCalled Remove-MyAutopilotDevice -Times 1 -Exactly
        Assert-MockCalled Remove-MyDeviceIntuneRecord -Times 0 -Exactly
        Assert-MockCalled Remove-MyDevice -Times 0 -Exactly
        $processedDevices.Contains('entra:entra-ap-fail') | Should -BeTrue
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
        Assert-MockCalled Remove-MyAutopilotDevice -Times 0 -Exactly
    }

    It 'counts failed delete attempts toward the delete limit' {
        Mock Remove-MyDevice { [PSCustomObject] @{ Success = $false; Message = 'Delete failed' } }
        Mock Remove-MyDeviceIntuneRecord {}

        $processedDevices = [ordered] @{}
        $devices = 1..3 | ForEach-Object {
            [PSCustomObject] @{
                Name                = "iPhone-Fail-$_"
                EntraDeviceObjectId = "entra-fail-$_"
                HasEntraRecord      = $true
                HasIntuneRecord     = $false
                RecordState         = 'EntraOnly'
                ProcessedDeviceKey  = "entra:entra-fail-$_"
                ProcessedDeviceKeys = @("entra:entra-fail-$_")
            }
        }

        $results = @(Request-CloudDevicesDelete -Devices $devices -ProcessedDevices $processedDevices -Today (Get-Date) -DeleteLimit 1)

        $results | Should -HaveCount 1
        $results[0].ActionStatus | Should -Be 'False'
        Assert-MockCalled Remove-MyDevice -Times 1 -Exactly
    }
}
