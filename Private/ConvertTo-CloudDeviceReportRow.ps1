function ConvertTo-CloudDeviceReportRow {
    <#
    .SYNOPSIS
    Projects inventory, selector classifications, and recorded actions for review.
    .DESCRIPTION
    Missing properties are labelled Not captured. Empty activity is Unknown, never zero days.
    The caller supplies records matched by stable identifiers, not display names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $Device,
        [Parameter(Mandatory)] [string] $Scope,
        [Array] $Candidates = @(),
        [Array] $Decisions = @(),
        [Array] $CurrentActions = @(),
        [psobject] $PendingAction
    )

    $value = {
        param([string] $Name, [string] $Empty = 'Unknown')
        $property = $Device.PSObject.Properties[$Name]
        if (-not $property) { return 'Not captured' }
        if ($null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string] $property.Value)) { return $Empty }
        if ($property.Value -is [bool]) {
            if ($property.Value) { return 'Yes' }
            return 'No'
        }
        if ($property.Value -is [datetime]) { return $property.Value.ToString('yyyy-MM-dd HH:mm') }
        if ($property.Value -is [array]) { return $property.Value -join ', ' }
        $property.Value
    }
    $actionNames = @{
        StageDelete = 'Stage for deletion'
        RemoveAutopilotIdentity = 'Remove Autopilot identity'
    }
    $stageReasons = @(
        foreach ($decision in $Decisions) {
            $action = if ($actionNames.ContainsKey($decision.Action)) { $actionNames[$decision.Action] } else { $decision.Action }
            '{0}: {1} - {2}' -f $action, $decision.Classification, $decision.Reason
        }
    )
    $classification = 'Not evaluated'
    $reason = 'No enabled action stage evaluated this inventory record. Check Rules and inventory scope.'
    if ($Candidates.Count -gt 0) {
        $classification = (@(
            foreach ($action in @($Candidates.Action | Select-Object -Unique)) {
                $label = if ($actionNames.ContainsKey($action)) { $actionNames[$action] } else { $action }
                '{0} candidate' -f $label
            }
        )) -join ', '
        $reason = ($Candidates | ForEach-Object {
            $action = if ($actionNames.ContainsKey($_.Action)) { $actionNames[$_.Action] } else { $_.Action }
            '{0}: {1}' -f $action, $_.SelectionReason
        }) -join '; '
    } elseif ($Decisions.Count -gt 0) {
        $applicableDecisions = @($Decisions | Where-Object Classification -ne 'Not applicable')
        if ($applicableDecisions.Count -eq 0) { $applicableDecisions = $Decisions }
        $classificationDecisions = @($applicableDecisions | Where-Object Classification -ne 'Already pending')
        if ($classificationDecisions.Count -eq 0) { $classificationDecisions = $applicableDecisions }
        $classifications = @($classificationDecisions.Classification | Select-Object -Unique)
        $classification = if ($classifications.Count -eq 1) { $classifications[0] } else { 'Not selected' }
        $reason = ($applicableDecisions | ForEach-Object {
            $action = if ($actionNames.ContainsKey($_.Action)) { $actionNames[$_.Action] } else { $_.Action }
            '{0}: {1}' -f $action, $_.Reason
        }) -join '; '
    }
    [pscustomobject] @{
        Classification = $classification
        Device = $Device.Name
        Reason = $reason
        'Inventory source' = $Scope
        OS = $Device.OperatingSystem
        Source = $Device.RecordState
        Enabled = & $value 'Enabled'
        'Entra age (days)' = & $value 'EntraLastSeenDays'
        'Intune age (days)' = & $value 'IntuneLastSeenDays'
        'Registration age (days)' = & $value 'RegisteredDays'
        'Intune link' = & $value 'IntuneLinkState'
        'Selected actions' = ($Candidates.Action | Select-Object -Unique) -join ', '
        'Selection reasons' = ($Candidates | ForEach-Object { '{0}: {1}' -f $_.Action, $_.SelectionReason }) -join '; '
        'Recorded actions this run' = ($CurrentActions | ForEach-Object { '{0}: {1}' -f $_.Action, $_.ActionStatus }) -join '; '
        'Pending action' = if ($PendingAction) { $PendingAction.Action } else { '' }
        'Stage decisions' = $stageReasons -join '; '
        'Join type' = & $value 'TrustType'
        'Ambiguous Intune match' = & $value 'IntuneMatchAmbiguous'
        'Duplicate protection' = & $value 'PreserveDuplicateNameGroup'
        'Owner UPN' = & $value 'OwnerUserPrincipalName' ''
        'Intune user UPN' = & $value 'IntuneUserPrincipalName' ''
        'Ambiguous Autopilot match' = & $value 'AutopilotMatchAmbiguous'
        'Autopilot contact age (days)' = & $value 'AutopilotLastContactedDays'
        'Entra object ID' = $Device.EntraDeviceObjectId
        'Entra device ID' = $Device.DeviceId
        'Intune device ID' = $Device.ManagedDeviceId
        'Autopilot identity ID' = $Device.AutopilotDeviceId
    }
}
