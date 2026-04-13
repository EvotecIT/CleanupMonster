function Get-CloudDevicesToProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Retire', 'Disable', 'Delete')]
        [string] $Type,

        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ActionIf,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ProcessedDevices
    )

    Write-Color -Text '[i] ', "Applying following rules to $Type action:" -Color Yellow, Cyan, Green
    foreach ($key in $ActionIf.Keys) {
        if ($null -eq $ActionIf[$key] -or ($ActionIf[$key] -is [System.Array] -and $ActionIf[$key].Count -eq 0)) {
            Write-Color -Text '   [>] ', $key, ' is ', 'Not Set' -Color Yellow, Cyan, Yellow
        } else {
            Write-Color -Text '   [>] ', $key, ' is ', $ActionIf[$key] -Color Yellow, Cyan, Green
        }
    }

    $today = Get-Date
    $candidates = foreach ($device in $Devices) {
        $processedRecord = Find-ProcessedCloudDeviceRecord -Device $device -ProcessedDevices $ProcessedDevices
        $deviceKey = $processedRecord.CurrentDeviceKey
        $processedDevice = $processedRecord.ProcessedDevice
        $processedActionSucceeded = $false

        if ($processedDevice) {
            $processedActionSucceeded = $processedDevice.ActionStatus -is [bool] -and $processedDevice.ActionStatus
            if (-not $processedActionSucceeded) {
                $processedActionSucceeded = [string] $processedDevice.ActionStatus -eq 'True'
            }
        }

        if ($ActionIf.ExcludeCompanyOwned -and $device.ManagedDeviceOwnerType -eq 'company') {
            continue
        }

        if ($Type -eq 'Retire') {
            if (-not $device.HasIntuneRecord) {
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly' -and -not $ActionIf.IncludeIntuneOnly) {
                continue
            }
            if ($processedDevice -and $processedDevice.Action -eq 'Retire' -and $processedActionSucceeded) {
                continue
            }
        } elseif ($Type -eq 'Disable') {
            if (-not $device.HasEntraRecord -or $device.Enabled -eq $false) {
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly') {
                continue
            }
            if ($device.RecordState -eq 'EntraOnly' -and -not $ActionIf.IncludeEntraOnly) {
                continue
            }
        } elseif ($Type -eq 'Delete') {
            if (-not $device.HasEntraRecord -and -not $device.HasIntuneRecord) {
                continue
            }
            if ($device.HasEntraRecord -and $device.Enabled -eq $true) {
                continue
            }
            if ($device.RecordState -eq 'EntraOnly' -and -not $ActionIf.IncludeEntraOnly) {
                continue
            }
            if ($device.RecordState -eq 'IntuneOnly' -and -not $ActionIf.IncludeIntuneOnly) {
                continue
            }
        }

        if ($null -ne $ActionIf.ListProcessedMoreThan) {
            if (-not $processedDevice -or -not $processedDevice.ActionDate -or -not $processedActionSucceeded) {
                continue
            }

            $timeOnPendingList = (New-TimeSpan -Start $processedDevice.ActionDate -End $today).Days
            if ($timeOnPendingList -lt $ActionIf.ListProcessedMoreThan) {
                $processedDevice.TimeOnPendingList = $timeOnPendingList
                $processedDevice.TimeToNextAction = $ActionIf.ListProcessedMoreThan - $timeOnPendingList
                continue
            }
        }

        if ($null -ne $ActionIf.LastSeenEntraMoreThan) {
            if ($null -eq $device.EntraLastSeenDays -or $device.EntraLastSeenDays -le $ActionIf.LastSeenEntraMoreThan) {
                continue
            }
        }

        if ($null -ne $ActionIf.LastSeenIntuneMoreThan) {
            if ($null -eq $device.IntuneLastSeenDays -or $device.IntuneLastSeenDays -le $ActionIf.LastSeenIntuneMoreThan) {
                continue
            }
        }

        $candidate = $device | Select-Object *
        $selectionReason = Get-CloudDeviceSelectionReason -Device $device -Type $Type -ActionIf $ActionIf -ProcessedDevice $processedDevice
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'Action' -Value $Type -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'ProcessedDeviceKey' -Value $deviceKey -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'ProcessedDeviceKeys' -Value $processedRecord.CurrentDeviceKeys -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'MatchedProcessedDeviceKey' -Value $processedRecord.MatchedProcessedDeviceKey -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'TimeOnPendingList' -Value $(if ($processedDevice) { $processedDevice.TimeOnPendingList } else { $null }) -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'TimeToNextAction' -Value $(if ($processedDevice) { $processedDevice.TimeToNextAction } else { $null }) -Force
        Add-Member -InputObject $candidate -MemberType NoteProperty -Name 'SelectionReason' -Value $selectionReason -Force
        $candidate
    }

    @($candidates)
}
