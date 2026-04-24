function Request-CloudDevicesDisable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices,

        [Parameter(Mandatory)]
        [datetime] $Today,

        [int] $DisableLimit = 0,

        [switch] $ReportOnly,
        [switch] $WhatIfDisable,
        [switch] $WhatIf
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $processedCount = 0

    foreach ($device in $Devices) {
        if ($DisableLimit -gt 0 -and $processedCount -ge $DisableLimit) {
            break
        }

        if ($ReportOnly) {
            $actionStatus = 'ReportOnly'
            $actionSucceeded = $true
        } else {
            $disableResult = Disable-MyDevice -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfDisable)
            $actionSucceeded = [bool] $disableResult.Success
            $actionStatus = if ($WhatIf -or $WhatIfDisable) { 'WhatIf' } elseif ($disableResult.Success) { 'True' } else { 'False' }
        }

        $result = $device | Select-Object *
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionDate' -Value $Today -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionStatus' -Value $actionStatus -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'Action' -Value 'Disable' -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ProcessedDeviceKeys' -Value $device.ProcessedDeviceKeys -Force
        $results.Add($result)

        if ($actionSucceeded -and -not ($WhatIf -or $WhatIfDisable -or $ReportOnly)) {
            Set-ProcessedCloudDeviceRecord -ProcessedDevices $ProcessedDevices -Device $device -Result $result
            $processedCount++
        } elseif ($actionSucceeded -or $WhatIf -or $WhatIfDisable -or $ReportOnly) {
            $processedCount++
        }
    }

    @($results)
}
