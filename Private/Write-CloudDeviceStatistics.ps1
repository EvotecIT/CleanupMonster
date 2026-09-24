function Write-CloudDeviceStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Label,
        [Parameter(Mandatory)] [AllowNull()] [AllowEmptyCollection()] [Array] $Devices,
        [Parameter(Mandatory)] [ValidateSet('Entra', 'Intune', 'Scoped', 'Candidates')] [string] $Mode,
        [string] $LogPath,
        [switch] $PassThru
    )

    $families = @('Windows', 'Android', 'iOS', 'iPadOS', 'macOS', 'Other', 'Unknown')
    $totals = @{}
    foreach ($family in @('ALL') + $families) {
        $totals[$family] = @{ Total = 0; On = 0; Off = 0; UnknownState = 0; Recent = 0; Middle = 0; Old = 0; UnknownAge = 0; NoEntra = 0; Old90 = 0; OnOld90 = 0; OnOld180 = 0 }
    }
    $records = @{ Matched = 0; EntraOnly = 0; IntuneOnly = 0; Other = 0 }
    $links = @{ Healthy = 0; Broken = 0; NotClaimed = 0; IntuneOnly = 0; Other = 0 }
    $otherOsLabels = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($device in $Devices) {
        $operatingSystem = [string] $device.OperatingSystem
        $family = if ([string]::IsNullOrWhiteSpace($operatingSystem) -or $operatingSystem -eq 'Unknown') {
            'Unknown'
        } elseif ($operatingSystem -like 'Windows*') {
            'Windows'
        } elseif ($operatingSystem -like 'Android*') {
            'Android'
        } elseif ($operatingSystem -like 'iPadOS*') {
            'iPadOS'
        } elseif ($operatingSystem -like 'iOS*') {
            'iOS'
        } elseif ($operatingSystem -like 'macOS*' -or $operatingSystem -like 'Mac OS*') {
            'macOS'
        } else {
            'Other'
        }
        if ($family -eq 'Other') {
            $otherOsLabel = $operatingSystem.Trim()
            if (-not $otherOsLabels.ContainsKey($otherOsLabel)) { $otherOsLabels[$otherOsLabel] = 0 }
            $otherOsLabels[$otherOsLabel]++
        }

        foreach ($row in @($totals.ALL, $totals[$family])) {
            $row.Total++
            if ($Mode -ne 'Intune') {
                if ($null -ne $device.Enabled -and $device.Enabled -eq $true) {
                    $row.On++
                } elseif ($null -ne $device.Enabled -and $device.Enabled -eq $false) {
                    $row.Off++
                } else {
                    $row.UnknownState++
                }
            }

            if ($Mode -eq 'Entra' -or $Mode -eq 'Intune' -or $Mode -eq 'Scoped') {
                $noEntra = $Mode -eq 'Scoped' -and -not $device.HasEntraRecord
                $age = if ($Mode -eq 'Scoped') { $device.EntraLastSeenDays } else { $device.LastSeenDays }
                if ($noEntra) {
                    $row.NoEntra++
                } elseif ($null -eq $age) {
                    $row.UnknownAge++
                } elseif ($age -le 90) {
                    $row.Recent++
                } elseif ($age -le 180) {
                    $row.Middle++
                    $row.Old90++
                    if ($null -ne $device.Enabled -and $device.Enabled -eq $true) { $row.OnOld90++ }
                } else {
                    $row.Old++
                    $row.Old90++
                    if ($null -ne $device.Enabled -and $device.Enabled -eq $true) {
                        $row.OnOld90++
                        $row.OnOld180++
                    }
                }
            }
        }

        if ($Mode -eq 'Scoped') {
            $recordState = [string] $device.RecordState
            if (-not $records.ContainsKey($recordState)) { $recordState = 'Other' }
            $records[$recordState]++
            $linkState = [string] $device.IntuneLinkState
            if (-not $links.ContainsKey($linkState)) { $linkState = 'Other' }
            $links[$linkState]++
        }
    }

    Write-Color -Text '[i] ', "$Label`: $($totals.ALL.Total) record(s)." -Color Yellow, Cyan -LogFile $LogPath
    $visibleFamilies = @('ALL') + @($families | Where-Object { $totals[$_].Total -gt 0 })
    if ($Mode -eq 'Candidates') {
        Write-Color -Text '[i] ', 'Selected by stage rules, before action limits or WhatIf.' -Color Yellow, Cyan -LogFile $LogPath
    }

    if ($Mode -eq 'Intune') {
        Write-Color -Text '[i] ', 'Intune sync age by OS (non-overlapping day bands):' -Color Yellow, Cyan -LogFile $LogPath
    } else {
        Write-Color -Text '[i] ', 'Enabled state by OS:' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'OS              Total   Enabled  Disabled   Unknown' -Color Yellow, Cyan -LogFile $LogPath
        foreach ($family in $visibleFamilies) {
            $row = $totals[$family]
            $line = '{0,-12} {1,9:N0} {2,9:N0} {3,9:N0} {4,9:N0}' -f $family, $row.Total, $row.On, $row.Off, $row.UnknownState
            Write-Color -Text '[i] ', $line -Color Yellow, Cyan -LogFile $LogPath
        }
    }

    if ($Mode -eq 'Entra' -or $Mode -eq 'Intune' -or $Mode -eq 'Scoped') {
        if ($Mode -ne 'Intune') {
            Write-Color -Text '[i] ', 'Entra activity age by OS (non-overlapping day bands):' -Color Yellow, Cyan -LogFile $LogPath
        }
        $ageHeader = if ($Mode -eq 'Scoped') { 'OS              <=90d   91-180d     >180d   Unknown   No Entra' } else { 'OS              <=90d   91-180d     >180d   Unknown' }
        Write-Color -Text '[i] ', $ageHeader -Color Yellow, Cyan -LogFile $LogPath
        foreach ($family in $visibleFamilies) {
            $row = $totals[$family]
            $line = '{0,-12} {1,9:N0} {2,9:N0} {3,9:N0} {4,9:N0}' -f $family, $row.Recent, $row.Middle, $row.Old, $row.UnknownAge
            if ($Mode -eq 'Scoped') { $line += (' {0,9:N0}' -f $row.NoEntra) }
            Write-Color -Text '[i] ', $line -Color Yellow, Cyan -LogFile $LogPath
        }
    }

    if ($Mode -eq 'Entra' -or $Mode -eq 'Scoped') {
        Write-Color -Text '[i] ', 'Enabled with old Entra activity (cumulative; other rules still apply):' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'OS               >90d     >180d' -Color Yellow, Cyan -LogFile $LogPath
        foreach ($family in $visibleFamilies) {
            $row = $totals[$family]
            $line = '{0,-12} {1,9:N0} {2,9:N0}' -f $family, $row.OnOld90, $row.OnOld180
            Write-Color -Text '[i] ', $line -Color Yellow, Cyan -LogFile $LogPath
        }
    }

    if ($otherOsLabels.Count -gt 0 -and ($Mode -eq 'Entra' -or $Mode -eq 'Intune')) {
        Write-Color -Text '[i] ', 'Other OS labels in this source (most common first):' -Color Yellow, Cyan -LogFile $LogPath
        $shownLabels = @($otherOsLabels.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8)
        $shownTotal = 0
        foreach ($entry in $shownLabels) {
            $shownTotal += $entry.Value
            $displayLabel = ($entry.Key -replace '[\r\n\t]+', ' ').Trim()
            if ($displayLabel.Length -gt 35) { $displayLabel = $displayLabel.Substring(0, 32) + '...' }
            Write-Color -Text '[i] ', ('  {0,-35} {1,9:N0}' -f $displayLabel, $entry.Value) -Color Yellow, Cyan -LogFile $LogPath
        }
        if ($otherOsLabels.Count -gt $shownLabels.Count) {
            Write-Color -Text '[i] ', "  Remaining $($otherOsLabels.Count - $shownLabels.Count) label(s): $($totals.Other.Total - $shownTotal) record(s)." -Color Yellow, Cyan -LogFile $LogPath
        }
    }

    if ($Mode -eq 'Scoped') {
        Write-Color -Text '[i] ', "Scoped source: Matched=$($records.Matched); EntraOnly=$($records.EntraOnly); IntuneOnly=$($records.IntuneOnly); Other=$($records.Other)." -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', "Intune link: Healthy=$($links.Healthy); Broken=$($links.Broken); NotClaimed=$($links.NotClaimed)." -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', "Intune link: IntuneOnly=$($links.IntuneOnly); Other=$($links.Other)." -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', "Scoped records without an Entra activity date: NoEntra=$($totals.ALL.NoEntra)." -Color Yellow, Cyan -LogFile $LogPath
    }

    if ($PassThru) {
        [pscustomobject] @{
            Label   = $Label
            Mode    = $Mode
            Total   = $totals.ALL.Total
            Rows    = @(
                foreach ($family in @('ALL') + $families) {
                    $row = $totals[$family]
                    if ($family -ne 'ALL' -and $row.Total -eq 0) { continue }
                    [pscustomobject] @{
                        OS              = $family
                        Total           = $row.Total
                        Enabled         = $row.On
                        Disabled        = $row.Off
                        UnknownState    = $row.UnknownState
                        AgeWithin90     = $row.Recent
                        Age91To180      = $row.Middle
                        AgeOver90       = $row.Old90
                        AgeOver180      = $row.Old
                        EnabledOver90   = $row.OnOld90
                        EnabledOver180  = $row.OnOld180
                        UnknownActivity = $row.UnknownAge
                        NoEntraRecord   = $row.NoEntra
                    }
                }
            )
            Records = [pscustomobject] $records
            Links   = [pscustomobject] $links
        }
    }
}
