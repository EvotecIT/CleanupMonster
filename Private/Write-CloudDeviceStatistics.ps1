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
    if ($Mode -eq 'Intune') {
        Write-Color -Text '[i] ', 'Age = days since Intune sync; bands do not overlap.' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'OS             Total    <=90d  91-180d    >180d    ?Age' -Color Yellow, Cyan -LogFile $LogPath
    } elseif ($Mode -eq 'Candidates') {
        Write-Color -Text '[i] ', 'Selected by stage rules; counts are candidates, not action attempts.' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'OS             Total       On      Off   ?State' -Color Yellow, Cyan -LogFile $LogPath
    } else {
        Write-Color -Text '[i] ', 'Age = Entra activity; >90d and >180d are cumulative.' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'On = enabled; Off = disabled; ?State/?Age = unknown.' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'On>90/On>180 = enabled with old activity; candidates apply all rules.' -Color Yellow, Cyan -LogFile $LogPath
        Write-Color -Text '[i] ', 'OS           Total     On    Off ?State    >90d   >180d  On>90 On>180 ?Age' -Color Yellow, Cyan -LogFile $LogPath
    }

    foreach ($family in @('ALL') + $families) {
        $row = $totals[$family]
        if ($family -ne 'ALL' -and $row.Total -eq 0) { continue }
        $line = if ($Mode -eq 'Intune') {
            '{0,-12} {1,7} {2,8} {3,8} {4,8} {5,7}' -f $family, $row.Total, $row.Recent, $row.Middle, $row.Old, $row.UnknownAge
        } elseif ($Mode -eq 'Candidates') {
            '{0,-12} {1,7} {2,8} {3,8} {4,8}' -f $family, $row.Total, $row.On, $row.Off, $row.UnknownState
        } else {
            '{0,-12} {1,7} {2,6} {3,6} {4,6} {5,7} {6,7} {7,6} {8,6} {9,5}' -f $family, $row.Total, $row.On, $row.Off, $row.UnknownState, $row.Old90, $row.Old, $row.OnOld90, $row.OnOld180, $row.UnknownAge
        }
        Write-Color -Text '[i] ', $line -Color Yellow, Cyan -LogFile $LogPath
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
