function Get-ADComputerEmailStageConfiguration {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [bool] $Disable, [bool] $DisableAndMove, [bool] $Move, [bool] $Delete,
        [int] $DisableLimit, [int] $MoveLimit, [int] $DeleteLimit,
        [bool] $ReportOnly, [bool] $Suppressed,
        [System.Collections.IDictionary] $MoveRunStatistics = @{},
        [bool] $WhatIfDisable, [bool] $WhatIfMove, [bool] $WhatIfDelete
    )

    $assignedCounts = @{ Disable = 0; Move = 0; Delete = 0 }
    foreach ($domain in $Report.Keys) {
        foreach ($computer in $Report[$domain]['Computers']) {
            if ($assignedCounts.ContainsKey([string] $computer.Action)) { $assignedCounts[[string] $computer.Action]++ }
        }
    }
    foreach ($stage in @(
            @{ Action = 'Disable'; Name = if ($DisableAndMove) { 'Disable and move' } else { 'Disable' }; Enabled = $Disable -or $DisableAndMove; Limit = $DisableLimit; Preview = $WhatIfDisable }
            @{ Action = 'Move'; Name = 'Move'; Enabled = $Move; Limit = $MoveLimit; Preview = $WhatIfMove }
            @{ Action = 'Delete'; Name = 'Delete'; Enabled = $Delete; Limit = $DeleteLimit; Preview = $WhatIfDelete }
        )) {
        if (-not $stage.Enabled) { continue }
        [pscustomobject] @{
            Action = $stage.Action
            Name = $stage.Name
            LimitStoppedIteration = if ($stage.Action -eq 'Move') { $MoveRunStatistics.LimitStoppedIteration } else { $null }
            AlreadyAtTargetSkipped = if ($stage.Action -eq 'Move') { $MoveRunStatistics.AlreadyAtTargetSkipped } else { 0 }
            Candidates = $assignedCounts[$stage.Action]
            Limit = $stage.Limit
            Mode = if ($Suppressed) { 'Suppressed' } elseif ($ReportOnly) { 'Report only' } elseif ($stage.Preview) { 'WhatIf' } else { 'Live' }
        }
    }
}
