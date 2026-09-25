function New-HTMLADComputerCurrentRun {
    <#
    .SYNOPSIS
    Shows a compact current-run summary while retaining the full AD action audit.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [Array] $Actions,
        [switch] $DisableAndMove
    )

    $ActionCounts = [ordered] @{ Disable = 0; Move = 0; Delete = 0 }
    $ResultCounts = [ordered] @{ Completed = 0; WhatIf = 0; NeedsReview = 0 }
    $AttemptedCount = 0
    [Array] $QuickActions = @(
        foreach ($Computer in $Actions) {
            $Action = [string] $Computer.Action
            if ($ActionCounts.Contains($Action)) { $ActionCounts[$Action]++ }
            if ([string] $Computer.ActionAttempted -eq 'True') { $AttemptedCount++ }
            $Outcome = Get-ADComputerReportOutcome -Computer $Computer -DisableAndMove:$DisableAndMove.IsPresent
            $ResultCounts[$Outcome.Group]++

            $Reason = [string] $Computer.SelectionReason
            if ($Reason.Length -gt 80) { $Reason = $Reason.Substring(0, 77) + '...' }
            [pscustomobject] @{
                Computer      = if ($Computer.DNSHostName) { $Computer.DNSHostName } else { $Computer.SamAccountName }
                Action        = $Action
                Result        = $Outcome.Label
                'Logon days'  = if ($null -ne $Computer.LastLogonDays) { $Computer.LastLogonDays } else { 'Unknown' }
                OS            = $Computer.OperatingSystem
                'Why preview' = $Reason
            }
        }
    )

    New-HTMLSection -HeaderText 'Current run at a glance' -Direction column {
        New-HTMLSection -Invisible -Density Compact {
            New-HTMLInfoCard -Title 'Selected this run' -Number ('{0:N0}' -f $Actions.Count) -Subtitle "$AttemptedCount reached an AD call" -NumberColor '#2878bd' -Style NoIcon
            New-HTMLInfoCard -Title 'Completed' -Number ('{0:N0}' -f $ResultCounts.Completed) -Subtitle 'AD actions completed' -NumberColor '#00a978' -Style NoIcon
            New-HTMLInfoCard -Title 'WhatIf previews' -Number ('{0:N0}' -f $ResultCounts.WhatIf) -Subtitle 'AD calls previewed' -NumberColor '#e39a22' -Style NoIcon
            New-HTMLInfoCard -Title 'Needs review' -Number ('{0:N0}' -f $ResultCounts.NeedsReview) -Subtitle 'Skipped, partial or errored' -NumberColor '#d56748' -Style NoIcon
        }
    }

    if ($Actions.Count -eq 0) {
        New-HTMLText -Text 'No computer actions were attempted in this run.'
        return
    }

    New-HTMLSection -HeaderText 'Actions by type' {
        New-HTMLPanel {
            New-HTMLChart {
                New-ChartBarOptions -Distributed
                New-ChartLegend -HideLegend
                foreach ($Action in $ActionCounts.Keys) {
                    if ($ActionCounts[$Action] -gt 0) { New-ChartBar -Name $Action -Value $ActionCounts[$Action] }
                }
            } -Title 'Selected by action' -SubTitle 'Includes WhatIf and skipped rows' -Height 210
        }
    }

    New-HTMLSection -HeaderText 'Quick view' -Direction column {
        New-HTMLText -Text 'The reason column is abbreviated. Expand full action details for every field and the complete selection reason.'
        New-HTMLTable -DataTable $QuickActions -HideButtons {
            New-HTMLTableHeader -Names 'Computer', 'Action', 'Result', 'Logon days' -ResponsiveOperations all
            New-HTMLTableHeader -Names 'OS', 'Why preview' -ResponsiveOperations not-mobile
        }
    }

    New-HTMLSection -HeaderText 'Full action details' -CanCollapse -Collapsed {
        New-HTMLTable -DataTable $Actions -Filtering -ScrollX {
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Move' -BackgroundColor Yellow
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
            New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
            New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
            New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
            New-HTMLTableCondition -Name 'ProtectedFromAccidentalDeletion' -ComparisonType string -Value $false -BackgroundColor LightBlue -FailBackgroundColor Salmon
        } -WarningAction SilentlyContinue
    }
}
