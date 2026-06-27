function Merge-CloudDeviceReportInventory {
    [CmdletBinding()]
    param(
        [Array] $PrimaryDevices,
        [Array] $AdditionalDevices
    )

    function Get-CloudDeviceReportInventoryKey {
        param(
            [Parameter(Mandatory)]
            [object] $Device
        )

        @(
            if ($Device.PSObject.Properties['ManagedDeviceId'] -and $Device.ManagedDeviceId) { "intune:$($Device.ManagedDeviceId)" }
            if ($Device.PSObject.Properties['EntraDeviceObjectId'] -and $Device.EntraDeviceObjectId) { "entra:$($Device.EntraDeviceObjectId)" }
            if ($Device.PSObject.Properties['DeviceId'] -and $Device.DeviceId) { "device:$($Device.DeviceId)" }
            if ($Device.PSObject.Properties['AutopilotDeviceId'] -and $Device.AutopilotDeviceId) { "autopilot:$($Device.AutopilotDeviceId)" }
        )
    }

    $reportDevices = @($PrimaryDevices)
    if (-not $AdditionalDevices) {
        return $reportDevices
    }

    $reportDeviceKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($reportDevice in $reportDevices) {
        foreach ($key in @(Get-CloudDeviceReportInventoryKey -Device $reportDevice)) {
            $null = $reportDeviceKeys.Add($key)
        }
    }

    foreach ($additionalDevice in @($AdditionalDevices)) {
        $additionalDeviceKeys = @(Get-CloudDeviceReportInventoryKey -Device $additionalDevice)
        $knownReportDevice = $false
        foreach ($key in $additionalDeviceKeys) {
            if ($reportDeviceKeys.Contains($key)) {
                $knownReportDevice = $true
                break
            }
        }
        if (-not $knownReportDevice) {
            $reportDevices += $additionalDevice
            foreach ($key in $additionalDeviceKeys) {
                $null = $reportDeviceKeys.Add($key)
            }
        }
    }

    $reportDevices
}
