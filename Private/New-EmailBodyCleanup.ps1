function New-EmailBodyCleanup {
    [CmdletBinding()]
    param(
        [string] $Title,
        [psobject] $Report,
        [string] $ObjectLabel = 'Device'
    )

    # Prepare the stage summary and result rows before rendering the email layout.
    $summaryRows = @($Report.Summary | ForEach-Object {
        $summaryText = @(
            "Candidates: $($_.Candidates); limit: $($_.Limit); results: $($_.Results); remaining without a result: $($_.Remaining)."
            "Completed: $($_.Completed); already satisfied: $($_.AlreadySatisfied); WhatIf: $($_.WhatIf); skipped: $($_.Skipped); report only: $($_.ReportOnly); needs review: $($_.NeedsReview)."
            $_.Note
        )
        [pscustomobject] @{
            Stage   = "$($_.Action) - $($_.Mode)"
            Summary = $summaryText -join "`n"
        }
    })
    $actionRows = @($Report.Actions | ForEach-Object {
        $context = [System.Collections.Generic.List[string]]::new()
        if ($_.Reason) {
            $readableReason = [regex]::Replace([string] $_.Reason, '([a-z])([A-Z])', '$1 $2')
            $context.Add($readableReason.Replace('=', ' = '))
        }
        if ($_.Notes) {
            $context.Add("Notes: $($_.Notes)")
        }
        [pscustomobject] @{
            $ObjectLabel    = if ($_.Domain) { "$($_.Device) ($($_.Domain))" } else { $_.Device }
            Action          = $_.Action
            Outcome         = $_.Outcome
            'Reason / notes' = $context -join "`n"
        }
    })

    # Shared PSWriteHTML layout for computer, cloud, service-account and SID cleanup.
    EmailBody -FontFamily 'Arial, Helvetica, sans-serif' -FontSize '13px' -Color '#334155' -EmailBody {
        EmailLayout {
            EmailLayoutRow {
                EmailLayoutColumn -Width '100%' -Padding '16px' -BorderTopStyle solid -BorderTopColor '#0f766e' -BorderTopWidthSize '4px' {
                    # Header: cleanup title and run details.
                    EmailText -Text $Title -FontSize '22px' -FontWeight bold -Color '#0f766e'
                    EmailText -Text "Run on $env:COMPUTERNAME | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -FontSize '12px' -Color '#64748b'
                    # Summary: stage modes, candidate counts, outcomes and limits.
                    EmailText -Text 'Run summary' -FontWeight bold -FontSize '16px' -LineBreak
                    if ($summaryRows.Count) {
                        EmailTable -DataTable $summaryRows -HideFooter -WordBreak break-word {
                            EmailTableHeader -Names 'Stage', 'Summary' -BackgroundColor '#e0f2f1' -Color '#134e4a' -Alignment left
                        }
                    }
                    EmailText -Text 'Completed = successful overall result. Previews make no changes. Needs review includes failures, partial changes and blocked previews.' -FontSize '12px' -Color '#64748b' -LineBreak
                    # Results: one compact row per action, with its reason and notes.
                    if ($actionRows.Count) {
                        EmailText -Text "$ObjectLabel results ($($actionRows.Count))" -FontWeight bold -FontSize '16px' -LineBreak
                        EmailTable -DataTable $actionRows -HideFooter -WordBreak break-word {
                            EmailTableHeader -Names $ObjectLabel, 'Action', 'Outcome', 'Reason / notes' -BackgroundColor '#e0f2f1' -Color '#134e4a' -Alignment left
                            EmailTableCondition -Name 'Outcome' -ComparisonType string -Value 'Completed' -BackgroundColor '#dcfce7' -Color '#166534' -Inline
                            EmailTableCondition -Name 'Outcome' -ComparisonType string -Value 'WhatIf preview' -BackgroundColor '#e0f2fe' -Color '#075985' -Inline
                            EmailTableCondition -Name 'Outcome' -ComparisonType string -Value 'WhatIf preview (see notes)' -BackgroundColor '#e0f2fe' -Color '#075985' -Inline
                            EmailTableCondition -Name 'Outcome' -ComparisonType string -Value 'Failed overall (check subactions)' -BackgroundColor '#fee2e2' -Color '#991b1b' -Inline
                            EmailTableCondition -Name 'Outcome' -ComparisonType string -Value 'Failed' -BackgroundColor '#fee2e2' -Color '#991b1b' -Inline
                            EmailTableCondition -Name 'Outcome' -ComparisonType string -Value 'Blocked WhatIf (see notes)' -BackgroundColor '#fef3c7' -Color '#92400e' -Inline
                        }
                    } else {
                        EmailText -Text 'No action results were returned in this run.' -LineBreak
                    }
                    EmailText -Text 'Counts are action results, not unique objects. Full audit fields remain in the cleanup output and configured reports. A failed overall action may still have completed a subaction; check its notes.' -FontSize '12px' -Color '#64748b' -LineBreak
                }
            }
        }
    }
}
