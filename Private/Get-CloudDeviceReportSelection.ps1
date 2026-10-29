function Get-CloudDeviceReportSelection {
    <#
    .SYNOPSIS
    Correlates every inventory row with its recorded actions and rule candidates.
    .DESCRIPTION
    Preserves every input row and its order without changing cleanup eligibility.
    Stable target identifiers must agree; a shared display name or conflicting
    Intune target never makes another record part of the current run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [Array] $Devices,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Export,
        [Array] $CandidateDevices = @()
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

    for ($deviceIndex = 0; $deviceIndex -lt $Devices.Count; $deviceIndex++) {
        $device = $Devices[$deviceIndex]
        $currentActions = [System.Collections.Generic.HashSet[object]]::new()
        $pendingAction = $null
        $candidates = [System.Collections.Generic.HashSet[object]]::new()
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
            if ($candidatesByIdentity.ContainsKey($key)) {
                foreach ($record in $candidatesByIdentity[$key]) {
                    if (Test-CloudDeviceReportIdentity -Device $device -Record $record) {
                        $null = $candidates.Add($record)
                    }
                }
            }
        }
        [pscustomobject] @{
            Device = $device
            Index = $deviceIndex
            CurrentActions = @($currentActions)
            PendingAction = $pendingAction
            Candidates = @($candidates)
        }
    }
}
