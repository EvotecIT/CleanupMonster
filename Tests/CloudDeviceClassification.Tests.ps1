BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    foreach ($name in @(
            'Get-CloudDeviceRecordKey', 'Get-CloudDeviceRecordKeys', 'Get-CloudDevicePropertyValue',
            'Find-ProcessedCloudDeviceRecord', 'Test-CloudDevicePendingActivity',
            'Get-CloudDeviceSelectionReason', 'Get-CloudDevicesToProcess',
            'Test-CloudDeviceReportIdentity', 'Get-CloudDeviceReportSelection',
            'ConvertTo-CloudDeviceReportRow', 'Get-CloudDeviceAuditContext',
            'Write-CloudDeviceStatistics', 'Write-CloudDeviceActionLog',
            'Request-CloudDevicesDisable', 'Request-CloudDevicesStageDelete',
            'Test-CloudDeviceAlreadyPending', 'Merge-CloudDeviceReportInventory'
        )) {
        . (Join-Path $root "Private/$name.ps1")
    }
    . (Join-Path $root 'Public/Invoke-CloudDevicesCleanup.ps1')
    function Write-Color { param([object[]] $Text, [object[]] $Color, [string] $LogFile) }
    function Set-LoggingCapabilities {}
    function Set-ReportingCapabilities {}
    function Assert-CloudDeviceCleanupSettings { $true }
    function Get-GitHubVersion { 'test' }
    function Import-CloudDevicesData { $script:pending }
    function Get-InitialCloudDevices { $script:inventory }
    function New-HTMLProcessedCloudDevices {
        param($Export, $Devices, $CandidateDevices, $SelectionDecisions, $ActionConfiguration)
        $script:reportInputs = @{
            Devices = $Devices
            Export = $Export
            CandidateDevices = $CandidateDevices
            SelectionDecisions = $SelectionDecisions
        }
    }
    function New-EmailBodyCloudDevices { '' }
    function New-TestCloudDevice {
        param([string] $Name = 'Device', [int] $Age = 200)
        [pscustomobject] @{
            Name = $Name
            EntraDeviceObjectId = "entra-$Name"
            ManagedDeviceId = "intune-$Name"
            DeviceId = "device-$Name"
            OperatingSystem = 'Android'
            Enabled = $true
            HasEntraRecord = $true
            HasIntuneRecord = $true
            RecordState = 'Matched'
            IntuneLinkState = 'Healthy'
            EntraLastSeenDays = $Age
            IntuneLastSeenDays = $Age
            RegisteredDays = 500
            PreserveDuplicateNameGroup = $false
            IntuneMatchAmbiguous = $false
            ManagedDeviceOwnerType = 'personal'
        }
    }
}

