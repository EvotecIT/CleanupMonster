function Test-CloudDeviceReportIdentity {
    <#
    .SYNOPSIS
    Matches report facts by identifiers without crossing conflicting target records.
    .DESCRIPTION
    A shared Azure device ID cannot override distinct Intune, Entra object or Autopilot IDs.
    Empty GUID aliases are not usable identifiers. Display names are never a fallback.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $Device,
        [Parameter(Mandatory)] [psobject] $Record
    )
    $matched = $false
    foreach ($name in @('EntraDeviceObjectId', 'ManagedDeviceId', 'AutopilotDeviceId', 'DeviceId')) {
        $deviceValue = [string] $Device.$name
        $recordValue = [string] $Record.$name
        if ([string]::IsNullOrWhiteSpace($deviceValue) -or [string]::IsNullOrWhiteSpace($recordValue)) { continue }
        $deviceGuid = [guid]::Empty
        $recordGuid = [guid]::Empty
        if (([guid]::TryParse($deviceValue, [ref] $deviceGuid) -and $deviceGuid -eq [guid]::Empty) -or
            ([guid]::TryParse($recordValue, [ref] $recordGuid) -and $recordGuid -eq [guid]::Empty)) { continue }
        if ($deviceValue -eq $recordValue) {
            $matched = $true
        } elseif ($name -ne 'DeviceId') {
            return $false
        }
    }
    $matched
}
