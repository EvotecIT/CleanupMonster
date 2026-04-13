function Get-CloudDeviceRecordKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Device
    )

    if ($Device.PSObject.Properties['EntraDeviceObjectId'] -and $Device.EntraDeviceObjectId) {
        return "entra:$($Device.EntraDeviceObjectId)"
    }

    if ($Device.PSObject.Properties['DeviceId'] -and $Device.DeviceId) {
        return "device:$($Device.DeviceId)"
    }

    if ($Device.PSObject.Properties['ManagedDeviceId'] -and $Device.ManagedDeviceId) {
        return "intune:$($Device.ManagedDeviceId)"
    }

    throw "Get-CloudDeviceRecordKey - Unable to build a stable key for device '$($Device.Name)'."
}
