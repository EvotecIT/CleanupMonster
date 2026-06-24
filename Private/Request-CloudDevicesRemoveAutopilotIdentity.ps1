function Request-CloudDevicesRemoveAutopilotIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [datetime] $Today,

        [int] $RemoveAutopilotIdentityLimit = 0,

        [switch] $ReportOnly,
        [switch] $WhatIfRemoveAutopilotIdentity,
        [switch] $WhatIf
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $attemptedCount = 0

    foreach ($device in $Devices) {
        if ($RemoveAutopilotIdentityLimit -gt 0 -and $attemptedCount -ge $RemoveAutopilotIdentityLimit) {
            break
        }

        $actionStatus = 'False'
        $actionNotes = $null

        if ($ReportOnly) {
            $actionStatus = 'ReportOnly'
            $actionNotes = 'Autopilot identity removal previewed by report-only mode.'
        } elseif ([string]::IsNullOrWhiteSpace([string] $device.AutopilotDeviceId)) {
            $actionNotes = 'Autopilot: Device is onboarded but AutopilotDeviceId is missing.'
        } else {
            $removeAutopilotResult = Remove-MyAutopilotDevice -InputObject $device -Confirm:$false -WhatIf:$($WhatIf -or $WhatIfRemoveAutopilotIdentity)
            if ($removeAutopilotResult.Message) {
                $actionNotes = "Autopilot: $($removeAutopilotResult.Message)"
            }

            if ($WhatIf -or $WhatIfRemoveAutopilotIdentity) {
                $actionStatus = 'WhatIf'
            } elseif ($removeAutopilotResult.Success) {
                $actionStatus = 'True'
            }
        }

        $result = $device | Select-Object *
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionDate' -Value $Today -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionStatus' -Value $actionStatus -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'Action' -Value 'RemoveAutopilotIdentity' -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ActionNotes' -Value $actionNotes -Force
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'ProcessedDeviceKeys' -Value $device.ProcessedDeviceKeys -Force
        $results.Add($result)
        $attemptedCount++
    }

    @($results)
}
