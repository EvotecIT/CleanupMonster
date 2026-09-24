function Write-CloudDeviceStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Label,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [Array] $Devices,

        [switch] $IncludeActivityAge,
        [string] $LogPath
    )

    $os = @{ Windows = 0; Android = 0; iOS = 0; iPadOS = 0; macOS = 0; Other = 0; Unknown = 0 }
    $records = @{ Matched = 0; EntraOnly = 0; IntuneOnly = 0; Other = 0 }
    $links = @{ Healthy = 0; Broken = 0; NotClaimed = 0; IntuneOnly = 0; Other = 0 }
    $enabled = @{ Enabled = 0; Disabled = 0; Unknown = 0 }
    $activity = @{ Recent = 0; Middle = 0; Old = 0; Unknown = 0; NoEntraRecord = 0 }

    foreach ($device in $Devices) {
        $operatingSystem = [string] $device.OperatingSystem
        $osFamily = if ([string]::IsNullOrWhiteSpace($operatingSystem) -or $operatingSystem -eq 'Unknown') {
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
        $os[$osFamily]++

        $recordState = [string] $device.RecordState
        if (-not $records.ContainsKey($recordState)) { $recordState = 'Other' }
        $records[$recordState]++

        $linkState = [string] $device.IntuneLinkState
        if (-not $links.ContainsKey($linkState)) { $linkState = 'Other' }
        $links[$linkState]++

        if ($device.Enabled -eq $true -and $null -ne $device.Enabled) {
            $enabled.Enabled++
        } elseif ($device.Enabled -eq $false -and $null -ne $device.Enabled) {
            $enabled.Disabled++
        } else {
            $enabled.Unknown++
        }

        if ($IncludeActivityAge) {
            if (-not $device.HasEntraRecord) {
                $activity.NoEntraRecord++
            } elseif ($null -eq $device.EntraLastSeenDays) {
                $activity.Unknown++
            } elseif ($device.EntraLastSeenDays -le 90) {
                $activity.Recent++
            } elseif ($device.EntraLastSeenDays -le 180) {
                $activity.Middle++
            } else {
                $activity.Old++
            }
        }
    }

    Write-Color -Text '[i] ', "$Label summary: $($Devices.Count) record(s); OS Windows=$($os.Windows), Android=$($os.Android), iOS=$($os.iOS), iPadOS=$($os.iPadOS), macOS=$($os.macOS), Other=$($os.Other), Unknown=$($os.Unknown)." -Color Yellow, Cyan -LogFile $LogPath
    Write-Color -Text '[i] ', "$Label states: Matched=$($records.Matched), EntraOnly=$($records.EntraOnly), IntuneOnly=$($records.IntuneOnly), Other=$($records.Other); IntuneLink Healthy=$($links.Healthy), Broken=$($links.Broken), NotClaimed=$($links.NotClaimed), IntuneOnly=$($links.IntuneOnly), Other=$($links.Other); Enabled=$($enabled.Enabled), Disabled=$($enabled.Disabled), Unknown=$($enabled.Unknown)." -Color Yellow, Cyan -LogFile $LogPath
    if ($IncludeActivityAge) {
        Write-Color -Text '[i] ', "$Label Entra activity age: <=90d=$($activity.Recent), 91-180d=$($activity.Middle), >180d=$($activity.Old), Unknown=$($activity.Unknown), NoEntraRecord=$($activity.NoEntraRecord). These are activity bands within this job's scope, not portal stale-device totals." -Color Yellow, Cyan -LogFile $LogPath
    }
}
