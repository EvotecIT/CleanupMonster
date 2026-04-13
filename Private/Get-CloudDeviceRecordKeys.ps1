function Get-CloudDeviceRecordKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Device
    )

    $keys = [System.Collections.Generic.List[string]]::new()
    $seenKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($candidateKey in @(
            if ($Device.PSObject.Properties['ManagedDeviceId'] -and $Device.ManagedDeviceId) {
                "intune:$($Device.ManagedDeviceId)"
            }
            if ($Device.PSObject.Properties['EntraDeviceObjectId'] -and $Device.EntraDeviceObjectId) {
                "entra:$($Device.EntraDeviceObjectId)"
            }
            if ($Device.PSObject.Properties['DeviceId'] -and $Device.DeviceId) {
                "device:$($Device.DeviceId)"
            }
        )) {
        if ($candidateKey -and $seenKeys.Add($candidateKey)) {
            $keys.Add($candidateKey)
        }
    }

    if ($keys.Count -eq 0) {
        throw "Get-CloudDeviceRecordKeys - Unable to build stable keys for device '$($Device.Name)'."
    }

    @($keys)
}
