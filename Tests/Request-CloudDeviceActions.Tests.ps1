BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Remove-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Set-ProcessedCloudDeviceRecord.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesDelete.ps1')

    function Remove-MyDevice {}
    function Remove-MyDeviceIntuneRecord {}
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
}
