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
    $renderRows = [System.Collections.Generic.List[object]]::new()
    $allColumns = [System.Collections.Generic.List[string]]::new()
    $seenColumns = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Computer in $Actions) {
        $Action = [string] $Computer.Action
        if ($ActionCounts.Contains($Action)) { $ActionCounts[$Action]++ }
        if ([string] $Computer.ActionAttempted -eq 'True') { $AttemptedCount++ }
        $Outcome = Get-ADComputerReportOutcome -Computer $Computer -DisableAndMove:$DisableAndMove.IsPresent
        $ResultCounts[$Outcome.Group]++
        $renderRow = $Computer | Select-Object -Property *
        Add-Member -InputObject $renderRow -MemberType NoteProperty -Name 'Result' -Value $Outcome.Label
        $renderRows.Add($renderRow)
        foreach ($property in $renderRow.PSObject.Properties) {
            if ($seenColumns.Add($property.Name)) { $allColumns.Add($property.Name) }
        }
    }

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

    $primaryColumns = @('SamAccountName', 'Action', 'Result', 'LastLogonDays' | Where-Object { $allColumns -contains $_ })
    $secondaryColumns = @('DNSHostName', 'OperatingSystem' | Where-Object { $allColumns -contains $_ })
    $detailColumns = @($allColumns | Where-Object { $_ -notin ($primaryColumns + $secondaryColumns) })
    New-HTMLSection -HeaderText 'Actions this run' -Direction column {
        New-HTMLText -Text 'One row per selected computer. Expand a row for the complete selection reason, action notes, and remaining audit fields.'
        New-HTMLTable -DataTable $renderRows.ToArray() -AllProperties -Filtering -PagingLength 25 {
            if ($primaryColumns.Count) { New-HTMLTableHeader -Names $primaryColumns -ResponsiveOperations all }
            if ($secondaryColumns.Count) { New-HTMLTableHeader -Names $secondaryColumns -ResponsiveOperations not-mobile }
            if ($detailColumns.Count) { New-HTMLTableHeader -Names $detailColumns -ResponsiveOperations none }
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Move' -BackgroundColor Yellow
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
            New-HTMLTableCondition -Name 'Result' -ComparisonType string -Value 'Completed' -BackgroundColor LightGreen
            New-HTMLTableCondition -Name 'Result' -ComparisonType string -Value 'WhatIf preview' -BackgroundColor LightBlue
            foreach ($reviewResult in @('Skipped', 'Completed with issue', 'Partially completed', 'Failed', 'WhatIf error', 'Incomplete WhatIf', 'Incomplete action', 'Unknown result')) {
                New-HTMLTableCondition -Name 'Result' -ComparisonType string -Value $reviewResult -BackgroundColor Salmon
            }
            New-HTMLTableCondition -Name 'ProtectedFromAccidentalDeletion' -ComparisonType string -Value $false -BackgroundColor LightBlue -FailBackgroundColor Salmon
        } -WarningAction SilentlyContinue
    }
}
