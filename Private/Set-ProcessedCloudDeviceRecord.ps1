function Set-ProcessedCloudDeviceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices,

        [Parameter(Mandatory)]
        [PSObject] $Device,

        [Parameter(Mandatory)]
        [PSObject] $Result
    )

    if ($Device.PSObject.Properties['MatchedProcessedDeviceKey'] -and
        $Device.MatchedProcessedDeviceKey -and
        $Device.MatchedProcessedDeviceKey -ne $Device.ProcessedDeviceKey -and
        $ProcessedDevices.Contains($Device.MatchedProcessedDeviceKey)) {
        $null = $ProcessedDevices.Remove($Device.MatchedProcessedDeviceKey)
    }

    $ProcessedDevices[$Device.ProcessedDeviceKey] = $Result
}
