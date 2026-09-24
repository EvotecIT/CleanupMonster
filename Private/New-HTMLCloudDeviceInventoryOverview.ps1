function New-HTMLCloudDeviceInventoryOverview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Statistics
    )

    $candidateTotals = @(
        if ($Statistics.CandidateTotals) {
            foreach ($candidate in $Statistics.CandidateTotals.GetEnumerator()) {
                [pscustomobject] @{ Action = $candidate.Key; Selected = $candidate.Value }
            }
        }
    )
    $candidateRows = @(
        if ($Statistics.Candidates) {
            foreach ($candidate in $Statistics.Candidates) {
                foreach ($row in $candidate.Rows) {
                    if ($row.OS -eq 'ALL') { continue }
                    $action = $candidate.Label -replace ' candidates.*$', ''
                    [pscustomobject] @{ Action = $action; OS = $row.OS; Selected = $row.Total; Enabled = $row.Enabled; Disabled = $row.Disabled; Unknown = $row.UnknownState }
                }
            }
        }
    )

    New-HTMLTab -Name 'Inventory Overview' {
        New-HTMLSection -HeaderText 'What the job saw' {
            New-HTMLText -Text 'Primary cleanup query counts are before OS filters. Entra and Intune records can overlap; do not add their totals. Queries still use the configured join types.'
        }
        if ($Statistics.Entra) {
            New-HTMLSection -Invisible {
                New-HTMLPanel { New-HTMLToast -TextHeader 'Primary Entra seen' -Text "Records: $($Statistics.Entra.Total)" -BarColorLeft CornflowerBlue -IconSolid info-circle -IconColor CornflowerBlue } -Invisible
            }
        }
        if ($Statistics.Intune) {
            New-HTMLSection -Invisible {
                New-HTMLPanel { New-HTMLToast -TextHeader 'Primary Intune seen' -Text "Records: $($Statistics.Intune.Total)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel } -Invisible
            }
        }
        if ($Statistics.Scope) {
            New-HTMLSection -Invisible {
                New-HTMLPanel { New-HTMLToast -TextHeader 'Cleanup scope' -Text "Correlated records after filters: $($Statistics.Scope.Total)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen } -Invisible
            }
        }

        if ($Statistics.Entra) {
            New-HTMLSection -HeaderText 'Primary Entra seen before OS filters' {
                New-HTMLText -Text 'Age is days since Entra activity. Older than 90 and 180 days are cumulative. These counts alone do not decide action eligibility.'
            }
            if ($Statistics.Entra.Total -gt 0) {
                New-HTMLSection -Invisible {
                    New-HTMLPanel {
                        New-HTMLChart {
                            foreach ($row in $Statistics.Entra.Rows) {
                                if ($row.OS -ne 'ALL' -and $row.Total -gt 0) { New-ChartPie -Name $row.OS -Value $row.Total }
                            }
                        } -Title 'Entra records by OS'
                    }
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Enabled state by OS' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.Entra.Rows | Select-Object OS, Total, Enabled, Disabled, @{Name = 'Unknown'; Expression = { $_.UnknownState } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Old Entra activity by OS' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.Entra.Rows | Select-Object OS, @{Name = 'Over90'; Expression = { $_.AgeOver90 } }, @{Name = 'Over180'; Expression = { $_.AgeOver180 } }, @{Name = 'Unknown'; Expression = { $_.UnknownActivity } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Enabled with old Entra activity by OS' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.Entra.Rows | Select-Object OS, @{Name = 'OnOver90'; Expression = { $_.EnabledOver90 } }, @{Name = 'OnOver180'; Expression = { $_.EnabledOver180 } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
        }

        if ($Statistics.Intune) {
            New-HTMLSection -HeaderText 'Primary Intune seen before OS filters' {
                New-HTMLText -Text 'Age is days since last Intune sync. The age bands do not overlap. Intune records have no Entra enabled state.'
            }
            if ($Statistics.Intune.Total -gt 0) {
                New-HTMLSection -Invisible {
                    New-HTMLPanel {
                        New-HTMLChart {
                            foreach ($row in $Statistics.Intune.Rows) {
                                if ($row.OS -ne 'ALL' -and $row.Total -gt 0) { New-ChartPie -Name $row.OS -Value $row.Total }
                            }
                        } -Title 'Intune records by OS'
                    }
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLTable -DataTable @($Statistics.Intune.Rows | Select-Object OS, @{Name = 'UpTo90'; Expression = { $_.AgeWithin90 } }, @{Name = 'Days91To180'; Expression = { $_.Age91To180 } }, @{Name = 'Over180'; Expression = { $_.AgeOver180 } }, @{Name = 'Unknown'; Expression = { $_.UnknownActivity } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
        }

        if ($Statistics.Scope) {
            New-HTMLSection -HeaderText 'Cleanup scope after filters' {
                New-HTMLText -Text 'Correlated records passed the configured join, OS, version, and explicit exclusion filters. Primary cleanup actions select candidates from this pool. A separate Autopilot removal query, when configured, has its own source and scope below.'
            }
            if ($Statistics.Scope.Total -gt 0) {
                New-HTMLSection -Invisible {
                    New-HTMLPanel {
                        New-HTMLChart {
                            foreach ($row in $Statistics.Scope.Rows) {
                                if ($row.OS -ne 'ALL' -and $row.Total -gt 0) { New-ChartPie -Name $row.OS -Value $row.Total }
                            }
                        } -Title 'Cleanup scope by OS'
                    }
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Enabled state by OS' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.Scope.Rows | Select-Object OS, Total, Enabled, Disabled, @{Name = 'Unknown'; Expression = { $_.UnknownState } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Old Entra activity by OS' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.Scope.Rows | Select-Object OS, @{Name = 'Over90'; Expression = { $_.AgeOver90 } }, @{Name = 'Over180'; Expression = { $_.AgeOver180 } }, @{Name = 'Unknown'; Expression = { $_.UnknownActivity } }, @{Name = 'NoEntra'; Expression = { $_.NoEntraRecord } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Enabled with old Entra activity by OS' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.Scope.Rows | Select-Object OS, @{Name = 'OnOver90'; Expression = { $_.EnabledOver90 } }, @{Name = 'OnOver180'; Expression = { $_.EnabledOver180 } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Record source within cleanup scope' -FontWeight bold
                    New-HTMLTable -DataTable @(
                        [pscustomobject] @{ State = 'Matched'; Count = $Statistics.Scope.Records.Matched }
                        [pscustomobject] @{ State = 'Entra only'; Count = $Statistics.Scope.Records.EntraOnly }
                        [pscustomobject] @{ State = 'Intune only'; Count = $Statistics.Scope.Records.IntuneOnly }
                        [pscustomobject] @{ State = 'Other'; Count = $Statistics.Scope.Records.Other }
                    ) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Intune link within cleanup scope' -FontWeight bold
                    New-HTMLTable -DataTable @(
                        [pscustomobject] @{ State = 'Healthy'; Count = $Statistics.Scope.Links.Healthy }
                        [pscustomobject] @{ State = 'Broken'; Count = $Statistics.Scope.Links.Broken }
                        [pscustomobject] @{ State = 'Not claimed'; Count = $Statistics.Scope.Links.NotClaimed }
                        [pscustomobject] @{ State = 'Intune only'; Count = $Statistics.Scope.Links.IntuneOnly }
                        [pscustomobject] @{ State = 'Other'; Count = $Statistics.Scope.Links.Other }
                    ) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
        }

        if ($Statistics.AutopilotScope) {
            New-HTMLSection -HeaderText 'Separate Autopilot removal scope' {
                New-HTMLText -Text 'Autopilot removal candidates come from this separate query and scope. Source counts below are before OS filters and can overlap the primary query; do not add them together.'
            }
            if ($Statistics.AutopilotEntra) {
                New-HTMLSection -Invisible {
                    New-HTMLPanel {
                        New-HTMLText -Text "Autopilot Entra seen: $($Statistics.AutopilotEntra.Total) records" -FontWeight bold
                        New-HTMLTable -DataTable @($Statistics.AutopilotEntra.Rows | Select-Object OS, Total, Enabled, Disabled) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                    }
                }
            }
            if ($Statistics.AutopilotIntune) {
                New-HTMLSection -Invisible {
                    New-HTMLPanel {
                        New-HTMLText -Text "Autopilot Intune seen: $($Statistics.AutopilotIntune.Total) records" -FontWeight bold
                        New-HTMLTable -DataTable @($Statistics.AutopilotIntune.Rows | Select-Object OS, Total, @{Name = 'UpTo90'; Expression = { $_.AgeWithin90 } }, @{Name = 'Over180'; Expression = { $_.AgeOver180 } }) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                    }
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Autopilot removal scope after filters' -FontWeight bold
                    New-HTMLTable -DataTable @($Statistics.AutopilotScope.Rows | Select-Object OS, Total, Enabled, Disabled) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Autopilot scope record source' -FontWeight bold
                    New-HTMLTable -DataTable @(
                        [pscustomobject] @{ State = 'Matched'; Count = $Statistics.AutopilotScope.Records.Matched }
                        [pscustomobject] @{ State = 'Entra only'; Count = $Statistics.AutopilotScope.Records.EntraOnly }
                        [pscustomobject] @{ State = 'Intune only'; Count = $Statistics.AutopilotScope.Records.IntuneOnly }
                        [pscustomobject] @{ State = 'Other'; Count = $Statistics.AutopilotScope.Records.Other }
                    ) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    New-HTMLText -Text 'Autopilot scope Intune link' -FontWeight bold
                    New-HTMLTable -DataTable @(
                        [pscustomobject] @{ State = 'Healthy'; Count = $Statistics.AutopilotScope.Links.Healthy }
                        [pscustomobject] @{ State = 'Broken'; Count = $Statistics.AutopilotScope.Links.Broken }
                        [pscustomobject] @{ State = 'Not claimed'; Count = $Statistics.AutopilotScope.Links.NotClaimed }
                        [pscustomobject] @{ State = 'Intune only'; Count = $Statistics.AutopilotScope.Links.IntuneOnly }
                        [pscustomobject] @{ State = 'Other'; Count = $Statistics.AutopilotScope.Links.Other }
                    ) -HideButtons -DisableSearch -DisablePaging -DisableInfo
                }
            }
        }

        New-HTMLSection -HeaderText 'Selected by action rules' {
            New-HTMLText -Text 'Candidate counts are before action limits and confirmation. Current Run shows actual attempts and WhatIf outcomes.'
        }
        if ($candidateTotals.Count -gt 0) {
            New-HTMLSection -Invisible {
                New-HTMLPanel { New-HTMLTable -DataTable $candidateTotals -HideButtons -DisableSearch -DisablePaging -DisableInfo }
            }
        }
        if ($candidateRows.Count -gt 0) {
            New-HTMLSection -Invisible {
                New-HTMLPanel { New-HTMLTable -DataTable $candidateRows -HideButtons -DisableSearch -DisablePaging -DisableInfo }
            }
        }
    }
}
