function Get-CleanupEmailReport {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun = @(),
        [Array] $StageConfiguration = @(),
        [ValidateSet('AD', 'Cloud', 'ServiceAccount')] [string] $Source,
        [switch] $DisableAndMove
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($record in $CurrentRun) {
        $stage = @($StageConfiguration | Where-Object { $_.Action -eq $record.Action -and (-not $_.Domain -or $_.Domain -eq $record.DomainName) }) | Select-Object -First 1
        $outcome = Get-CleanupEmailActionOutcome -Record $record -Source $Source -ReportOnly:($stage.Mode -eq 'Report only') -DisableAndMove:$DisableAndMove
        $details = [System.Collections.Generic.List[string]]::new()
        $fields = if ($Source -ne 'Cloud') {
            @('DomainName', 'DNSHostName', 'DistinguishedName', 'OperatingSystem', 'LastLogonDays', 'PasswordLastChangedDays', 'TimeOnPendingList', 'DisableActionResult', 'MoveActionResult', 'ActionComment')
        } else {
            @('EntraDeviceObjectId', 'ManagedDeviceId', 'AutopilotDeviceId', 'OperatingSystem', 'EntraLastSeenDays', 'IntuneLastSeenDays', 'EntraRegisteredDays', 'TimeOnPendingList', 'ActionBlocked', 'AutopilotIdentityRemoved', 'ActionNotes')
        }
        foreach ($field in $fields) {
            $property = $record.PSObject.Properties[$field]
            if ($property -and $null -ne $property.Value -and [string] $property.Value -ne '') {
                $details.Add("${field}: $($property.Value)")
            }
        }
        if ($Source -eq 'Cloud') {
            $audit = Get-CloudDeviceAuditContext -Device $record
            foreach ($property in $audit.PSObject.Properties) { $details.Add("$($property.Name): $($property.Value)") }
        }
        $rows.Add([pscustomobject] @{
                Device = if ($Source -ne 'Cloud') { $record.SamAccountName } else { $record.Name }
                Domain = $record.DomainName
                Action = if ($DisableAndMove -and $record.Action -eq 'Disable') { 'Disable and move' } else { $record.Action }
                Outcome = $outcome.Label
                When = $record.ActionDate
                Reason = $record.SelectionReason
                Notes = if ($Source -ne 'Cloud') { $record.ActionComment } else { $record.ActionNotes }
                Details = $details -join '; '
                Category = $outcome.Category
                Stage = $record.Action
            })
    }

    $summary = foreach ($stage in $StageConfiguration) {
        $stageRows = @($rows | Where-Object { $_.Stage -eq $stage.Action -and (-not $stage.Domain -or $_.Domain -eq $stage.Domain) })
        $counts = @{ Completed = 0; AlreadySatisfied = 0; WhatIf = 0; Skipped = 0; ReportOnly = 0; NeedsReview = 0 }
        foreach ($row in $stageRows) { $counts[$row.Category]++ }
        $remaining = [Math]::Max(0, [int] $stage.Candidates - $stageRows.Count)
        $limitApplies = $stage.Mode -ne 'Suppressed' -and ($Source -eq 'Cloud' -or $stage.Mode -ne 'Report only')
        $limitReached = $limitApplies -and $stage.Limit -gt 0 -and $stageRows.Count -ge $stage.Limit -and $remaining -gt 0
        if ($stage.Action -eq 'StageDelete' -or ($Source -eq 'AD' -and $stage.Action -eq 'Move')) { $limitReached = $limitApplies -and $stage.LimitStoppedIteration -eq $true }
        $note = if ($stage.Mode -eq 'Suppressed') { 'Actions suppressed because inventory was incomplete or below its safety limit.' }
        elseif ($stage.ConfirmationDeclined) { 'Confirmation declined; no action was started for this stage.' }
        elseif ($limitReached) { "Limit reached ($($stage.Limit)); $remaining candidate(s) have no action result." }
        elseif ($remaining -gt 0) { "$remaining candidate(s) have no action result; see the run log for skips or an early stop." }
        else { 'All candidates have a result.' }
        if ($stage.AlreadyPendingSkipped -gt 0) { $note += " Already pending: $($stage.AlreadyPendingSkipped) candidate(s) skipped without a result." }
        if ($stage.AlreadyAtTargetSkipped -gt 0) { $note += " Already in target OU: $($stage.AlreadyAtTargetSkipped) candidate(s) skipped without a result." }
        if ($stage.ExcludedForDisable -gt 0) { $note += " Excluded from delete: $($stage.ExcludedForDisable) account(s) selected for disable in this run." }
        [pscustomobject] @{
            Action = $stage.Name
            Mode = $stage.Mode
            Candidates = [int] $stage.Candidates
            Limit = if ($stage.Limit -eq 0) { 'Unlimited' } elseif (-not $limitApplies) { "$($stage.Limit) (not applied)" } else { [string] $stage.Limit }
            Results = $stageRows.Count
            Completed = $counts.Completed
            AlreadySatisfied = $counts.AlreadySatisfied
            WhatIf = $counts.WhatIf
            Skipped = $counts.Skipped
            ReportOnly = $counts.ReportOnly
            NeedsReview = $counts.NeedsReview
            Failed = @($stageRows | Where-Object { $_.Outcome -in @('Failed', 'Failed overall (check subactions)', 'WhatIf error') }).Count
            Remaining = $remaining
            Note = $note
        }
    }
    [pscustomobject] @{ Summary = @($summary); Actions = $rows.ToArray() }
}
