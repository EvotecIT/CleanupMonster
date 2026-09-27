function Get-CleanupEmailActionOutcome {
    [CmdletBinding()]
    param(
        [psobject] $Record,
        [ValidateSet('AD', 'Cloud')] [string] $Source,
        [switch] $ReportOnly,
        [switch] $DisableAndMove
    )

    if ($ReportOnly -or [string] $Record.ActionStatus -eq 'ReportOnly') {
        return [pscustomobject] @{ Category = 'ReportOnly'; Label = 'Report only candidate' }
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
