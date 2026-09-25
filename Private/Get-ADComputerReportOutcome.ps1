function Get-ADComputerReportOutcome {
    <#
    .SYNOPSIS
    Classifies one AD cleanup result for the HTML current-run summary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Computer,
        [switch] $DisableAndMove
    )

    if ([string] $Computer.ActionAttempted -ne 'True') {
        return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Skipped' }
    }

    $status = [string] $Computer.ActionStatus
    $hasComment = -not [string]::IsNullOrWhiteSpace([string] $Computer.ActionComment)
    $failedStep = ([string] $Computer.DisableActionResult -eq 'False') -or ([string] $Computer.MoveActionResult -eq 'False')

    if ($DisableAndMove -and [string] $Computer.Action -eq 'Disable') {
        $disableResult = [string] $Computer.DisableActionResult
        $moveResult = [string] $Computer.MoveActionResult
        $completedSteps = @(@($disableResult, $moveResult) | Where-Object { $_ -eq 'True' }).Count
        if ($completedSteps -eq 2) {
            if ($hasComment) { return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Completed with issue' } }
            return [pscustomobject] @{ Group = 'Completed'; Label = 'Completed' }
        }
        if ($completedSteps -gt 0) {
            return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Partially completed' }
        }
        if ($failedStep -or $hasComment) {
            $label = if ($status -eq 'WhatIf') { 'WhatIf error' } else { 'Failed' }
            return [pscustomobject] @{ Group = 'NeedsReview'; Label = $label }
        }
        if ($disableResult -eq 'WhatIf' -and $moveResult -eq 'WhatIf') {
            return [pscustomobject] @{ Group = 'WhatIf'; Label = 'WhatIf preview' }
        }
        $label = if ($status -eq 'WhatIf') { 'Incomplete WhatIf' } else { 'Incomplete action' }
        return [pscustomobject] @{ Group = 'NeedsReview'; Label = $label }
    }

    if ($status -eq 'True') {
        if ($failedStep -or $hasComment) { return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Completed with issue' } }
        return [pscustomobject] @{ Group = 'Completed'; Label = 'Completed' }
    }
    if ($status -eq 'WhatIf') {
        if ($failedStep -or $hasComment) { return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'WhatIf error' } }
        return [pscustomobject] @{ Group = 'WhatIf'; Label = 'WhatIf preview' }
    }
    if ($status -eq 'False') {
        return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Failed' }
    }
    [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Unknown result' }
}
