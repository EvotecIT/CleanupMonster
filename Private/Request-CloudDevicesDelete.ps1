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

        [switch] $DeleteAutopilotIdentity,

        [switch] $ReportOnly,
        [switch] $WhatIfDelete,
        [switch] $WhatIf
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $attemptedCount = 0

    foreach ($device in $Devices) {
        if ($DeleteLimit -gt 0 -and $attemptedCount -ge $DeleteLimit) {
            break
        }

        $subActionMessages = [System.Collections.Generic.List[string]]::new()
        $subActionSuccess = $true
        $subActionExecuted = $false
        $continueRecordDelete = $true

        if (-not $ReportOnly) {
            if ($DeleteAutopilotIdentity) {
                $operatingSystem = [string] $device.OperatingSystem
                $autopilotMayApply = [string]::IsNullOrWhiteSpace($operatingSystem) -or $operatingSystem -eq 'Unknown' -or $operatingSystem -like 'Windows*'
                if ($device.AutopilotOnboarded -eq $true) {
                    $subActionExecuted = $true
                    if ([string]::IsNullOrWhiteSpace([string] $device.AutopilotDeviceId)) {
                        $subActionSuccess = $false
                        $continueRecordDelete = $false
                        $subActionMessages.Add('Autopilot: Device is onboarded but AutopilotDeviceId is missing; record delete was skipped.')
                    } else {
                        $removeAutopilotResult = Remove-MyAutopilotDevice -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfDelete)
                        if ($removeAutopilotResult.Message) {
                            $subActionMessages.Add("Autopilot: $($removeAutopilotResult.Message)")
                        }
                        if (-not $removeAutopilotResult.Success -and -not ($WhatIf -or $WhatIfDelete)) {
                            $subActionSuccess = $false
                            $continueRecordDelete = $false
                        }
                    }
                } elseif ($autopilotMayApply -and $device.AutopilotInventoryLoaded -ne $true -and $device.AutopilotOnboarded -ne $false) {
                    $subActionExecuted = $true
                    $subActionSuccess = $false
                    $continueRecordDelete = $false
                    $subActionMessages.Add('Autopilot: Inventory was not loaded; record delete was skipped.')
                }
            }

            if ($continueRecordDelete -and $DeleteRemoveIntuneRecord -and $device.HasIntuneRecord) {
                $subActionExecuted = $true
                $removeIntuneResult = Remove-MyDeviceIntuneRecord -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfDelete)
                if ($removeIntuneResult.Message) {
                    $subActionMessages.Add("Intune: $($removeIntuneResult.Message)")
                }
                if (-not $removeIntuneResult.Success -and -not ($WhatIf -or $WhatIfDelete)) {
                    $subActionSuccess = $false
                }
            }

            if ($continueRecordDelete -and $device.HasEntraRecord -and $device.RecordState -ne 'IntuneOnly') {
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
        $attemptedCount++

        if (($subActionExecuted -and ($subActionSuccess -or $WhatIf -or $WhatIfDelete)) -or $ReportOnly) {
            if (-not ($WhatIf -or $WhatIfDelete -or $ReportOnly)) {
                Remove-ProcessedCloudDeviceRecord -ProcessedDevices $ProcessedDevices -Device $device
            }
        }
    }

    @($results)
}
