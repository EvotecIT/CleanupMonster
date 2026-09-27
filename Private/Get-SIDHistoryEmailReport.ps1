function Get-SIDHistoryEmailReport {
    [CmdletBinding()]
    param([System.Collections.IDictionary] $Export)

    $rows = [System.Collections.Generic.List[object]]::new()
    $counts = @{ Completed=0; WhatIf=0; Skipped=0; ReportOnly=0; NeedsReview=0 }
    $selectedSIDCount = 0
    foreach ($item in $Export.ObjectsToProcess) {
        $sids = @(if ($item.SIDHistoryToRemove) { $item.SIDHistoryToRemove } else { $item.Object.SIDHistory })
        $selectedSIDCount += $sids.Count
        if ($Export.EmailMode -eq 'Report only') {
            foreach ($sid in $sids) {
                $rows.Add([pscustomobject] @{ Device=$item.Object.Name; Domain=$item.Object.Domain; Action='Remove SID history'; Outcome='Report only candidate'; Reason="Target SID: $sid; SID domain: $($item.Domain)"; Notes='' })
                $counts.ReportOnly++
            }
        }
    }
    if ($Export.EmailMode -ne 'Report only') {
        foreach ($record in $Export.CurrentRun) {
            $category = switch ([string] $record.ActionStatus) { 'Success' {'Completed'} 'WhatIf' {'WhatIf'} 'Skipped' {'Skipped'} default {'NeedsReview'} }
            $label = switch ($category) { 'Completed' {'Completed'} 'WhatIf' {'WhatIf preview'} 'Skipped' {'Skipped'} default {'Failed'} }
            $notes = [string] $record.ActionError
            if ($record.VerificationError) {
                $category = 'NeedsReview'
                $label = if ($record.ActionStatus -eq 'Success') { 'Completed; verification failed' } elseif ($record.ActionStatus -eq 'WhatIf') { 'WhatIf error' } else { $label }
                $notes += " Verification failed: $($record.VerificationError)"
                if ($null -eq $record.SIDAfterTargetedCount) {
                    $notes += '; remaining SID counts are unknown.'
                }
            }
            $counts[$category]++
            $rows.Add([pscustomobject] @{ Device=$record.ObjectName; Domain=$record.ObjectDomain; Action='Remove SID history'; Outcome=$label; Reason="Target SID: $($record.SIDAttempted); targeted before: $($record.SIDBeforeTargetedCount)"; Notes=$notes })
        }
    }
    $remaining = [Math]::Max(0, $selectedSIDCount - $rows.Count)
    $limitText = "Objects: $(if ($null -eq $Export.RemoveLimitObject) {'Unlimited'} else {$Export.RemoveLimitObject}); SIDs: $(if ($null -eq $Export.RemoveLimitSID) {'Unlimited'} else {$Export.RemoveLimitSID})"
    $notes = [System.Collections.Generic.List[string]]::new()
    $notes.Add("Selected $(@($Export.ObjectsToProcess).Count) object/domain group(s), $selectedSIDCount SID value(s). Counts are per SID result, not unique objects.")
    if ($Export.ObjectCollectionLimitReached) { $notes.Add('Object collection reached its configured limit; eligible totals beyond that boundary were not evaluated.') }
    if ($Export.SIDLimitStoppedIteration) { $notes.Add("SID limit stopped removal with $remaining selected SID value(s) without a result.") }
    if ($Export.EmailMode -eq 'Report only') { $notes.Add('No removals attempted. Object collection limit applies; SID removal limit is not applied in report-only mode.') }
    [pscustomobject] @{
        Actions=$rows.ToArray()
        Summary=@([pscustomobject] @{ Action='Remove SID history'; Mode=$Export.EmailMode; Candidates=$selectedSIDCount; Limit=$limitText; Results=$rows.Count; Remaining=$remaining; Completed=$counts.Completed; AlreadySatisfied=0; WhatIf=$counts.WhatIf; Skipped=$counts.Skipped; ReportOnly=$counts.ReportOnly; NeedsReview=$counts.NeedsReview; Note=$notes -join ' ' })
    }
}
