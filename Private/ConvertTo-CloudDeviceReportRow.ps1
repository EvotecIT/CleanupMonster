function ConvertTo-CloudDeviceReportRow {
    <#
    .SYNOPSIS
    Projects inventory and recorded action facts for review without deciding action eligibility.
    .DESCRIPTION
    Missing properties are labelled Not captured. Empty activity is Unknown, never zero days.
    The caller supplies records matched by stable identifiers, not display names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $Device,
        [Parameter(Mandatory)] [string] $Scope,
        [Array] $Candidates = @(),
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
    [pscustomobject] @{
        Device = $Device.Name
        Scope = $Scope
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
