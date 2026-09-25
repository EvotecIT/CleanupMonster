function New-HTMLCloudDeviceInventoryOverview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Statistics
    )

    $entraRows = @(
        if ($Statistics.Entra) {
            foreach ($row in $Statistics.Entra.Rows) {
                [pscustomobject] @{
                    OS = $row.OS
                    Seen = '{0:N0}' -f $row.Total
                    Enabled = '{0:N0}' -f $row.Enabled
                    Disabled = '{0:N0}' -f $row.Disabled
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
            [pscustomobject] @{ State = 'Matched Entra and Intune'; Records = '{0:N0}' -f $Statistics.Scope.Records.Matched }
            [pscustomobject] @{ State = 'Entra only'; Records = '{0:N0}' -f $Statistics.Scope.Records.EntraOnly }
            [pscustomobject] @{ State = 'Intune only'; Records = '{0:N0}' -f $Statistics.Scope.Records.IntuneOnly }
            [pscustomobject] @{ State = 'Broken Intune link'; Records = '{0:N0}' -f $Statistics.Scope.Links.Broken }
        }
    )
    $candidateTotals = @(
        if ($Statistics.CandidateTotals) {
            foreach ($candidate in $Statistics.CandidateTotals.GetEnumerator()) {
                [pscustomobject] @{ Action = [string] $candidate.Key; Selected = '{0:N0}' -f $candidate.Value }
            }
        }
    )
    $candidateRows = @(
        if ($Statistics.Candidates) {
            foreach ($candidate in $Statistics.Candidates) {
                foreach ($row in $candidate.Rows) {
                    if ($row.OS -eq 'ALL') { continue }
                    [pscustomobject] @{
                        Action = $candidate.Label -replace ' candidates.*$', ''
                        OS = $row.OS
                        Selected = '{0:N0}' -f $row.Total
                    }
                }
            }
        }
    )

    New-HTMLTab -Name 'Overview' {
        New-HTMLSection -HeaderText 'What the job saw' -Direction column {
            New-HTMLText -Text 'Read-only source counts are before OS filters. Entra and Intune may describe the same device, so their totals must not be added.'
            $seenRows = @(
                if ($Statistics.Entra) { [pscustomobject] @{ Stage = 'Entra seen'; Records = '{0:N0}' -f $Statistics.Entra.Total } }
                if ($Statistics.Intune) { [pscustomobject] @{ Stage = 'Intune seen'; Records = '{0:N0}' -f $Statistics.Intune.Total } }
                if ($Statistics.Scope) { [pscustomobject] @{ Stage = 'In cleanup scope'; Records = '{0:N0}' -f $Statistics.Scope.Total } }
            )
            New-HTMLTable -DataTable $seenRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                New-HTMLTableHeader -Names 'Stage', 'Records' -ResponsiveOperations all
            }
        }

        if ($entraRows.Count -gt 0) {
            New-HTMLSection -HeaderText 'Entra inventory by OS' -Direction column {
                New-HTMLText -Text 'Activity age is cumulative: over 180 days is included in over 90 days. These counts alone do not make a device eligible for action.'
                New-HTMLTable -DataTable $entraRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                    New-HTMLTableHeader -Names 'OS', 'Seen' -ResponsiveOperations all
                    New-HTMLTableHeader -Names 'Enabled', 'Disabled', 'Old over 90 days', 'Old over 180 days', 'Activity unknown' -ResponsiveOperations not-mobile
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
                    New-HTMLTableHeader -Names 'Enabled', 'Disabled', 'Enabled, Entra old 90d', 'Enabled, Entra old 180d', 'Entra activity unknown', 'No Entra record' -ResponsiveOperations not-mobile
                }
                New-HTMLText -Text 'Source and link state within this scope' -FontWeight bold
                New-HTMLTable -DataTable $sourceRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                    New-HTMLTableHeader -Names 'State', 'Records' -ResponsiveOperations all
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

        New-HTMLSection -HeaderText 'What the rules selected' -Direction column {
            New-HTMLText -Text 'Selected counts are before action limits or confirmation. The Current Run tab shows attempted actions and WhatIf previews.'
            if ($candidateTotals.Count -gt 0) {
                New-HTMLTable -DataTable $candidateTotals -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                    New-HTMLTableHeader -Names 'Action', 'Selected' -ResponsiveOperations all
                }
            } else {
                New-HTMLText -Text 'No cleanup action was selected for this run.'
            }
            if ($candidateRows.Count -gt 0) {
                New-HTMLText -Text 'Selected devices by action and OS' -FontWeight bold
                New-HTMLTable -DataTable $candidateRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering {
                    New-HTMLTableHeader -Names 'Action', 'OS', 'Selected' -ResponsiveOperations all
                }
            }
        }
    }
}
