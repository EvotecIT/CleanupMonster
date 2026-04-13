function Request-CloudDevicesRetire {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices,

        [Parameter(Mandatory)]
        [datetime] $Today,

        [int] $RetireLimit = 0,

        [switch] $ReportOnly,
        [switch] $WhatIfRetire,
        [switch] $WhatIf
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $processedCount = 0

    foreach ($device in $Devices) {
        if ($RetireLimit -gt 0 -and $processedCount -ge $RetireLimit) {
            break
        }

        if ($ReportOnly) {
            $actionStatus = 'ReportOnly'
            $actionSucceeded = $true
        } else {
            $retireResult = Invoke-MyDeviceRetire -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfRetire)
            $actionSucceeded = [bool] $retireResult.Success
            $actionStatus = if ($WhatIf -or $WhatIfRetire) { 'WhatIf' } elseif ($retireResult.Success) { 'True' } else { 'False' }
        }

        $result = $device | Select-Object *
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionDate' -Value $Today -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionStatus' -Value $actionStatus -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'Action' -Value 'Retire' -Force
        $results.Add($result)

        if ($actionSucceeded -or $WhatIf -or $WhatIfRetire -or $ReportOnly) {
            $ProcessedDevices[$device.ProcessedDeviceKey] = $result
            $processedCount++
        }
    }

    @($results)
}
