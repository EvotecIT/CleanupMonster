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

    $disableResult = [string] $Computer.DisableActionResult
    $moveResult = [string] $Computer.MoveActionResult
    $composite = $DisableAndMove -and [string] $Computer.Action -eq 'Disable'
    if ([string] $Computer.ActionAttempted -ne 'True') {
        if (($composite -and $disableResult -eq 'AlreadySatisfied' -and $moveResult -eq 'AlreadySatisfied') -or
            (-not $composite -and [string] $Computer.Action -eq 'Disable' -and $disableResult -eq 'AlreadySatisfied')) {
            return [pscustomobject] @{ Group = 'Completed'; Label = 'Already satisfied' }
        }
        return [pscustomobject] @{ Group = 'NeedsReview'; Label = 'Skipped' }
    }

    $status = [string] $Computer.ActionStatus
    $hasComment = -not [string]::IsNullOrWhiteSpace([string] $Computer.ActionComment)
    $failedStep = ($disableResult -eq 'False') -or ($moveResult -eq 'False')

    if ($composite) {
        $completedSteps = @(@($disableResult, $moveResult) | Where-Object { $_ -eq 'True' }).Count
        $satisfiedSteps = @(@($disableResult, $moveResult) | Where-Object { $_ -in 'True', 'AlreadySatisfied' }).Count
        $previewSteps = @(@($disableResult, $moveResult) | Where-Object { $_ -in 'WhatIf', 'AlreadySatisfied' }).Count
        if ($satisfiedSteps -eq 2) {
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
        if ($previewSteps -eq 2 -and ($disableResult -eq 'WhatIf' -or $moveResult -eq 'WhatIf')) {
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
