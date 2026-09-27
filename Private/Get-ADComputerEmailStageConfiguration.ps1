function Get-ADComputerEmailStageConfiguration {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [bool] $Disable, [bool] $DisableAndMove, [bool] $Move, [bool] $Delete,
        [int] $DisableLimit, [int] $MoveLimit, [int] $DeleteLimit,
        [bool] $ReportOnly, [bool] $Suppressed,
        [bool] $GlobalWhatIf, [bool] $WhatIfDisable, [bool] $WhatIfMove, [bool] $WhatIfDelete
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
            Candidates = $assignedCounts[$stage.Action]
            Limit = $stage.Limit
            Mode = if ($Suppressed) { 'Suppressed' } elseif ($ReportOnly) { 'Report only' } elseif ($GlobalWhatIf -or $stage.Preview) { 'WhatIf' } else { 'Live' }
        }
    }
}
