function Get-CloudDeviceReportSelection {
    <#
    .SYNOPSIS
    Selects a bounded review sample without changing cleanup eligibility or totals.
    .DESCRIPTION
    Current-run records come first, then pending actions, actual rule candidates,
    and inventory context. Within each group, older recorded activity comes first.
    Stable target identifiers must agree; a shared display name or conflicting
    Intune target never makes another record part of the current run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [Array] $Devices,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Export,
        [Array] $CandidateDevices = @(),
        [ValidateRange(1, 2147483647)] [int] $Limit = 500
    )

    $actionsByIdentity = @{}
    $pendingByIdentity = @{}
    $candidatesByIdentity = @{}
    foreach ($recordSet in @(
            @{ Records = @($Export.CurrentRun); Index = $actionsByIdentity },
            @{ Records = @($Export.PendingActions.Values); Index = $pendingByIdentity },
            @{ Records = $CandidateDevices; Index = $candidatesByIdentity }
        )) {
        foreach ($record in $recordSet.Records) {
            foreach ($identity in @('EntraDeviceObjectId', 'ManagedDeviceId', 'DeviceId', 'AutopilotDeviceId')) {
                if ([string]::IsNullOrWhiteSpace([string] $record.$identity)) { continue }
                $identityGuid = [guid]::Empty
                if ([guid]::TryParse([string] $record.$identity, [ref] $identityGuid) -and $identityGuid -eq [guid]::Empty) { continue }
                $key = '{0}:{1}' -f $identity, $record.$identity
                if (-not $recordSet.Index.ContainsKey($key)) {
                    $recordSet.Index[$key] = [System.Collections.Generic.List[object]]::new()
                }
                $recordSet.Index[$key].Add($record)
            }
        }
    }

    $review = for ($deviceIndex = 0; $deviceIndex -lt $Devices.Count; $deviceIndex++) {
        $device = $Devices[$deviceIndex]
        $currentActions = [System.Collections.Generic.HashSet[object]]::new()
        $pendingAction = $null
        $candidate = $false
        foreach ($identity in @('EntraDeviceObjectId', 'ManagedDeviceId', 'DeviceId', 'AutopilotDeviceId')) {
            if ([string]::IsNullOrWhiteSpace([string] $device.$identity)) { continue }
            $key = '{0}:{1}' -f $identity, $device.$identity
            if ($actionsByIdentity.ContainsKey($key)) {
                foreach ($record in $actionsByIdentity[$key]) {
                    if (Test-CloudDeviceReportIdentity -Device $device -Record $record) {
                        $null = $currentActions.Add($record)
                    }
                }
            }
            if (-not $pendingAction -and $pendingByIdentity.ContainsKey($key)) {
                foreach ($record in $pendingByIdentity[$key]) {
                    if (Test-CloudDeviceReportIdentity -Device $device -Record $record) {
                        $pendingAction = $record
                        break
                    }
                }
            }
            if (-not $candidate -and $candidatesByIdentity.ContainsKey($key)) {
                foreach ($record in $candidatesByIdentity[$key]) {
                    if (Test-CloudDeviceReportIdentity -Device $device -Record $record) {
                        $candidate = $true
                        break
                    }
                }
            }
        }
        $priority = 3
        $reason = 'Inventory sample'
        if ($currentActions.Count) {
            $priority = 0
            $reason = 'Current run'
        } elseif ($pendingAction) {
            $priority = 1
            $reason = 'Pending action'
        } elseif ($candidate) {
            $priority = 2
            $reason = 'Rule candidate'
        }
        $activityAge = -1
        if ($null -ne $device.EntraLastSeenDays) {
            $activityAge = $device.EntraLastSeenDays
        } elseif ($null -ne $device.IntuneLastSeenDays) {
            $activityAge = $device.IntuneLastSeenDays
        }
        [pscustomobject] @{
            Device = $device
            Index = $deviceIndex
            CurrentActions = @($currentActions)
            PendingAction = $pendingAction
            Priority = $priority
            Reason = $reason
            ActivityAge = $activityAge
        }
    }
    $review | Sort-Object -Property @{ Expression = 'Priority'; Ascending = $true }, @{ Expression = 'ActivityAge'; Descending = $true }, @{ Expression = 'Index'; Ascending = $true } | Select-Object -First $Limit
}
