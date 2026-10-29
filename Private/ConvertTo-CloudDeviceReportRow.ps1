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
        [string] $ReviewSelection = 'Inventory context',
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
    $audit = Get-CloudDeviceAuditContext -Device $Device
    [pscustomobject] [ordered] @{
        Device = $Device.Name
        Scope = $Scope
        'Review selection' = $ReviewSelection
        OS = $Device.OperatingSystem
        Source = $Device.RecordState
        Enabled = & $value 'Enabled'
        'Entra age (days)' = & $value 'EntraLastSeenDays'
        'Intune age (days)' = & $value 'IntuneLastSeenDays'
        'Registration age (days)' = & $value 'RegisteredDays'
        'Intune link' = & $value 'IntuneLinkState'
        'Recorded actions this run' = if ($CurrentActions.Count) { ($CurrentActions.Action | Select-Object -Unique) -join ', ' } else { 'None recorded' }
        'Why selected this run' = if ($CurrentActions.Count) { ($CurrentActions | ForEach-Object { '{0}: {1}' -f $_.Action, $_.SelectionReason }) -join '; ' } else { 'No action recorded; see Rules for selection settings' }
        'Action outcomes this run' = ($CurrentActions | ForEach-Object { '{0}: {1}' -f $_.Action, $_.ActionStatus }) -join '; '
        'Action results this run' = ($CurrentActions | ForEach-Object { $_.ActionNotes } | Where-Object { $_ }) -join '; '
        'Pending action' = if ($PendingAction) { $PendingAction.Action } else { 'None recorded' }
        'Pending since' = if ($PendingAction -and $PendingAction.ActionDate) { ([datetime] $PendingAction.ActionDate).ToString('yyyy-MM-dd HH:mm') } else { 'Not applicable' }
        'Days pending' = if ($PendingAction) { $PendingAction.TimeOnPendingList } else { 'Not applicable' }
        'Entra last activity' = & $value 'EntraLastSeen'
        'Intune last sync' = & $value 'IntuneLastSeen'
        'Registered on' = & $value 'FirstSeen'
        'Entra registration age (days)' = & $value 'EntraRegisteredDays'
        'Intune registration age (days)' = & $value 'IntuneRegisteredDays'
        'Join type' = & $value 'TrustType'
        'OS version' = & $value 'OperatingSystemVersion'
        'Has Entra record' = & $value 'HasEntraRecord'
        'Has Intune record' = & $value 'HasIntuneRecord'
        'Ambiguous Intune match' = & $value 'IntuneMatchAmbiguous'
        'Duplicate name count' = & $value 'DuplicateNameCount'
        'Duplicate protection group' = & $value 'PreserveDuplicateNameGroup'
        'Duplicate protection reason' = & $value 'DuplicateNameProtectionReason' 'None'
        'Duplicate join types' = & $value 'DuplicateNameJoinTypes' 'None'
        'Registered owner' = $audit.RegisteredOwner
        'Owner UPN' = $audit.RegisteredOwnerUPN
        'Intune user UPN' = $audit.IntuneUserUPN
        'Ownership type' = & $value 'ManagedDeviceOwnerType'
        'Entra compliant' = $audit.EntraCompliant
        'Intune compliance' = $audit.IntuneCompliance
        'Entra managed' = $audit.EntraManaged
        'Entra management type' = $audit.EntraManagementType
        'MDM app ID' = $audit.MdmAppId
        'Intune management agent' = $audit.IntuneManagementAgent
        'Enrollment type' = & $value 'EnrollmentType'
        'Intune enrollment type' = & $value 'DeviceEnrollmentType'
        'Device registration state' = & $value 'DeviceRegistrationState'
        'Autopilot inventory loaded' = & $value 'AutopilotInventoryLoaded'
        'Ambiguous Autopilot match' = & $value 'AutopilotMatchAmbiguous'
        'Autopilot onboarded' = & $value 'AutopilotOnboarded'
        'Autopilot last contact' = & $value 'AutopilotLastContacted'
        'Autopilot contact age (days)' = & $value 'AutopilotLastContactedDays'
        'Autopilot group tag' = & $value 'AutopilotGroupTag' 'None'
        'Autopilot enrollment state' = & $value 'AutopilotEnrollmentState'
        'Autopilot serial' = & $value 'AutopilotSerialNumber'
        'Entra object ID' = $Device.EntraDeviceObjectId
        'Entra device ID' = $Device.DeviceId
        'Intune device ID' = $Device.ManagedDeviceId
        'Autopilot identity ID' = $Device.AutopilotDeviceId
    }
}
