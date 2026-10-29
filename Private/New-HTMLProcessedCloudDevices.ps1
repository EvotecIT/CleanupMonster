function New-HTMLProcessedCloudDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Export,
        [Parameter(Mandatory)] [Array] $Devices,
        [int] $PrimaryDeviceCount = -1,
        [Array] $CandidateDevices = @(),
        [System.Collections.IDictionary] $Statistics,
        [Parameter(Mandatory)] [Array] $ActionConfiguration,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $ScopeConfiguration,
        [Parameter(Mandatory)] [string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile
    )

    $currentRows = @($Export.CurrentRun | ForEach-Object { ConvertTo-CloudDeviceActionReportRow -Record $_ })
    $historyRows = @($Export.History | ForEach-Object { ConvertTo-CloudDeviceActionReportRow -Record $_ })
    $pendingRows = @($Export.PendingActions.Values | ForEach-Object { ConvertTo-CloudDeviceActionReportRow -Record $_ -Pending })
    $primaryCount = if ($PrimaryDeviceCount -ge 0) { $PrimaryDeviceCount } else { $Devices.Count }
    $reviewSelection = @(Get-CloudDeviceReportSelection -Devices $Devices -Export $Export -CandidateDevices $CandidateDevices)
    $deviceRows = @(
        foreach ($selected in $reviewSelection) {
            $scope = if ($selected.Index -lt $primaryCount) { 'Primary cleanup' } else { 'Autopilot removal only' }
            ConvertTo-CloudDeviceReportRow -Device $selected.Device -Scope $scope -CurrentActions $selected.CurrentActions -PendingAction $selected.PendingAction -Candidates $selected.Candidates
        }
    )
    $enabledActions = @($ActionConfiguration | Where-Object { $_.Enabled })
    $ageRuleNames = [ordered] @{
        LastSeenEntraMoreThan = 'Entra activity'
        LastSeenIntuneMoreThan = 'Intune sync'
        IntuneStaleWhenPresentMoreThan = 'Matching Intune sync'
        RegisteredMoreThan = 'Registration'
        ListProcessedMoreThan = 'Pending'
        AutopilotLastContactMoreThan = 'Autopilot contact'
    }
    $actionOverview = @(
        foreach ($action in $enabledActions) {
            $ageGates = @(
                foreach ($ruleName in $ageRuleNames.Keys) {
                    if ($action.Rules.Contains($ruleName) -and $null -ne $action.Rules[$ruleName]) {
                        if ($ruleName -eq 'ListProcessedMoreThan') {
                            'Pending at least {0} days' -f $action.Rules[$ruleName]
                        } else {
                            '{0} >{1} days' -f $ageRuleNames[$ruleName], $action.Rules[$ruleName]
                        }
                    }
                }
            )
            [pscustomobject] [ordered] @{
                Action = $action.Name
                Mode = $action.Mode
                Limit = if ($action.Limit -eq 0) { 'Unlimited' } else { [string] $action.Limit }
                'Age gates' = if ($ageGates.Count) { $ageGates -join '; ' } else { 'See full rules' }
                Notes = [string] $action.Additional
            }
        }
    )
    $ruleRows = @(
        foreach ($action in $enabledActions) {
            foreach ($rule in $action.Rules.GetEnumerator()) {
                $value = if ($null -eq $rule.Value) { 'Not set' } elseif ($rule.Value -is [Array]) { $rule.Value -join ', ' } else { [string] $rule.Value }
                [pscustomobject] @{ Action = [string] $action.Name; Rule = [string] $rule.Key; Value = $value }
            }
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
                    [pscustomobject] @{ Action = $candidate.Label -replace ' candidates.*$', ''; OS = $row.OS; Selected = '{0:N0}' -f $row.Total }
                }
            }
        }
    )
    $previewCount = @($Export.CurrentRun | Where-Object { $_.ActionStatus -eq 'WhatIf' }).Count
    $reportOnlyCount = @($Export.CurrentRun | Where-Object { $_.ActionStatus -eq 'ReportOnly' }).Count
    $completedCount = @($Export.CurrentRun | Where-Object { [string] $_.ActionStatus -eq 'True' }).Count
    $failedCount = @($Export.CurrentRun | Where-Object { [string] $_.ActionStatus -eq 'False' }).Count

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey -BackgroundColor BlizzardBlue
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin
        Add-HTMLStyle -Placement Header -Content @'
