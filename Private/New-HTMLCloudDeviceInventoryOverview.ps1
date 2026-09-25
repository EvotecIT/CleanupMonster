function New-HTMLCloudDeviceInventoryOverview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Statistics,
        [Parameter(Mandatory)]
        [Array] $ActionOverview,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ScopeConfiguration
    )

    $entraRows = @(
        if ($Statistics.Entra) {
            foreach ($row in $Statistics.Entra.Rows) {
                [pscustomobject] @{
                    OS = $row.OS
                    Seen = '{0:N0}' -f $row.Total
                    Enabled = '{0:N0}' -f $row.Enabled
                    Disabled = '{0:N0}' -f $row.Disabled
                    'Enabled state unknown' = '{0:N0}' -f $row.UnknownState
                    'Old over 90 days' = '{0:N0}' -f $row.AgeOver90
                    'Old over 180 days' = '{0:N0}' -f $row.AgeOver180
                    'Activity unknown' = '{0:N0}' -f $row.UnknownActivity
                }
            }
        }
    )
    $intuneRows = @(
        if ($Statistics.Intune) {
            foreach ($row in $Statistics.Intune.Rows) {
                [pscustomobject] @{
                    OS = $row.OS
                    Seen = '{0:N0}' -f $row.Total
                    'Sync old over 90 days' = '{0:N0}' -f $row.AgeOver90
                    'Sync old over 180 days' = '{0:N0}' -f $row.AgeOver180
                    'Sync unknown' = '{0:N0}' -f $row.UnknownActivity
                }
            }
        }
    )
    $scopeRows = @(
        if ($Statistics.Scope) {
            foreach ($row in $Statistics.Scope.Rows) {
                [pscustomobject] @{
                    OS = $row.OS
                    InScope = '{0:N0}' -f $row.Total
                    Enabled = '{0:N0}' -f $row.Enabled
                    Disabled = '{0:N0}' -f $row.Disabled
                    'Enabled state unknown' = '{0:N0}' -f $row.UnknownState
                    'Enabled, Entra old 90d' = '{0:N0}' -f $row.EnabledOver90
                    'Enabled, Entra old 180d' = '{0:N0}' -f $row.EnabledOver180
                    'Entra activity unknown' = '{0:N0}' -f $row.UnknownActivity
                    'No Entra record' = '{0:N0}' -f $row.NoEntraRecord
                }
            }
        }
    )
    $sourceRows = @(
        if ($Statistics.Scope) {
            foreach ($state in ([ordered] @{ Matched = 'Matched Entra and Intune'; EntraOnly = 'Entra only'; IntuneOnly = 'Intune only'; Other = 'Other source' }).GetEnumerator()) {
                [pscustomobject] @{ Category = 'Record source'; State = $state.Value; Records = '{0:N0}' -f $Statistics.Scope.Records.($state.Key) }
            }
            foreach ($state in ([ordered] @{ Healthy = 'Healthy'; Broken = 'Broken'; NotClaimed = 'Not claimed'; IntuneOnly = 'Intune only'; Other = 'Other' }).GetEnumerator()) {
                [pscustomobject] @{ Category = 'Intune link'; State = $state.Value; Records = '{0:N0}' -f $Statistics.Scope.Links.($state.Key) }
            }
        }
    )
    $staleChartRows = @($Statistics.Scope.Rows | Where-Object { $_.OS -ne 'ALL' -and $_.EnabledOver90 -gt 0 })

    New-HTMLTab -Name 'Overview' {
        New-HTMLSection -HeaderText 'At a glance' -Direction column {
            New-HTMLSection -Invisible -Density Compact {
                New-HTMLInfoCard -Title 'Entra seen' -Number ('{0:N0}' -f $Statistics.Entra.Total) -Subtitle 'Before OS filters' -NumberColor '#2878bd' -Style NoIcon
                New-HTMLInfoCard -Title 'Intune seen' -Number ('{0:N0}' -f $Statistics.Intune.Total) -Subtitle 'Before OS filters' -NumberColor '#00a978' -Style NoIcon
                New-HTMLInfoCard -Title 'Cleanup scope' -Number ('{0:N0}' -f $Statistics.Scope.Total) -Subtitle 'After filters' -NumberColor '#e39a22' -Style NoIcon
                New-HTMLInfoCard -Title 'Enabled, old >90d' -Number ('{0:N0}' -f $Statistics.Scope.Rows[0].EnabledOver90) -Subtitle 'Entra activity; context only' -NumberColor '#d56748' -Style NoIcon
            }
            New-HTMLText -Text 'Read-only source counts are before OS filters. Entra and Intune may describe the same device, so their totals must not be added.'
        }

        New-HTMLSection -HeaderText 'Scope and enabled actions' -Direction column {
            New-HTMLText -Text 'Inventory scope used in this run' -FontWeight bold
            New-HTMLList {
                foreach ($setting in $ScopeConfiguration.GetEnumerator()) {
                    New-HTMLListItem -Text "$(($setting.Key)): $($setting.Value)"
                }
            }
            New-HTMLText -Text 'Only enabled action stages are shown below. Age gates are the main thresholds; the Rules tab contains every configured filter.'
            if ($ActionOverview.Count -gt 0) {
                New-HTMLTable -DataTable $ActionOverview -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                    New-HTMLTableHeader -Names 'Action', 'Mode', 'Limit' -ResponsiveOperations all
                    New-HTMLTableHeader -Names 'Age gates' -ResponsiveOperations not-mobile
                    New-HTMLTableHeader -Names 'Notes' -ResponsiveOperations none
                }
            }
        }

        New-HTMLSection -HeaderText 'Enabled with old Entra activity' {
            if ($staleChartRows.Count -gt 0) {
                New-HTMLPanel {
                    New-HTMLChart {
                        New-ChartBarOptions -Distributed
                        New-ChartLegend -HideLegend
                        foreach ($row in $staleChartRows) { New-ChartBar -Name $row.OS -Value $row.EnabledOver90 }
                    } -Title 'In cleanup scope, by OS' -SubTitle 'Entra activity over 90 days; selection rules still apply' -Height 240
                }
            } else {
                New-HTMLText -Text 'No enabled in-scope device has Entra activity older than 90 days.'
            }
        }

        New-HTMLSection -HeaderText 'Detailed inventory counts' -CanCollapse -Collapsed -Direction column {
            if ($entraRows.Count -gt 0) {
                New-HTMLSection -HeaderText 'Entra inventory by OS' -Direction column {
                    New-HTMLText -Text 'Activity age is cumulative: over 180 days is included in over 90 days. These counts alone do not make a device eligible for action.'
                    New-HTMLTable -DataTable $entraRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                        New-HTMLTableHeader -Names 'OS', 'Seen' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'Enabled', 'Disabled', 'Enabled state unknown', 'Old over 90 days', 'Old over 180 days', 'Activity unknown' -ResponsiveOperations not-mobile
                    }
                }
            }
            if ($intuneRows.Count -gt 0) {
                New-HTMLSection -HeaderText 'Intune inventory by OS' -Direction column {
                    New-HTMLText -Text 'Sync age is cumulative. Intune inventory has no Entra enabled state.'
                    New-HTMLTable -DataTable $intuneRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                        New-HTMLTableHeader -Names 'OS', 'Seen' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'Sync old over 90 days', 'Sync old over 180 days', 'Sync unknown' -ResponsiveOperations not-mobile
                    }
                }
            }
            if ($scopeRows.Count -gt 0) {
                New-HTMLSection -HeaderText 'What entered cleanup scope' -Direction column {
                    New-HTMLText -Text 'Correlated records after join type, OS, version and explicit exclusion filters. Enabled with old Entra activity is context; the action rules still apply.'
                    New-HTMLTable -DataTable $scopeRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                        New-HTMLTableHeader -Names 'OS', 'InScope' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'Enabled', 'Disabled', 'Enabled state unknown', 'Enabled, Entra old 90d', 'Enabled, Entra old 180d', 'Entra activity unknown', 'No Entra record' -ResponsiveOperations not-mobile
                    }
                    New-HTMLText -Text 'Source and link state within this scope' -FontWeight bold
                    New-HTMLTable -DataTable $sourceRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                        New-HTMLTableHeader -Names 'Category', 'State', 'Records' -ResponsiveOperations all
                    }
                }
            }
        }

        if ($Statistics.AutopilotScope) {
            $autopilotRows = @(
                if ($Statistics.AutopilotEntra) { [pscustomobject] @{ Source = 'Entra seen'; Records = '{0:N0}' -f $Statistics.AutopilotEntra.Total } }
                if ($Statistics.AutopilotIntune) { [pscustomobject] @{ Source = 'Intune seen'; Records = '{0:N0}' -f $Statistics.AutopilotIntune.Total } }
                [pscustomobject] @{ Source = 'Removal scope'; Records = '{0:N0}' -f $Statistics.AutopilotScope.Total }
            )
            New-HTMLSection -HeaderText 'Separate Autopilot removal query' -Direction column {
                New-HTMLText -Text 'This query has its own scope and can overlap the primary inventory.'
                New-HTMLTable -DataTable $autopilotRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                    New-HTMLTableHeader -Names 'Source', 'Records' -ResponsiveOperations all
                }
            }
        }

    }
}
