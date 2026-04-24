function Test-CloudDevicePendingActivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Device,

        [Parameter(Mandatory)]
        [PSObject] $ProcessedDevice
    )

    foreach ($activityProperty in 'EntraLastSeen', 'IntuneLastSeen') {
        $currentActivity = if ($Device.PSObject.Properties[$activityProperty]) {
            $Device.$activityProperty
        } else {
            $null
        }
        $processedActivity = if ($ProcessedDevice.PSObject.Properties[$activityProperty]) {
            $ProcessedDevice.$activityProperty
        } else {
            $null
        }

        if ($null -eq $processedActivity) {
            if ($null -ne $currentActivity) {
                return $false
            }
            continue
        }

        if ($null -eq $currentActivity) {
            return $false
        }

        if ([datetime] $currentActivity -gt [datetime] $processedActivity) {
            return $false
        }
    }

    $true
}
