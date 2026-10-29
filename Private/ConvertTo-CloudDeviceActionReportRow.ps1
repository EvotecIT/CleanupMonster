function ConvertTo-CloudDeviceActionReportRow {
    <#
    .SYNOPSIS
    Projects action-time evidence from a saved record without consulting current inventory.
    .DESCRIPTION
    Uses the same projection for Current Run, History and Pending Actions. Fields absent
    from older snapshots remain Not captured rather than taking values from today's device.
    The complete normalized snapshot remains in the XML datastore.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $Record,
        [switch] $Pending
    )

    $value = {
        param([string] $Name)
        $property = $Record.PSObject.Properties[$Name]
        if (-not $property) { return 'Not captured' }
        if ($null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string] $property.Value)) { return 'Unknown' }
        $property.Value
    }
    $audit = Get-CloudDeviceAuditContext -Device $Record
    $outcome = switch ([string] $Record.ActionStatus) {
        'True' { 'Completed' }
        'False' { 'Failed' }
        'WhatIf' { 'WhatIf preview' }
        'ReportOnly' { 'Report only' }
        default { & $value 'ActionStatus' }
    }
    $action = switch ([string] $Record.Action) {
        'StageDelete' { 'Stage for deletion' }
        'RemoveAutopilotIdentity' { 'Remove Autopilot identity' }
        default { [string] $Record.Action }
    }
    $row = [ordered] @{
        Device = $Record.Name
        Action = $action
        Outcome = $outcome
        When = if ($Record.ActionDate) { ([datetime] $Record.ActionDate).ToString('yyyy-MM-dd HH:mm') } else { 'Not captured' }
        'Why selected' = & $value 'SelectionReason'
        Result = & $value 'ActionNotes'
        OS = $Record.OperatingSystem
        Source = & $value 'RecordState'
        'Saved enabled state' = & $value 'Enabled'
        'Entra age (days)' = & $value 'EntraLastSeenDays'
        'Intune age (days)' = & $value 'IntuneLastSeenDays'
        'Registration age (days)' = & $value 'RegisteredDays'
        'Join type' = & $value 'TrustType'
        'Intune link' = & $value 'IntuneLinkState'
        'Ambiguous Intune match' = & $value 'IntuneMatchAmbiguous'
        'Duplicate protection' = & $value 'PreserveDuplicateNameGroup'
        'Registered owner' = $audit.RegisteredOwner
        'Owner UPN' = $audit.RegisteredOwnerUPN
        'Intune user UPN' = $audit.IntuneUserUPN
        'Autopilot contact age (days)' = & $value 'AutopilotLastContactedDays'
        'Ambiguous Autopilot match' = & $value 'AutopilotMatchAmbiguous'
        'Entra object ID' = $Record.EntraDeviceObjectId
        'Entra device ID' = $Record.DeviceId
        'Intune device ID' = $Record.ManagedDeviceId
        'Autopilot identity ID' = $Record.AutopilotDeviceId
        'Autopilot serial' = $Record.AutopilotSerialNumber
        'Autopilot resource' = $Record.AutopilotResourceName
        'Entra compliant' = $audit.EntraCompliant
        'Intune compliance' = $audit.IntuneCompliance
        'Entra managed' = $audit.EntraManaged
        'Entra management type' = $audit.EntraManagementType
        'MDM app ID' = $audit.MdmAppId
        'Intune management agent' = $audit.IntuneManagementAgent
    }
    if ($Pending) {
        $row['Days pending'] = & $value 'TimeOnPendingList'
    }
    [pscustomobject] $row
}
