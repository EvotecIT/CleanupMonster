function Write-CloudDeviceActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Action,

        [int] $CandidateCount,
        [int] $Limit,
        [Array] $Results = @(),
        [string] $LogPath,
        [switch] $ConfirmationDeclined
    )

    $completed = 0
    $previewed = 0
    $reported = 0
    $failed = 0

    foreach ($device in $Results) {
        $status = [string] $device.ActionStatus
        if ($status -eq 'ReportOnly') {
            $reported++
            continue
        }
        $prefix = '[i] '
        $color = 'Cyan'
        $outcome = 'failed'
        switch ($status) {
            'True' { $completed++; $prefix = '[+] '; $color = 'Green'; $outcome = 'completed' }
            'WhatIf' { $previewed++; $outcome = 'WhatIf preview' }
            default { $failed++; $prefix = '[-] '; $color = 'Red' }
        }

        $name = ([string] $device.Name) -replace '[\r\n]+', ' '
        $identity = "Name='$name'"
        foreach ($field in @(
                @{ Name = 'EntraObjectId'; Value = $device.EntraDeviceObjectId }
                @{ Name = 'IntuneManagedDeviceId'; Value = $device.ManagedDeviceId }
                @{ Name = 'AutopilotId'; Value = $device.AutopilotDeviceId }
                @{ Name = 'DeviceKey'; Value = $device.ProcessedDeviceKey }
            )) {
            if (-not [string]::IsNullOrWhiteSpace([string] $field.Value)) {
                $identity += "; $($field.Name)=$($field.Value)"
            }
        }

        $details = "$Action ${outcome}: $identity"
        if (-not [string]::IsNullOrWhiteSpace([string] $device.ActionNotes)) {
            $notes = ([string] $device.ActionNotes) -replace '[\r\n]+', ' '
            $details += "; $notes"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $device.SelectionReason)) {
            $reason = ([string] $device.SelectionReason) -replace '[\r\n]+', ' '
            $details += "; SelectionReason: $reason"
        }
        Write-Color -Text $prefix, $details -Color Yellow, $color -LogFile $LogPath
        $audit = Get-CloudDeviceAuditContext -Device $device
        Write-Color -Text '    ', "Identity: Owner=$($audit.RegisteredOwner); OwnerUPN=$($audit.RegisteredOwnerUPN); IntuneUserUPN=$($audit.IntuneUserUPN)" -Color DarkGray, Gray -LogFile $LogPath
        Write-Color -Text '    ', "Compliance: Entra=$($audit.EntraCompliant); Intune=$($audit.IntuneCompliance)" -Color DarkGray, Gray -LogFile $LogPath
        Write-Color -Text '    ', "Management: EntraManaged=$($audit.EntraManaged); EntraType=$($audit.EntraManagementType); MdmAppId=$($audit.MdmAppId); IntuneAgent=$($audit.IntuneManagementAgent)" -Color DarkGray, Gray -LogFile $LogPath
    }

    $notProcessed = [Math]::Max(0, $CandidateCount - $Results.Count)
    $summary = "$Action results: $completed completed, $previewed WhatIf, $reported ReportOnly, $failed failed; $notProcessed of $CandidateCount candidate(s) without an action result."
    if ($Limit -gt 0 -and $Results.Count -ge $Limit -and $notProcessed -gt 0) {
        $summary += " Limit reached ($Limit)."
    }
    if ($ConfirmationDeclined) {
        $summary += ' Confirmation declined.'
    }
    Write-Color -Text '[i] ', $summary -Color Yellow, Cyan -LogFile $LogPath
}
