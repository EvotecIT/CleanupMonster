function Set-CloudDeviceDuplicateNameMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]] $Devices
    )

    $devicesByName = @{}
    foreach ($device in $Devices) {
        $name = [string] $device.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $normalizedName = $name.Trim().ToUpperInvariant()
        if (-not $devicesByName.ContainsKey($normalizedName)) {
            $devicesByName[$normalizedName] = [System.Collections.Generic.List[object]]::new()
        }
        $devicesByName[$normalizedName].Add($device)
    }

    foreach ($device in $Devices) {
        Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameCount' -Value 1 -Force
        Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameJoinTypes' -Value @() -Force
        Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameRecordStates' -Value @() -Force
        Add-Member -InputObject $device -MemberType NoteProperty -Name 'PreserveDuplicateNameGroup' -Value $false -Force
        Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameProtectionReason' -Value $null -Force
    }

    foreach ($duplicateGroup in $devicesByName.Values) {
        if ($duplicateGroup.Count -lt 2) {
            continue
        }

        $joinTypes = @($duplicateGroup | ForEach-Object { [string] $_.TrustType } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        $recordStates = @($duplicateGroup | ForEach-Object { [string] $_.RecordState } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        $hasWindowsDevice = @($duplicateGroup | Where-Object { [string] $_.OperatingSystem -like 'Windows*' }).Count -gt 0
        $hasHybridDevice = $joinTypes -contains 'Hybrid AzureAD'
        $hasCloudJoinedDevice = @($joinTypes | Where-Object { $_ -in @('AzureAD joined', 'AzureAD registered') }).Count -gt 0
        $hasAutopilotDevice = @($duplicateGroup | Where-Object { $_.AutopilotOnboarded -eq $true -or -not [string]::IsNullOrWhiteSpace([string] $_.AutopilotDeviceId) }).Count -gt 0
        $preserveGroup = $hasWindowsDevice -and (($hasHybridDevice -and $hasCloudJoinedDevice) -or $hasAutopilotDevice)

        $reason = if ($preserveGroup) {
            if ($hasHybridDevice -and $hasCloudJoinedDevice -and $hasAutopilotDevice) {
                'Same-name Windows Autopilot hybrid duplicate'
            } elseif ($hasHybridDevice -and $hasCloudJoinedDevice) {
                'Same-name Windows hybrid/cloud join duplicate'
            } else {
                'Same-name Windows Autopilot duplicate'
            }
        } else {
            $null
        }

        foreach ($device in $duplicateGroup) {
            Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameCount' -Value $duplicateGroup.Count -Force
            Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameJoinTypes' -Value $joinTypes -Force
            Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameRecordStates' -Value $recordStates -Force
            Add-Member -InputObject $device -MemberType NoteProperty -Name 'PreserveDuplicateNameGroup' -Value $preserveGroup -Force
            Add-Member -InputObject $device -MemberType NoteProperty -Name 'DuplicateNameProtectionReason' -Value $reason -Force
        }
    }
}
