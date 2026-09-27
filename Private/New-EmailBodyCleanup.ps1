function New-EmailBodyCleanup {
    [CmdletBinding()]
    param([string] $Title, [psobject] $Report)

    EmailBody -EmailBody {
        EmailText -Text $Title -FontWeight bold
        EmailText -Text "Host: $env:COMPUTERNAME; generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')."
        EmailText -Text 'Completed means a recorded successful overall result. WhatIf and report-only rows are previews, not successful changes. Needs review includes failures, partial actions, and results with errors. Already satisfied means no state change was needed.'
        foreach ($stage in $Report.Summary) {
            EmailText -Text "$($stage.Action) - $($stage.Mode)" -FontWeight bold -LineBreak
            EmailList {
                EmailListItem -Text "Candidates: $($stage.Candidates); limit: $($stage.Limit); results: $($stage.Results); remaining without a result: $($stage.Remaining)."
                EmailListItem -Text "Completed: $($stage.Completed); already satisfied: $($stage.AlreadySatisfied); WhatIf: $($stage.WhatIf); skipped: $($stage.Skipped); report only: $($stage.ReportOnly); needs review: $($stage.NeedsReview)."
                if ($stage.NeedsReview -gt 0) { EmailListItem -Text "Of the results needing review, $($stage.Failed) failed overall or had a WhatIf error. Check row outcomes and subaction notes for partial changes." }
                EmailListItem -Text $stage.Note
            }
        }
        if ($Report.Actions.Count -gt 0) {
            EmailText -Text 'Results this run' -FontWeight bold -LineBreak
            foreach ($action in $Report.Actions) {
                EmailText -Text "$($action.Device) $($action.Action) $($action.Outcome)" -FontWeight bold -LineBreak
                EmailList {
                    EmailListItem -Text "When: $($action.When)"
                    EmailListItem -Text "Reason: $($action.Reason)"
                    EmailListItem -Text "Details: $($action.Details)"
                }
            }
        } else {
            EmailText -Text 'No action results were returned in this run.' -LineBreak
        }
        EmailText -Text 'Counts describe action results, not unique devices. A device can appear in more than one stage. The summary covers this run; full logs and the HTML report remain the detailed audit.' -LineBreak
    }
}
