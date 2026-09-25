function Write-ADComputerActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Disable', 'DisableAndMove', 'Move', 'Delete')]
        [string] $Action,
        [Array] $Results = @(),
        [string] $LogPath
    )

    foreach ($computer in $Results) {
        # Only record an action whose AD cmdlet was reached, including WhatIf previews.
        if (-not $computer.ActionAttempted -or [string] $computer.ActionStatus -eq 'ReportOnly') { continue }

        $status = [string] $computer.ActionStatus
        $outcome = if ($status -eq 'WhatIf') { 'WhatIf preview' } elseif ($status -eq 'True') { 'completed' } else { 'failed' }
        $prefix = if ($status -eq 'True') { '[+] ' } elseif ($status -eq 'WhatIf') { '[i] ' } else { '[-] ' }
        $color = if ($status -eq 'True') { 'Green' } elseif ($status -eq 'WhatIf') { 'Cyan' } else { 'Red' }
        if ($status -eq 'WhatIf' -and -not [string]::IsNullOrWhiteSpace([string] $computer.ActionComment)) {
            $outcome = 'WhatIf attempted with error'
            $prefix = '[-] '
            $color = 'Red'
        }
        if ($Action -eq 'DisableAndMove') {
            $disableResult = if ($computer.DisableActionResult) { [string] $computer.DisableActionResult } else { 'NotAttempted' }
            $moveResult = if ($computer.MoveActionResult) { [string] $computer.MoveActionResult } else { 'NotAttempted' }
            $completedSteps = @(@($disableResult, $moveResult) | Where-Object { $_ -eq 'True' }).Count
            if ($completedSteps -eq 2) {
                $outcome = 'completed'
            } elseif ($completedSteps -eq 1) {
                $outcome = 'partially completed'
                $prefix = '[w] '
                $color = 'Yellow'
            } elseif ($disableResult -eq 'False' -or $moveResult -eq 'False') {
                $outcome = if ($disableResult -eq 'WhatIf' -or $moveResult -eq 'WhatIf') { 'WhatIf attempted with error' } else { 'failed' }
                $prefix = '[-] '
                $color = 'Red'
            } elseif ($disableResult -eq 'WhatIf' -and $moveResult -eq 'WhatIf') {
                $outcome = 'WhatIf preview'
                $prefix = '[i] '
                $color = 'Cyan'
            } elseif ($disableResult -eq 'WhatIf' -or $moveResult -eq 'WhatIf') {
                $outcome = 'incomplete WhatIf preview'
                $prefix = '[w] '
                $color = 'Yellow'
            } else {
                $outcome = 'failed'
                $prefix = '[-] '
                $color = 'Red'
            }
        }
        $name = ([string] $computer.SamAccountName) -replace '[\r\n]+', ' '
        $dn = ([string] $computer.DistinguishedName) -replace '[\r\n]+', ' '
        $details = "$Action ${outcome}: Name='$name'; DN='$dn'"
        if ($Action -eq 'DisableAndMove') {
            $details += "; Disable=$disableResult; Move=$moveResult"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $computer.SelectionReason)) {
            $reason = ([string] $computer.SelectionReason) -replace '[\r\n]+', ' '
            $details += "; SelectionReason: $reason"
        }
        if (-not [string]::IsNullOrWhiteSpace([string] $computer.ActionComment)) {
            $comment = ([string] $computer.ActionComment) -replace '[\r\n]+', ' '
            $details += "; $comment"
        }
        Write-Color -Text $prefix, $details -Color Yellow, $color -LogFile $LogPath
    }
}
