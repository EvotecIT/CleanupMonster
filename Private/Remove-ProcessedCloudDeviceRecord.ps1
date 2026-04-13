function Remove-ProcessedCloudDeviceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices,

        [Parameter(Mandatory)]
        [PSObject] $Device
    )

    foreach ($processedDeviceKey in @(
            if ($Device.PSObject.Properties['MatchedProcessedDeviceKey'] -and $Device.MatchedProcessedDeviceKey) {
                $Device.MatchedProcessedDeviceKey
            }
            if ($Device.PSObject.Properties['ProcessedDeviceKey'] -and $Device.ProcessedDeviceKey) {
                $Device.ProcessedDeviceKey
            }
        )) {
        if ($ProcessedDevices.Contains($processedDeviceKey)) {
            $null = $ProcessedDevices.Remove($processedDeviceKey)
        }
    }
}