table.dataTable > tbody > tr.child ul.dtr-details { display: block; width: 100%; columns: 26rem; column-gap: 2rem; }
table.dataTable > tbody > tr.child ul.dtr-details > li { break-inside: avoid; overflow-wrap: anywhere; }
table.dataTable > tbody > tr.child .dtr-title { margin-right: 0.5rem; }
'@

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection { New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue } -JustifyContent flex-start -Invisible
                New-HTMLSection { New-HTMLText -Text "Cleanup Monster - $($Export.Version)" -Color Blue } -JustifyContent flex-end -Invisible
            }
        }

        if ($Statistics) { New-HTMLCloudDeviceInventoryOverview -Statistics $Statistics -ActionOverview $actionOverview -ScopeConfiguration $ScopeConfiguration }

        New-HTMLTab -Name 'Current Run' {
            New-HTMLSection -HeaderText 'Selected by rules this run' -Direction column {
                New-HTMLText -Text 'These counts are before action limits or confirmation. The action table below shows what the job attempted or previewed.'
                if ($candidateTotals.Count -gt 0) {
                    New-HTMLTable -DataTable $candidateTotals -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering
                } else {
                    New-HTMLText -Text 'No cleanup action was selected for this run.'
                }
                if ($candidateRows.Count -gt 0) {
                    New-HTMLSection -HeaderText 'Selected by OS' -CanCollapse {
                        New-HTMLTable -DataTable $candidateRows -HideButtons -HideFooter -DisableSearch -DisablePaging -DisableInfo -DisableOrdering
                    }
                }
            }
            New-HTMLSection -HeaderText 'Actions attempted this run' -Direction column {
                New-HTMLText -Text "$previewCount WhatIf preview(s), $reportOnlyCount report-only result(s), $completedCount completed, $failedCount failed. WhatIf previews enter History but never start pending actions."
                if ($currentRows.Count -gt 0) {
                    New-HTMLTable -DataTable $currentRows -HideButtons -HideFooter -PagingLength 25 -TextWhenNoData 'No actions in this run.' {
                        New-HTMLTableHeader -Names 'Device', 'Action', 'Outcome' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'When', 'Why selected', 'Result' -ResponsiveOperations not-mobile
                        New-HTMLTableHeader -Names @($currentRows[0].PSObject.Properties.Name | Where-Object { $_ -notin @('Device', 'Action', 'Outcome', 'When', 'Why selected', 'Result') }) -ResponsiveOperations none
                    }
                } else {
                    New-HTMLText -Text 'No actions were attempted in this run.'
                }
            }
        }

        New-HTMLTab -Name 'History' {
            New-HTMLSection -HeaderText 'Action history' -Direction column {
                New-HTMLText -Text 'Completed, failed, and WhatIf attempts are retained across runs. A WhatIf entry is a preview, not a completed change. Report-only results are not retained. Expanded details show the saved action-time evidence; missing facts in older snapshots are Not captured.'
                if ($historyRows.Count -gt 0) {
                    New-HTMLTable -DataTable $historyRows -HideButtons -HideFooter -PagingLength 25 -TextWhenNoData 'No history recorded.' {
                        New-HTMLTableHeader -Names 'Device', 'Action', 'Outcome' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'When', 'Why selected', 'Result' -ResponsiveOperations not-mobile
                        New-HTMLTableHeader -Names @($historyRows[0].PSObject.Properties.Name | Where-Object { $_ -notin @('Device', 'Action', 'Outcome', 'When', 'Why selected', 'Result') }) -ResponsiveOperations none
                    }
                } else {
                    New-HTMLText -Text 'No action history has been recorded yet.'
                }
            }
        }

        New-HTMLTab -Name 'Pending Actions' {
            New-HTMLSection -HeaderText 'Waiting for the next stage' -Direction column {
                New-HTMLText -Text 'These are saved action-time snapshots awaiting a later stage, not current inventory values. Only completed actions enter this list. WhatIf previews never start a pending period. Current rules and activity are checked again before the next action.'
                if ($pendingRows.Count -gt 0) {
                    New-HTMLTable -DataTable $pendingRows -HideButtons -HideFooter -PagingLength 25 {
                        New-HTMLTableHeader -Names 'Device', 'Action', 'Days pending' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'When', 'Why selected', 'Result' -ResponsiveOperations not-mobile
                        New-HTMLTableHeader -Names @($pendingRows[0].PSObject.Properties.Name | Where-Object { $_ -notin @('Device', 'Action', 'Days pending', 'When', 'Why selected', 'Result') }) -ResponsiveOperations none
                    }
                } else {
                    New-HTMLText -Text 'No devices are pending a later action.'
                }
            }
        }

        New-HTMLTab -Name 'Devices' {
            New-HTMLSection -HeaderText 'Devices returned for reporting' -Direction column {
                New-HTMLText -Text ('All {0:N0} inventory records are included and searchable. Expand a row for decision context and target IDs. Selected actions and reasons cover rule candidates before action limits; recorded actions show attempts made this run.' -f $deviceRows.Count)
                New-HTMLText -Text 'This is current inventory, not a deletion approval. A blank action field means no matching record for that stage, not safe to delete. Check Rules, matching and duplicate protection, and the action-time evidence in Current Run, History or Pending Actions. A separate Autopilot removal query can add rows marked Autopilot removal only. Full normalized action snapshots remain in the XML datastore; this standalone HTML contains focused investigation fields.'
                if ($deviceRows.Count -gt 0) {
                    New-HTMLTable -DataTable $deviceRows -DataTableID 'cloud-device-inventory' -DisableStateSave -HideButtons -HideFooter -PagingLength 25 {
                        New-HTMLTableHeader -Names 'Device', 'Scope', 'OS', 'Enabled' -ResponsiveOperations all
                        $detailColumns = @($deviceRows[0].PSObject.Properties.Name | Where-Object { $_ -notin @('Device', 'Scope', 'OS', 'Enabled', 'Source', 'Entra age (days)', 'Intune age (days)', 'Registration age (days)', 'Intune link', 'Recorded actions this run') })
                        New-HTMLTableHeader -Names $detailColumns -ResponsiveOperations none
                    }
                } else {
                    New-HTMLText -Text 'No devices entered cleanup scope.'
                }
            }
        }

        New-HTMLTab -Name 'Rules' {
            New-HTMLSection -HeaderText 'Enabled action rules' -Direction column {
                New-HTMLText -Text 'Only enabled action stages appear here. These are the complete selection settings used in this run.'
                New-HTMLTable -DataTable $ruleRows -HideButtons -HideFooter -PagingLength 25 -ResponsivePriorityOrder 'Action', 'Rule', 'Value'
            }
        }

        try {
            if ($LogFile -and (Test-Path -LiteralPath $LogFile -ErrorAction Stop)) {
                $logContent = Get-Content -Raw -LiteralPath $LogFile -ErrorAction Stop
                New-HTMLTab -Name 'Log' { New-HTMLCodeBlock -Code $logContent -Style generic }
            }
        } catch {
            Write-Color -Text '[e] ', "Couldn't read the log file. Skipping adding log to HTML. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    } -FilePath $FilePath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent
}
