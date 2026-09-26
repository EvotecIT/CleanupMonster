BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-CloudDeviceAuditContext.ps1')
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

        $script:actionLogLines.Count | Should -Be 9
        $script:actionLogLines[0] | Should -Match 'Disable WhatIf preview.*EntraObjectId=entra-1.*IntuneManagedDeviceId=intune-1'
        $script:actionLogLines[4] | Should -Match 'Disable WhatIf preview.*EntraObjectId=entra-2.*IntuneManagedDeviceId=intune-2'
        $script:actionLogLines[8] | Should -Match '0 completed, 2 WhatIf.*19774 of 19776.*Limit reached \(2\)'
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
        $script:actionLogLines[4] | Should -Match '0 completed, 0 WhatIf, 0 ReportOnly, 1 failed'
    }

    It 'makes an empty delete stage explicit' {
        Write-CloudDeviceActionLog -Action Delete -CandidateCount 0 -Limit 5 -Results @()

        $script:actionLogLines.Count | Should -Be 1
        $script:actionLogLines[0] | Should -Match 'Delete results: 0 completed.*0 of 0 candidate'
    }

    It 'summarizes report-only candidates without a per-device action line' {
        $result = [pscustomobject] @{
            Name            = 'NotAttempted'
            ActionStatus    = 'ReportOnly'
            SelectionReason = 'EntraLastSeenDays=200 > 90'
        }

        Write-CloudDeviceActionLog -Action Disable -CandidateCount 1 -Limit 5 -Results @($result)

        $script:actionLogLines.Count | Should -Be 1
        $script:actionLogLines[0] | Should -Match '0 completed, 0 WhatIf, 1 ReportOnly'
        $script:actionLogLines[0] | Should -Not -Match 'NotAttempted'
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

    It 'includes the candidate age and threshold in the attempted action line' {
        $result = [pscustomobject] @{
            Name                = 'Phone'
            EntraDeviceObjectId = 'entra-4'
            ActionStatus        = 'WhatIf'
            SelectionReason     = 'EntraLastSeenDays=230 > 180; IntuneLastSeenDays=205 > 180 (recent Intune activity protection); RegisteredDays=400 > 180; PendingDays=95 >= 90'
        }

        Write-CloudDeviceActionLog -Action Delete -CandidateCount 1 -Limit 5 -Results @($result)

        $script:actionLogLines[0] | Should -Match 'Delete WhatIf preview.*EntraLastSeenDays=230 > 180'
        $script:actionLogLines[0] | Should -Match 'IntuneLastSeenDays=205 > 180'
        $script:actionLogLines[0] | Should -Match 'RegisteredDays=400 > 180.*PendingDays=95 >= 90'
    }

    It 'logs the identity, compliance, and management snapshot for an attempted device' {
        $result = [pscustomobject] @{
            Name = 'Phone'; ActionStatus = 'WhatIf'; HasIntuneRecord = $false
            OwnerDisplayName = @('User One'); OwnerUserPrincipalName = @('user.one@contoso.com')
            IntuneUserPrincipalName = $null; IsCompliant = $false; ComplianceState = $null
            IsManaged = $true; ManagementType = 'mdm'; MdmAppId = '0000000a-0000-0000-c000-000000000000'
            ManagementAgent = $null
        }

        Write-CloudDeviceActionLog -Action Disable -CandidateCount 1 -Limit 1 -Results @($result)

        $script:actionLogLines[1] | Should -Match 'Identity: Owner=User One; OwnerUPN=user.one@contoso.com'
        $script:actionLogLines[2] | Should -Match 'Compliance: Entra=False; Intune=No Intune record'
        $script:actionLogLines[3] | Should -Match 'Management: EntraManaged=True; EntraType=mdm'
        $script:actionLogLines[3] | Should -Match 'MdmAppId=0000000a-0000-0000-c000-000000000000'
    }

    It 'identifies absent Entra data for an Intune-only attempt' {
        $result = [pscustomobject] @{
            Name = 'Phone'; ActionStatus = 'WhatIf'; RecordState = 'IntuneOnly'; HasEntraRecord = $true; HasIntuneRecord = $true
            IsManaged = $true; ComplianceState = 'compliant'; ManagementAgent = 'mdm'
            IntuneUserPrincipalName = 'phone.user@contoso.com'
        }

        Write-CloudDeviceActionLog -Action Delete -CandidateCount 1 -Limit 1 -Results @($result)

        $script:actionLogLines[3] | Should -Match 'EntraManaged=Entra details not captured'
        $script:actionLogLines[2] | Should -Match 'Entra=Entra details not captured; Intune=compliant'
        $script:actionLogLines[1] | Should -Match 'IntuneUserUPN=phone.user@contoso.com'
    }

    It 'distinguishes an Intune-only attempt with no correlated Entra object' {
        $result = [pscustomobject] @{
            Name = 'Phone'; ActionStatus = 'WhatIf'; RecordState = 'IntuneOnly'
            HasEntraRecord = $false; HasIntuneRecord = $true; IsManaged = $true
        }

        Write-CloudDeviceActionLog -Action Delete -CandidateCount 1 -Limit 1 -Results @($result)

        $script:actionLogLines[2] | Should -Match 'Entra=No Entra record'
        $script:actionLogLines[3] | Should -Match 'EntraManaged=No Entra record'
    }
}
