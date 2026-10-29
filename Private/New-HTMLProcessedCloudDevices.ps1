function New-HTMLProcessedCloudDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Export,
        [Parameter(Mandatory)] [Array] $Devices,
        [int] $PrimaryDeviceCount = -1,
        [ValidateRange(1, 2147483647)] [int] $ReportDeviceLimit = 500,
        [Array] $CandidateDevices = @(),
        [System.Collections.IDictionary] $Statistics,
        [Parameter(Mandatory)] [Array] $ActionConfiguration,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $ScopeConfiguration,
        [Parameter(Mandatory)] [string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile
    )

    $actionRows = {
        param([Array] $Records)
        foreach ($record in $Records) {
            $audit = Get-CloudDeviceAuditContext -Device $record
            $outcome = switch ([string] $record.ActionStatus) {
                'True' { 'Completed' }
                'False' { 'Failed' }
                'WhatIf' { 'WhatIf preview' }
                'ReportOnly' { 'Report only' }
                default { [string] $record.ActionStatus }
            }
            $action = switch ([string] $record.Action) {
                'StageDelete' { 'Stage for deletion' }
                'RemoveAutopilotIdentity' { 'Remove Autopilot identity' }
                default { [string] $record.Action }
            }
            [pscustomobject] @{
                Device = $record.Name
                Action = $action
                Outcome = $outcome
                When = if ($record.ActionDate) { ([datetime] $record.ActionDate).ToString('yyyy-MM-dd HH:mm') } else { '' }
                'Why selected' = $record.SelectionReason
                Result = $record.ActionNotes
                OS = $record.OperatingSystem
                'Entra age (days)' = $record.EntraLastSeenDays
                'Intune age (days)' = $record.IntuneLastSeenDays
                'Entra object ID' = $record.EntraDeviceObjectId
                'Intune device ID' = $record.ManagedDeviceId
                'Autopilot identity ID' = $record.AutopilotDeviceId
                'Autopilot serial' = $record.AutopilotSerialNumber
                'Autopilot resource' = $record.AutopilotResourceName
                'Registered owner' = $audit.RegisteredOwner
                'Owner UPN' = $audit.RegisteredOwnerUPN
                'Intune user UPN' = $audit.IntuneUserUPN
                'Entra compliant' = $audit.EntraCompliant
                'Intune compliance' = $audit.IntuneCompliance
                'Entra managed' = $audit.EntraManaged
                'Entra management type' = $audit.EntraManagementType
                'MDM app ID' = $audit.MdmAppId
                'Intune management agent' = $audit.IntuneManagementAgent
            }
        }
    }
    $currentRows = @(& $actionRows -Records @($Export.CurrentRun))
    $historyRows = @(& $actionRows -Records @($Export.History))
    $pendingRows = @(
        foreach ($device in $Export.PendingActions.Values) {
            [pscustomobject] @{
                Device = $device.Name
                Action = $device.Action
                Since = if ($device.ActionDate) { ([datetime] $device.ActionDate).ToString('yyyy-MM-dd') } else { '' }
                'Days pending' = $device.TimeOnPendingList
                OS = $device.OperatingSystem
                'Entra object ID' = $device.EntraDeviceObjectId
                'Intune device ID' = $device.ManagedDeviceId
            }
        }
    )
    $primaryCount = if ($PrimaryDeviceCount -ge 0) { $PrimaryDeviceCount } else { $Devices.Count }
    $reviewSelection = @(Get-CloudDeviceReportSelection -Devices $Devices -Export $Export -CandidateDevices $CandidateDevices -Limit $ReportDeviceLimit)
    $deviceRows = @(
        foreach ($selected in $reviewSelection) {
            $scope = if ($selected.Index -lt $primaryCount) { 'Primary cleanup' } else { 'Autopilot removal only' }
            ConvertTo-CloudDeviceReportRow -Device $selected.Device -Scope $scope -CurrentActions $selected.CurrentActions -PendingAction $selected.PendingAction -ReviewSelection $selected.Reason
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
#cloud-device-inventory > tbody > tr.child ul.dtr-details { display: block; width: 100%; columns: 26rem; column-gap: 2rem; }
#cloud-device-inventory > tbody > tr.child ul.dtr-details > li { break-inside: avoid; overflow-wrap: anywhere; }
#cloud-device-inventory > tbody > tr.child .dtr-title { margin-right: 0.5rem; }
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
                        New-HTMLTableHeader -Names 'OS', 'Entra age (days)', 'Intune age (days)', 'Entra object ID', 'Intune device ID', 'Autopilot identity ID', 'Autopilot serial', 'Autopilot resource' -ResponsiveOperations none
                        New-HTMLTableHeader -Names 'Registered owner', 'Owner UPN', 'Intune user UPN', 'Entra compliant', 'Intune compliance', 'Entra managed', 'Entra management type', 'MDM app ID', 'Intune management agent' -ResponsiveOperations none
                    }
                } else {
                    New-HTMLText -Text 'No actions were attempted in this run.'
                }
            }
        }

        New-HTMLTab -Name 'History' {
            New-HTMLSection -HeaderText 'Action history' -Direction column {
                New-HTMLText -Text 'Completed, failed, and WhatIf attempts are retained across runs. A WhatIf entry is a preview, not a completed change. Report-only results are not retained.'
                if ($historyRows.Count -gt 0) {
                    New-HTMLTable -DataTable $historyRows -HideButtons -HideFooter -PagingLength 25 -TextWhenNoData 'No history recorded.' {
                        New-HTMLTableHeader -Names 'Device', 'Action', 'Outcome' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'When', 'Why selected', 'Result' -ResponsiveOperations not-mobile
                        New-HTMLTableHeader -Names 'OS', 'Entra age (days)', 'Intune age (days)', 'Entra object ID', 'Intune device ID', 'Autopilot identity ID', 'Autopilot serial', 'Autopilot resource' -ResponsiveOperations none
                        New-HTMLTableHeader -Names 'Registered owner', 'Owner UPN', 'Intune user UPN', 'Entra compliant', 'Intune compliance', 'Entra managed', 'Entra management type', 'MDM app ID', 'Intune management agent' -ResponsiveOperations none
                    }
                } else {
                    New-HTMLText -Text 'No action history has been recorded yet.'
                }
            }
        }

        New-HTMLTab -Name 'Pending Actions' {
            New-HTMLSection -HeaderText 'Waiting for the next stage' -Direction column {
                New-HTMLText -Text 'Only completed actions enter this list. WhatIf previews never start a pending period.'
                if ($pendingRows.Count -gt 0) {
                    New-HTMLTable -DataTable $pendingRows -HideButtons -HideFooter -PagingLength 25 {
                        New-HTMLTableHeader -Names 'Device', 'Action', 'Days pending' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'Since', 'OS', 'Entra object ID', 'Intune device ID' -ResponsiveOperations not-mobile
                    }
                } else {
                    New-HTMLText -Text 'No devices are pending a later action.'
                }
            }
        }

        New-HTMLTab -Name 'Devices' {
            New-HTMLSection -HeaderText 'Device review sample' -Direction column {
                New-HTMLText -Text ('Showing {0:N0} of {1:N0} inventory records. Detail limit: {2:N0}. Search in this table covers only the displayed sample; the overview counts still cover the full inventory.' -f $deviceRows.Count, $Devices.Count, $ReportDeviceLimit)
                New-HTMLText -Text 'Current-run devices come first, then pending actions, actual rule candidates, and an inventory sample. Older recorded activity comes first within each group. A separate Autopilot removal query can add rows marked Autopilot removal only. Review selection explains why a row is included; it is not a deletion approval.'
                New-HTMLText -Text 'Expand a device row for activity dates, registration, ownership, matching and duplicate-protection facts, Autopilot context, and recorded action reasons. None recorded does not mean eligible or safe to delete: limits, confirmation and action rules still apply. Entra records must be disabled before the Delete stage can select them. Check Rules and the recorded action results before approving removal.'
                if ($deviceRows.Count -gt 0) {
                    New-HTMLTable -DataTable $deviceRows -DataTableID 'cloud-device-inventory' -HideButtons -HideFooter -PagingLength 25 {
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