Describe 'Cloud inventory cleanup classifications' {
    BeforeEach { $script:pending = [ordered] @{} }
    It 'records the selector decision without changing candidates for <Case>' -ForEach @(
        @{ Case = 'recent Entra activity'; Changes = @{ EntraLastSeenDays = 16; IntuneLastSeenDays = 16 }; Rules = @{}; Class = 'Not required'; Reason = '16 days.*more than 90'; Selected = 0 }
        @{ Case = 'the exact age boundary'; Changes = @{ EntraLastSeenDays = 90 }; Rules = @{}; Class = 'Not required'; Reason = '90 days.*more than 90'; Selected = 0 }
        @{ Case = 'recent Intune activity with stale Entra'; Changes = @{ IntuneLastSeenDays = 16 }; Rules = @{}; Class = 'Not required'; Reason = 'Intune inactivity is 16'; Selected = 0 }
        @{ Case = 'unknown activity'; Changes = @{ EntraLastSeenDays = $null }; Rules = @{}; Class = 'Protected'; Reason = 'Entra activity is unknown'; Selected = 0 }
        @{ Case = 'unknown registration age'; Changes = @{ RegisteredDays = $null }; Rules = @{ RegisteredMoreThan = 180 }; Class = 'Protected'; Reason = 'Registration age is unknown'; Selected = 0 }
        @{ Case = 'recent registration'; Changes = @{ RegisteredDays = 16 }; Rules = @{ RegisteredMoreThan = 180 }; Class = 'Not required'; Reason = 'Registration age is 16 days'; Selected = 0 }
        @{ Case = 'duplicate-name protection'; Changes = @{ PreserveDuplicateNameGroup = $true }; Rules = @{ PreserveDuplicateDeviceNames = $true }; Class = 'Protected'; Reason = 'Duplicate-name protection'; Selected = 0 }
        @{ Case = 'ambiguous Intune matching'; Changes = @{ IntuneMatchAmbiguous = $true }; Rules = @{}; Class = 'Protected'; Reason = 'Intune match is ambiguous'; Selected = 0 }
        @{ Case = 'an ownership exclusion'; Changes = @{ ManagedDeviceOwnerType = 'company' }; Rules = @{ ExcludeCompanyOwned = $true }; Class = 'Excluded by setting'; Reason = 'Company-owned'; Selected = 0 }
        @{ Case = 'a required previous stage'; Changes = @{}; Rules = @{ ListProcessedMoreThan = 30 }; Class = 'Waiting for previous stage'; Reason = 'previous action'; Selected = 0 }
        @{ Case = 'an eligible device'; Changes = @{}; Rules = @{}; Class = 'Selected by rules'; Reason = 'EntraLastSeenDays=200 > 90'; Selected = 1 }
    ) {
        $device = New-TestCloudDevice
        foreach ($key in $Changes.Keys) { $device.$key = $Changes[$key] }
        $actionIf = @{ LastSeenEntraMoreThan = 90; LastSeenIntuneMoreThan = 90 }
        foreach ($key in $Rules.Keys) { $actionIf[$key] = $Rules[$key] }
        $withoutDecisions = @(Get-CloudDevicesToProcess -Type Disable -Devices @($device) -ActionIf $actionIf -ProcessedDevices @{})
        $decisions = [System.Collections.Generic.List[object]]::new()
        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices @($device) -ActionIf $actionIf -ProcessedDevices @{} -Decisions $decisions)

        $candidates.Count | Should -Be $Selected
        ($candidates.Name -join ',') | Should -Be ($withoutDecisions.Name -join ',')
        $decisions.Count | Should -Be 1
        $decisions[0].Classification | Should -Be $Class
        $decisions[0].Reason | Should -Match $Reason
        $decisions[0].EntraDeviceObjectId | Should -Be $device.EntraDeviceObjectId
    }

    It 'explains an unfinished pending period using the same pending-state check as selection' {
        $device = New-TestCloudDevice
        $processed = @{
            'entra:entra-Device' = [pscustomobject] @{
                Action = 'Retire'
                ActionStatus = 'True'
                ActionDate = (Get-Date).AddDays(-5)
                TimeOnPendingList = 5
                TimeToNextAction = 25
            }
        }
        $decisions = [System.Collections.Generic.List[object]]::new()
        $candidates = @(Get-CloudDevicesToProcess -Type Disable -Devices @($device) -ActionIf @{ ListProcessedMoreThan = 30 } -ProcessedDevices $processed -Decisions $decisions)
        $candidates.Count | Should -Be 0
        $decisions[0].Classification | Should -Be 'Waiting for pending period'
        $decisions[0].Reason | Should -Match 'Pending for 5 days; requires at least 30 days'
    }

    It 'keeps candidates beyond the run limit classified separately from recent inventory and attempts' {
        $script:inventory = @(
            New-TestCloudDevice -Name Recent -Age 16
            New-TestCloudDevice -Name Oldest -Age 300
            New-TestCloudDevice -Name BeyondLimit -Age 200
        )
        Invoke-CloudDevicesCleanup -Disable -DisableLastSeenEntraMoreThan 90 -DisableListProcessedMoreThan $null -DisableLimit 1 -ReportOnly -Suppress | Out-Null

        $script:reportInputs.Devices.Count | Should -Be 3
        $script:reportInputs.CandidateDevices.Count | Should -Be 2
        $script:reportInputs.Export.CurrentRun.Count | Should -Be 1
        $selection = @(Get-CloudDeviceReportSelection @script:reportInputs)
        $rows = @($selection | ForEach-Object {
            ConvertTo-CloudDeviceReportRow -Device $_.Device -Scope 'Main inventory' -Candidates $_.Candidates -CurrentActions $_.CurrentActions -Decisions $_.Decisions
        })
        $recent = $rows | Where-Object Device -eq Recent
        $beyondLimit = $rows | Where-Object Device -eq BeyondLimit
        $recent.Classification | Should -Be 'Not required'
        $recent.Reason | Should -Match '16 days.*more than 90'
        $beyondLimit.Classification | Should -Be 'Disable candidate'
        $beyondLimit.'Selected actions' | Should -Be 'Disable'
        $beyondLimit.'Recorded actions this run' | Should -Be ''
        ($rows | Where-Object Device -eq Oldest).'Recorded actions this run' | Should -Be 'Disable: ReportOnly'
    }

    It 'distinguishes devices already pending deletion from genuinely unstaged candidates' {
        $alreadyPending = New-TestCloudDevice -Name AlreadyPending -Age 300
        $alreadyPending.Enabled = $false
        $unstaged = New-TestCloudDevice -Name Unstaged -Age 250
        $unstaged.Enabled = $false
        $script:inventory = @($alreadyPending, $unstaged)
        $record = $alreadyPending | Select-Object *
        $record | Add-Member -NotePropertyMembers @{
            Action = 'Disable'; ActionStatus = 'True'; ActionDate = (Get-Date).AddDays(-5)
            TimeOnPendingList = 5; TimeToNextAction = 25
        }
        $script:pending['entra:entra-AlreadyPending'] = $record

        Invoke-CloudDevicesCleanup -StageDisabledForDelete -Delete -DeleteLastSeenEntraMoreThan 180 -DeleteListProcessedMoreThan 30 -StageDisabledForDeleteLimit 1 -ReportOnly -Suppress | Out-Null

        $script:reportInputs.CandidateDevices.Count | Should -Be 1
        $script:reportInputs.CandidateDevices[0].Name | Should -Be Unstaged
        $rows = @(Get-CloudDeviceReportSelection @script:reportInputs | ForEach-Object {
            ConvertTo-CloudDeviceReportRow -Device $_.Device -Scope 'Main inventory' -Candidates $_.Candidates -CurrentActions $_.CurrentActions -Decisions $_.Decisions
        })
        $pendingRow = $rows | Where-Object Device -eq AlreadyPending
        $newRow = $rows | Where-Object Device -eq Unstaged
        $pendingRow.Classification | Should -Be 'Waiting for pending period'
        $pendingRow.Reason | Should -Match 'Already on the pending list'
        $newRow.Classification | Should -Be 'Stage for deletion candidate'
        $newRow.Reason | Should -Match 'no device record is deleted'
        $newRow.Reason | Should -Not -Match 'Delete Intune record and Entra device object'
        $newRow.'Recorded actions this run' | Should -Be 'StageDelete: ReportOnly'
    }
}
