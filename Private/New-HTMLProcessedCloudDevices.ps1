function New-HTMLProcessedCloudDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Export,
        [Parameter(Mandatory)] [Array] $Devices,
        [int] $PrimaryDeviceCount = -1,
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
    $deviceRows = @(
        for ($deviceIndex = 0; $deviceIndex -lt $Devices.Count; $deviceIndex++) {
            $device = $Devices[$deviceIndex]
            $enabled = if ($device.Enabled -eq $true) { 'Yes' } elseif ($device.Enabled -eq $false) { 'No' } else { 'Unknown' }
            [pscustomobject] @{
                Device = $device.Name
                Scope = if ($deviceIndex -lt $primaryCount) { 'Primary cleanup' } else { 'Autopilot removal only' }
                OS = $device.OperatingSystem
                Source = $device.RecordState
                Enabled = $enabled
                'Entra age (days)' = $device.EntraLastSeenDays
                'Intune age (days)' = $device.IntuneLastSeenDays
                'Intune link' = $device.IntuneLinkState
                'Entra object ID' = $device.EntraDeviceObjectId
                'Intune device ID' = $device.ManagedDeviceId
                'Autopilot identity ID' = $device.AutopilotDeviceId
            }
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
                    New-HTMLSection -HeaderText 'Selected by OS' -CanCollapse -Collapsed {
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
            New-HTMLSection -HeaderText 'Devices returned for reporting' -Direction column {
                New-HTMLText -Text 'The primary cleanup inventory appears first. A separate Autopilot removal query can add rows; those rows are marked Autopilot removal only. A primary row can also match the Autopilot query. This is inventory context, not an action list.'
                if ($deviceRows.Count -gt 0) {
                    New-HTMLTable -DataTable $deviceRows -HideButtons -HideFooter -PagingLength 25 {
                        New-HTMLTableHeader -Names 'Device', 'Scope', 'OS', 'Enabled' -ResponsiveOperations all
                        New-HTMLTableHeader -Names 'Source', 'Entra age (days)', 'Intune age (days)', 'Intune link', 'Entra object ID', 'Intune device ID', 'Autopilot identity ID' -ResponsiveOperations not-mobile
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
