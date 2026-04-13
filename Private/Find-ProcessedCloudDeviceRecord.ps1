function Find-ProcessedCloudDeviceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Device,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices
    )

    $currentDeviceKeys = @(Get-CloudDeviceRecordKeys -Device $Device)

    foreach ($candidateKey in $currentDeviceKeys) {
        if ($ProcessedDevices.Contains($candidateKey)) {
            return [PSCustomObject] @{
                CurrentDeviceKey         = $currentDeviceKeys[0]
                CurrentDeviceKeys        = $currentDeviceKeys
                MatchedProcessedDeviceKey = $candidateKey
                ProcessedDevice          = $ProcessedDevices[$candidateKey]
            }
        }
    }

    foreach ($processedDeviceKey in @($ProcessedDevices.Keys)) {
        $processedDevice = $ProcessedDevices[$processedDeviceKey]
        $processedDeviceKeys = @()

        if ($processedDevice.PSObject.Properties['ProcessedDeviceKeys'] -and $processedDevice.ProcessedDeviceKeys) {
            $processedDeviceKeys = @($processedDevice.ProcessedDeviceKeys)
        } else {
            $processedDeviceKeys = @(
                if ($processedDevice.PSObject.Properties['ManagedDeviceId'] -and $processedDevice.ManagedDeviceId) {
                    "intune:$($processedDevice.ManagedDeviceId)"
                }
                if ($processedDevice.PSObject.Properties['EntraDeviceObjectId'] -and $processedDevice.EntraDeviceObjectId) {
                    "entra:$($processedDevice.EntraDeviceObjectId)"
                }
                if ($processedDevice.PSObject.Properties['DeviceId'] -and $processedDevice.DeviceId) {
                    "device:$($processedDevice.DeviceId)"
                }
            )
        }

        foreach ($candidateKey in $currentDeviceKeys) {
            if ($processedDeviceKeys -contains $candidateKey) {
                return [PSCustomObject] @{
                    CurrentDeviceKey         = $currentDeviceKeys[0]
                    CurrentDeviceKeys        = $currentDeviceKeys
                    MatchedProcessedDeviceKey = $processedDeviceKey
                    ProcessedDevice          = $processedDevice
                }
            }
        }
    }

    [PSCustomObject] @{
        CurrentDeviceKey         = $currentDeviceKeys[0]
        CurrentDeviceKeys        = $currentDeviceKeys
        MatchedProcessedDeviceKey = $null
        ProcessedDevice          = $null
    }
}
