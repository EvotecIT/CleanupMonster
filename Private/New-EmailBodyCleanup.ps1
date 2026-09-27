function New-EmailBodyCleanup {
    [CmdletBinding()]
    param([string] $Title, [psobject] $Report)

    $summaryRows = @($Report.Summary | ForEach-Object {
        [pscustomobject] @{
            Stage = "$($_.Action) - $($_.Mode)"
            Summary = "Candidates: $($_.Candidates); limit: $($_.Limit); results: $($_.Results); remaining without a result: $($_.Remaining).`nCompleted: $($_.Completed); already satisfied: $($_.AlreadySatisfied); WhatIf: $($_.WhatIf); skipped: $($_.Skipped); report only: $($_.ReportOnly); needs review: $($_.NeedsReview).`n$($_.Note)"
        }
    })
    $actionRows = @($Report.Actions | ForEach-Object {
        $context = [System.Collections.Generic.List[string]]::new()
        if ($_.Reason) { $context.Add([string] $_.Reason) }
        if ($_.Notes) { $context.Add("Notes: $($_.Notes)") }
        [pscustomobject] @{
            Device = $_.Device
            Action = $_.Action
            Outcome = $_.Outcome
            'Reason / notes' = $context -join "`n"
        }
    })

    EmailBody -FontFamily 'Arial, Helvetica, sans-serif' -FontSize '13px' -Color '#334155' -EmailBody {
        EmailLayout {
            EmailLayoutRow {
                EmailLayoutColumn -Width '100%' -Padding '16px' -BorderTopStyle solid -BorderTopColor '#0f766e' -BorderTopWidthSize '4px' {
                    EmailText -Text $Title -FontSize '22px' -FontWeight bold -Color '#0f766e'
                    EmailText -Text "Run on $env:COMPUTERNAME | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -FontSize '12px' -Color '#64748b'
                    EmailText -Text 'Run summary' -FontWeight bold -FontSize '16px' -LineBreak
                    if ($summaryRows.Count) {
                        EmailTable -DataTable $summaryRows -HideFooter -WordBreak break-word {
                            EmailTableHeader -Names 'Stage', 'Summary' -BackgroundColor '#e0f2f1' -Color '#134e4a' -Alignment left
                        }
                    }
                    EmailText -Text 'Completed = successful overall result. Previews make no changes. Needs review includes failures, partial changes and blocked previews.' -FontSize '12px' -Color '#64748b' -LineBreak
                    if ($actionRows.Count) {
                        EmailText -Text "Device results ($($actionRows.Count))" -FontWeight bold -FontSize '16px' -LineBreak
                        EmailTable -DataTable $actionRows -HideFooter -WordBreak break-word {
                            EmailTableHeader -Names 'Device', 'Action', 'Outcome', 'Reason / notes' -BackgroundColor '#e0f2f1' -Color '#134e4a' -Alignment left
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
                    EmailText -Text 'Counts are action results, not unique devices. Full timestamps, IDs, ownership, compliance and management details remain in the HTML report, log and saved history. A failed overall delete may still have completed a subaction; check its notes.' -FontSize '12px' -Color '#64748b' -LineBreak
                }
            }
        }
    }
}