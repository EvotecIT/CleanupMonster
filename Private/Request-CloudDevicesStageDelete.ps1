function Request-CloudDevicesStageDelete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices,

        [Parameter(Mandatory)]
        [datetime] $Today,

        [int] $StageLimit = 0,

        [switch] $ReportOnly,
        [switch] $WhatIfStageDelete,
        [switch] $WhatIf
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $attemptedCount = 0

    foreach ($device in $Devices) {
        if ($StageLimit -gt 0 -and $attemptedCount -ge $StageLimit) {
            break
        }

        $alreadyPending = $false
        foreach ($processedDeviceKey in @(
                if ($device.PSObject.Properties['MatchedProcessedDeviceKey'] -and $device.MatchedProcessedDeviceKey) {
                    $device.MatchedProcessedDeviceKey
                }
                if ($device.PSObject.Properties['ProcessedDeviceKey'] -and $device.ProcessedDeviceKey) {
                    $device.ProcessedDeviceKey
                }
            )) {
            if ($ProcessedDevices.Contains($processedDeviceKey)) {
                $alreadyPending = $true
                break
            }
        }

        if ($alreadyPending) {
            continue
        }

        $actionStatus = if ($ReportOnly) {
            'ReportOnly'
        } elseif ($WhatIf -or $WhatIfStageDelete) {
            'WhatIf'
        } else {
            'True'
        }

        $result = $device | Select-Object *
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionDate' -Value $Today -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionStatus' -Value $actionStatus -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'Action' -Value 'StageDelete' -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionNotes' -Value 'Device staged for delete after pending grace period.' -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ProcessedDeviceKeys' -Value $device.ProcessedDeviceKeys -Force
        $results.Add($result)
        $attemptedCount++

        if (-not ($WhatIf -or $WhatIfStageDelete -or $ReportOnly)) {
            Set-ProcessedCloudDeviceRecord -ProcessedDevices $ProcessedDevices -Device $device -Result $result
        }
    }

    @($results)
}
