function Get-CleanupEmailActionOutcome {
    [CmdletBinding()]
    param(
        [psobject] $Record,
        [ValidateSet('AD', 'Cloud', 'ServiceAccount')] [string] $Source,
        [switch] $ReportOnly,
        [switch] $DisableAndMove
    )

    if ($ReportOnly -or [string] $Record.ActionStatus -eq 'ReportOnly') {
        return [pscustomobject] @{ Category = 'ReportOnly'; Label = 'Report only candidate' }
    }
    if ($Source -eq 'ServiceAccount') {
        if ([string] $Record.ActionStatus -eq 'Skipped') { return [pscustomobject] @{ Category='Skipped'; Label='Skipped' } }
        if ([string] $Record.ActionStatus -eq 'WhatIf') {
            return [pscustomobject] @{ Category=if ($Record.ActionComment) {'NeedsReview'} else {'WhatIf'}; Label=if ($Record.ActionComment) {'WhatIf error'} else {'WhatIf preview'} }
        }
        if ([string] $Record.ActionStatus -eq 'True') {
            return [pscustomobject] @{ Category=if ($Record.ActionComment) {'NeedsReview'} else {'Completed'}; Label=if ($Record.ActionComment) {'Completed with issue'} else {'Completed'} }
        }
        return [pscustomobject] @{ Category='NeedsReview'; Label=if ([string] $Record.ActionStatus -eq 'False') {'Failed'} else {'Unknown result'} }
    }
    if ($Source -eq 'AD') {
        $outcome = Get-ADComputerReportOutcome -Computer $Record -DisableAndMove:$DisableAndMove
        $category = switch ($outcome.Label) {
            'Completed' { 'Completed' }
            'Already satisfied' { 'AlreadySatisfied' }
            'WhatIf preview' { 'WhatIf' }
            'Skipped' { 'Skipped' }
            default { 'NeedsReview' }
        }
        return [pscustomobject] @{ Category = $category; Label = $outcome.Label }
    }
    switch ([string] $Record.ActionStatus) {
        'True' { [pscustomobject] @{ Category = 'Completed'; Label = 'Completed' } }
        'WhatIf' {
            if ($Record.ActionBlocked -eq $true) {
                [pscustomobject] @{ Category = 'NeedsReview'; Label = 'Blocked WhatIf (see notes)' }
            } else {
                [pscustomobject] @{ Category = 'WhatIf'; Label = 'WhatIf preview (see notes)' }
            }
        }
        'False' { [pscustomobject] @{ Category = 'NeedsReview'; Label = 'Failed overall (check subactions)' } }
        default { [pscustomobject] @{ Category = 'NeedsReview'; Label = 'Unknown result' } }
    }
}
