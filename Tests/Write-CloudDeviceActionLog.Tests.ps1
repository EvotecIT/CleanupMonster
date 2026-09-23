BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Write-CloudDeviceActionLog.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-CloudDevicesStageDelete.ps1')

    function Write-Color {
        param([string[]] $Text, [object[]] $Color, [string] $LogFile)
        $script:actionLogLines.Add(($Text -join ''))
    }
}

Describe 'Write-CloudDeviceActionLog' {
    BeforeEach {
        $script:actionLogLines = [System.Collections.Generic.List[string]]::new()
    }

    It 'identifies each bounded WhatIf target and distinguishes previews from completed actions' {
        $results = @(
            [pscustomobject] @{ Name = 'iPad'; EntraDeviceObjectId = 'entra-1'; ManagedDeviceId = 'intune-1'; ActionStatus = 'WhatIf'; ActionNotes = $null },
            [pscustomobject] @{ Name = 'iPad'; EntraDeviceObjectId = 'entra-2'; ManagedDeviceId = 'intune-2'; ActionStatus = 'WhatIf'; ActionNotes = $null }
        )

        Write-CloudDeviceActionLog -Action Disable -CandidateCount 19776 -Limit 2 -Results $results

        $script:actionLogLines.Count | Should -Be 3
        $script:actionLogLines[0] | Should -Match 'Disable WhatIf preview.*EntraObjectId=entra-1.*IntuneManagedDeviceId=intune-1'
        $script:actionLogLines[1] | Should -Match 'Disable WhatIf preview.*EntraObjectId=entra-2.*IntuneManagedDeviceId=intune-2'
        $script:actionLogLines[2] | Should -Match '0 completed, 2 WhatIf.*19774 of 19776.*Limit reached \(2\)'
    }

    It 'reports failed deletes with their sub-action note and does not call them completed' {
        $result = [pscustomobject] @{
            Name                = 'Phone'
            EntraDeviceObjectId = 'entra-3'
            ActionStatus        = 'False'
            ActionNotes         = 'Intune: Removal failed; Entra: Record delete was skipped.'
        }

        Write-CloudDeviceActionLog -Action Delete -CandidateCount 1 -Limit 5 -Results @($result)

        $script:actionLogLines[0] | Should -Match 'Delete failed.*Intune: Removal failed.*Entra: Record delete was skipped'
        $script:actionLogLines[1] | Should -Match '0 completed, 0 WhatIf, 0 ReportOnly, 1 failed'
    }

    It 'makes an empty delete stage explicit' {
        Write-CloudDeviceActionLog -Action Delete -CandidateCount 0 -Limit 5 -Results @()

        $script:actionLogLines.Count | Should -Be 1
        $script:actionLogLines[0] | Should -Match 'Delete results: 0 completed.*0 of 0 candidate'
    }

    It 'logs a staged-delete WhatIf as a preview without claiming a pending record was written' {
        $device = [pscustomobject] @{
            Name                = 'Windows-StagePreview'
            EntraDeviceObjectId = 'entra-stage-preview'
            ProcessedDeviceKey  = 'entra:entra-stage-preview'
            ProcessedDeviceKeys = @('entra:entra-stage-preview')
        }
        $processedDevices = [ordered] @{}
        $results = @(Request-CloudDevicesStageDelete -Devices @($device) -ProcessedDevices $processedDevices -Today (Get-Date) -WhatIfStageDelete)

        Write-CloudDeviceActionLog -Action StageDelete -CandidateCount 1 -Limit 5 -Results $results

        $script:actionLogLines[0] | Should -Match 'StageDelete WhatIf preview.*Pending delete staging previewed; no pending record was written'
        $script:actionLogLines[0] | Should -Not -Match 'Device staged for delete'
        $processedDevices.Count | Should -Be 0
    }
}
