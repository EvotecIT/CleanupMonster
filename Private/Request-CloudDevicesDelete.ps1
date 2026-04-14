function Request-CloudDevicesDelete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices,

        [Parameter(Mandatory)]
        [datetime] $Today,

        [int] $DeleteLimit = 0,

        [bool] $DeleteRemoveIntuneRecord = $true,

        [switch] $ReportOnly,
        [switch] $WhatIfDelete,
        [switch] $WhatIf
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $processedCount = 0

    foreach ($device in $Devices) {
        if ($DeleteLimit -gt 0 -and $processedCount -ge $DeleteLimit) {
            break
        }

        $subActionMessages = [System.Collections.Generic.List[string]]::new()
        $subActionSuccess = $true
        $subActionExecuted = $false

        if (-not $ReportOnly) {
            if ($DeleteRemoveIntuneRecord -and $device.HasIntuneRecord) {
                $subActionExecuted = $true
                $removeIntuneResult = Remove-MyDeviceIntuneRecord -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfDelete)
                if ($removeIntuneResult.Message) {
                    $subActionMessages.Add("Intune: $($removeIntuneResult.Message)")
                }
                if (-not $removeIntuneResult.Success -and -not ($WhatIf -or $WhatIfDelete)) {
                    $subActionSuccess = $false
                }
            }

            if ($device.HasEntraRecord -and $device.RecordState -ne 'IntuneOnly') {
                $subActionExecuted = $true
                $removeEntraResult = Remove-MyDevice -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfDelete)
                if ($removeEntraResult.Message) {
                    $subActionMessages.Add("Entra: $($removeEntraResult.Message)")
                }
                if (-not $removeEntraResult.Success -and -not ($WhatIf -or $WhatIfDelete)) {
                    $subActionSuccess = $false
                }
            }

            if (-not $subActionExecuted) {
                $subActionSuccess = $false
                $subActionMessages.Add('No delete sub-actions were applicable for this device.')
            }
        }

        $actionStatus = if ($ReportOnly) {
            'ReportOnly'
        } elseif (-not $subActionExecuted) {
            'False'
        } elseif ($WhatIf -or $WhatIfDelete) {
            'WhatIf'
        } elseif ($subActionSuccess) {
            'True'
        } else {
            'False'
        }

        $result = $device | Select-Object *
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionDate' -Value $Today -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionStatus' -Value $actionStatus -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'Action' -Value 'Delete' -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionNotes' -Value ($subActionMessages -join '; ') -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ProcessedDeviceKeys' -Value $device.ProcessedDeviceKeys -Force
        $results.Add($result)

        if (($subActionExecuted -and ($subActionSuccess -or $WhatIf -or $WhatIfDelete)) -or $ReportOnly) {
            if (-not ($WhatIf -or $WhatIfDelete -or $ReportOnly)) {
                Remove-ProcessedCloudDeviceRecord -ProcessedDevices $ProcessedDevices -Device $device
            }
            $processedCount++
        }
    }

    @($results)
}
