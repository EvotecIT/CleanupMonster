function Invoke-CloudDevicesCleanup {
    <#
    .SYNOPSIS
    Cleans up stale Microsoft Entra registered cloud devices.

    .DESCRIPTION
    Handles staged cleanup for Microsoft Entra and Intune cloud device records.
    The default operating-system scope is iOS and Android because these are the
    intended mobile-device cleanup targets, but the scope can be changed with
    IncludeOperatingSystem and ExcludeOperatingSystem.

    The workflow supports three explicit stages:
    - Retire: retires stale Intune managed devices.
    - Disable: disables stale Microsoft Entra devices after matching criteria or pending-list age.
    - Delete: removes stale Microsoft Entra devices and, by default, eligible Intune records.

    The cmdlet keeps a datastore with PendingActions and History so staged actions
    can be reviewed over multiple runs. ReportOnly and WhatIf/action-specific
    WhatIf modes show candidates without mutating pending cleanup state.

    Blank activity timestamps are intentionally excluded from destructive actions by default.
    This follows Microsoft guidance for stale-device cleanup where activity timestamps can be empty
    even for active devices.
    Hybrid Azure AD joined and Azure AD joined records are excluded from this cloud-device workflow;
    use Invoke-ADComputersCleanup for hybrid device lifecycle cleanup.

    .PARAMETER Retire
    Enables the Intune retire stage.

    .PARAMETER RetireLastSeenIntuneMoreThan
    Retire devices only when the Intune LastSeenDays value is greater than this number.
    Defaults to 120 days. Devices with blank Intune activity are not selected by this criterion.

    .PARAMETER RetireLastSeenEntraMoreThan
    Retire devices only when the Entra LastSeenDays value is greater than this number.
    Devices with blank Entra activity are not selected by this criterion.

    .PARAMETER RetireIncludeIntuneOnly
    Allows retire-stage processing of Intune-only orphan records.
    By default, orphan Intune records are discovered and reported but not actioned.

    .PARAMETER RetireLimit
    Maximum number of devices to retire in one run. 0 means unlimited. Default is 10.

    .PARAMETER Disable
    Enables the Microsoft Entra disable stage.

    .PARAMETER DisableLastSeenEntraMoreThan
    Disable devices only when the Entra LastSeenDays value is greater than this number.
    Entra-backed devices must have Enabled equal to $true; unknown enabled state is treated as unsafe.

    .PARAMETER DisableLastSeenIntuneMoreThan
    Disable devices only when the Intune LastSeenDays value is greater than this number.
    Devices with blank Intune activity are not selected by this criterion.

    .PARAMETER DisableListProcessedMoreThan
    Disable devices only after they were previously actioned and remained pending longer than this number of days.
    Defaults to 30 days.

    .PARAMETER DisableIncludeEntraOnly
    Allows disable-stage processing of Entra-only records.
    By default, Entra-only records are discovered and reported but not actioned.

    .PARAMETER DisableLimit
    Maximum number of devices to disable in one run. 0 means unlimited. Default is 10.

    .PARAMETER Delete
    Enables the final delete stage.

    .PARAMETER DeleteLastSeenEntraMoreThan
    Delete devices only when the Entra LastSeenDays value is greater than this number.
    Entra-backed devices must have Enabled equal to $false; unknown enabled state is treated as unsafe.

    .PARAMETER DeleteLastSeenIntuneMoreThan
    Delete devices only when the Intune LastSeenDays value is greater than this number.
    Devices with blank Intune activity are not selected by this criterion.

    .PARAMETER DeleteListProcessedMoreThan
    Delete devices only after they were previously actioned and remained pending longer than this number of days.
    Defaults to 30 days.

    .PARAMETER DeleteIncludeEntraOnly
    Allows delete-stage processing of Entra-only orphan records.

    .PARAMETER DeleteIncludeIntuneOnly
    Allows delete-stage processing of Intune-only orphan records.

    .PARAMETER DeleteLimit
    Maximum number of devices to delete in one run. 0 means unlimited. Default is 10.

    .PARAMETER DeleteRemoveIntuneRecord
    Controls whether delete-stage processing also removes eligible Intune managed-device records.
    Defaults to $true.

    .PARAMETER IncludeOperatingSystem
    Operating-system patterns to include when building cloud-device inventory.
    Defaults to iOS and Android patterns. Wildcards are supported.

    .PARAMETER ExcludeOperatingSystem
    Operating-system patterns to exclude when building cloud-device inventory.
    Wildcards are supported.

    .PARAMETER Exclusions
    Device names, Entra object IDs, Intune managed-device IDs, or other supported identifiers to exclude from cleanup.

    .PARAMETER IncludeCompanyOwned
    Includes company-owned devices in candidate selection. By default company-owned devices are excluded from actions.

    .PARAMETER DataStorePath
    Path to the XML datastore that tracks PendingActions and History.
    Defaults to ProcessedCloudDevices.xml next to this function.

    .PARAMETER ReportOnly
    Generates inventory and reports without executing retire, disable, or delete actions and without writing updated cleanup state.
    Existing pending actions are still read so staged candidates can be reported accurately.

    .PARAMETER WhatIfRetire
    Previews retire actions only. Preview results are shown in the current report but are not stored as pending actions or history.

    .PARAMETER WhatIfDisable
    Previews disable actions only. Preview results are shown in the current report but are not stored as pending actions or history.

    .PARAMETER WhatIfDelete
    Previews delete actions only. Preview results are shown in the current report but are not stored as pending actions or history.

    .PARAMETER LogPath
    Path to a log file. When omitted, file logging is not enabled.

    .PARAMETER LogMaximum
    Maximum number of rotated log files to keep. Default is 5.

    .PARAMETER LogShowTime
    Includes timestamps in log output.

    .PARAMETER LogTimeFormat
    Date/time format used when LogShowTime is enabled.

    .PARAMETER Suppress
    Suppresses returning the export object to the pipeline.

    .PARAMETER ShowHTML
    Opens the generated HTML report after the run.

    .PARAMETER Online
    Uses CDN-hosted CSS and JavaScript assets for the HTML report, reducing report file size.

    .PARAMETER ReportPath
    Path where the HTML report is written.
    Defaults to ProcessedCloudDevices.html next to this function.

    .PARAMETER SafetyEntraLimit
    Stops processing if the Entra inventory count is below this value.
    Use this as a guard against partial Graph inventory responses.

    .PARAMETER SafetyIntuneLimit
    Stops processing if the Intune inventory count is below this value.
    Use this as a guard against partial Graph inventory responses.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -ReportOnly -ShowHTML

    Builds a report of Intune retire candidates using the default stale threshold without changing devices or cleanup state.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -Disable -Delete -RetireLastSeenIntuneMoreThan 120 -DisableListProcessedMoreThan 30 -DeleteListProcessedMoreThan 30

    Runs the full staged workflow: retire stale Intune devices, disable pending devices after 30 days, and delete pending devices after 30 days.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -Disable -Delete -WhatIf -SafetyEntraLimit 1000 -SafetyIntuneLimit 1000 -ReportPath C:\Reports\CloudDevices.html -ShowHTML

    Previews all enabled stages, requires minimum inventory counts, writes an HTML report, and opens it for review.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Delete -DeleteIncludeIntuneOnly -DeleteRemoveIntuneRecord $true -DeleteLastSeenIntuneMoreThan 180 -WhatIfDelete

    Previews cleanup of stale Intune-only orphan records without deleting anything or updating the pending-action datastore.

    .EXAMPLE
    $cloudCleanup = Invoke-CloudDevicesCleanup -Disable -DisableLastSeenEntraMoreThan 180 -IncludeOperatingSystem 'Android*' -ExcludeOperatingSystem '*Dedicated*' -Confirm
    $cloudCleanup.CurrentRun | Format-Table Name, Action, ActionStatus, ActionDate

    Disables matching Android Entra-backed devices after confirmation and reviews the current run.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch] $Retire,
        [nullable[int]] $RetireLastSeenIntuneMoreThan = 120,
        [nullable[int]] $RetireLastSeenEntraMoreThan,
        [switch] $RetireIncludeIntuneOnly,
        [int] $RetireLimit = 10,

        [switch] $Disable,
        [nullable[int]] $DisableLastSeenEntraMoreThan,
        [nullable[int]] $DisableLastSeenIntuneMoreThan,
        [nullable[int]] $DisableListProcessedMoreThan = 30,
        [switch] $DisableIncludeEntraOnly,
        [int] $DisableLimit = 10,

        [switch] $Delete,
        [nullable[int]] $DeleteLastSeenEntraMoreThan,
        [nullable[int]] $DeleteLastSeenIntuneMoreThan,
        [nullable[int]] $DeleteListProcessedMoreThan = 30,
        [switch] $DeleteIncludeEntraOnly,
        [switch] $DeleteIncludeIntuneOnly,
        [int] $DeleteLimit = 10,
        [bool] $DeleteRemoveIntuneRecord = $true,

        [Array] $IncludeOperatingSystem = @('iOS*', 'Android*'),
        [Array] $ExcludeOperatingSystem = @(),
        [Array] $Exclusions = @(),
        [switch] $IncludeCompanyOwned,

        [string] $DataStorePath,
        [switch] $ReportOnly,
        [switch] $WhatIfRetire,
        [switch] $WhatIfDisable,
        [switch] $WhatIfDelete,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $LogShowTime,
        [string] $LogTimeFormat,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,
        [string] $ReportPath,
        [nullable[int]] $SafetyEntraLimit,
        [nullable[int]] $SafetyIntuneLimit
    )

    if ($WhatIfPreference) {
        if (-not $PSBoundParameters.ContainsKey('WhatIfRetire')) {
            $WhatIfRetire = $true
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIfDisable')) {
            $WhatIfDisable = $true
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIfDelete')) {
            $WhatIfDelete = $true
        }
    }

    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    if (-not $DataStorePath) {
        $DataStorePath = Join-Path -Path $MyInvocation.PSScriptRoot -ChildPath 'ProcessedCloudDevices.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = Join-Path -Path $MyInvocation.PSScriptRoot -ChildPath 'ProcessedCloudDevices.html'
    }

    Set-ReportingCapabilities -ReportPath $ReportPath -ReportMaximum 0 -ScriptPath $MyInvocation.ScriptName

    Write-Color -Text '[i] ', 'Started process of cleaning up stale cloud devices' -Color Yellow, White
    Write-Color -Text '[i] ', 'Executed by: ', $Env:USERNAME -Color Yellow, White, Green

    if (-not (Assert-CloudDeviceCleanupSettings)) {
        return
    }

    if (-not $Retire -and -not $Disable -and -not $Delete) {
        Write-Color -Text '[i] ', 'No action can be taken. You need to enable Retire, Disable or Delete.' -Color Yellow, Red
        return
    }

    $confirmActions = $PSBoundParameters.ContainsKey('Confirm') -and [bool] $PSBoundParameters['Confirm']

    $retireOnlyIf = [ordered] @{
        LastSeenIntuneMoreThan = $RetireLastSeenIntuneMoreThan
        LastSeenEntraMoreThan  = $RetireLastSeenEntraMoreThan
        ExcludeCompanyOwned    = -not $IncludeCompanyOwned
        IncludeIntuneOnly      = $RetireIncludeIntuneOnly.IsPresent
    }

    $disableOnlyIf = [ordered] @{
        LastSeenEntraMoreThan  = $DisableLastSeenEntraMoreThan
        LastSeenIntuneMoreThan = $DisableLastSeenIntuneMoreThan
        ListProcessedMoreThan  = $DisableListProcessedMoreThan
        ExcludeCompanyOwned    = -not $IncludeCompanyOwned
        IncludeEntraOnly       = $DisableIncludeEntraOnly.IsPresent
    }

    $deleteOnlyIf = [ordered] @{
        LastSeenEntraMoreThan  = $DeleteLastSeenEntraMoreThan
        LastSeenIntuneMoreThan = $DeleteLastSeenIntuneMoreThan
        ListProcessedMoreThan  = $DeleteListProcessedMoreThan
        ExcludeCompanyOwned    = -not $IncludeCompanyOwned
        IncludeEntraOnly       = $DeleteIncludeEntraOnly.IsPresent
        IncludeIntuneOnly      = $DeleteIncludeIntuneOnly.IsPresent
    }

    $export = [ordered] @{
        Version        = Get-GitHubVersion -Cmdlet 'Invoke-CloudDevicesCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun     = @()
        History        = @()
        PendingActions = [ordered] @{}
    }

    $processedDevices = Import-CloudDevicesData -DataStorePath $DataStorePath -Export $export
    if ($processedDevices -eq $false) {
        return
    }

    $allDevices = Get-InitialCloudDevices -SafetyEntraLimit $SafetyEntraLimit -SafetyIntuneLimit $SafetyIntuneLimit -IncludeOperatingSystem $IncludeOperatingSystem -ExcludeOperatingSystem $ExcludeOperatingSystem -Exclusions $Exclusions
    if ($allDevices -eq $false) {
        return
    }

    $today = Get-Date
    $reportRetired = @()
    $reportDisabled = @()
    $reportDeleted = @()

    if ($Retire) {
        $devicesToRetire = @(Get-CloudDevicesToProcess -Type Retire -Devices $allDevices -ActionIf $retireOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be retired: ', $devicesToRetire.Count, '. Current retire limit: ', $(if ($RetireLimit -eq 0) { 'Unlimited' } else { $RetireLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processRetire = $devicesToRetire.Count -gt 0
        if ($processRetire -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfRetire)) {
            $processRetire = $PSCmdlet.ShouldProcess("$($devicesToRetire.Count) cloud device(s)", 'Retire')
        }
        if ($processRetire) {
            $reportRetired = @(Request-CloudDevicesRetire -Devices $devicesToRetire -ProcessedDevices $processedDevices -Today $today -RetireLimit $RetireLimit -ReportOnly:$ReportOnly -WhatIfRetire:$WhatIfRetire -WhatIf:$WhatIfPreference)
        }
    }

    if ($Disable) {
        $devicesToDisable = @(Get-CloudDevicesToProcess -Type Disable -Devices $allDevices -ActionIf $disableOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be disabled: ', $devicesToDisable.Count, '. Current disable limit: ', $(if ($DisableLimit -eq 0) { 'Unlimited' } else { $DisableLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processDisable = $devicesToDisable.Count -gt 0
        if ($processDisable -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfDisable)) {
            $processDisable = $PSCmdlet.ShouldProcess("$($devicesToDisable.Count) cloud device(s)", 'Disable')
        }
        if ($processDisable) {
            $reportDisabled = @(Request-CloudDevicesDisable -Devices $devicesToDisable -ProcessedDevices $processedDevices -Today $today -DisableLimit $DisableLimit -ReportOnly:$ReportOnly -WhatIfDisable:$WhatIfDisable -WhatIf:$WhatIfPreference)
        }
    }

    if ($Delete) {
        $devicesToDelete = @(Get-CloudDevicesToProcess -Type Delete -Devices $allDevices -ActionIf $deleteOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be deleted: ', $devicesToDelete.Count, '. Current delete limit: ', $(if ($DeleteLimit -eq 0) { 'Unlimited' } else { $DeleteLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processDelete = $devicesToDelete.Count -gt 0
        if ($processDelete -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfDelete)) {
            $processDelete = $PSCmdlet.ShouldProcess("$($devicesToDelete.Count) cloud device(s)", 'Delete')
        }
        if ($processDelete) {
            $reportDeleted = @(Request-CloudDevicesDelete -Devices $devicesToDelete -ProcessedDevices $processedDevices -Today $today -DeleteLimit $DeleteLimit -DeleteRemoveIntuneRecord:$DeleteRemoveIntuneRecord -ReportOnly:$ReportOnly -WhatIfDelete:$WhatIfDelete -WhatIf:$WhatIfPreference)
        }
    }

    $export.PendingActions = $processedDevices
    $export.CurrentRun = @(
        if ($reportRetired.Count -gt 0) { $reportRetired }
        if ($reportDisabled.Count -gt 0) { $reportDisabled }
        if ($reportDeleted.Count -gt 0) { $reportDeleted }
    )
    $persistedRun = @()
    if ($reportRetired.Count -gt 0) {
        $persistedRun += @($reportRetired | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    if ($reportDisabled.Count -gt 0) {
        $persistedRun += @($reportDisabled | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    if ($reportDeleted.Count -gt 0) {
        $persistedRun += @($reportDeleted | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    $export.History = @(
        if ($export.History) { $export.History }
        if ($persistedRun.Count -gt 0) { $persistedRun }
    )

    if (-not $ReportOnly) {
        try {
            $export | Export-Clixml -LiteralPath $DataStorePath -Encoding Unicode -WhatIf:$false -ErrorAction Stop
        } catch {
            Write-Color -Text '[-] Exporting processed cloud device list failed. Error: ', $_.Exception.Message -Color Yellow, Red
        }
    }

    New-HTMLProcessedCloudDevices -Export $export -Devices $allDevices -RetireOnlyIf $retireOnlyIf -DisableOnlyIf $disableOnlyIf -DeleteOnlyIf $deleteOnlyIf -FilePath $ReportPath -Online:$Online -ShowHTML:$ShowHTML -LogFile $LogPath

    Write-Color -Text '[i] ', 'Finished process of cleaning up stale cloud devices' -Color Green

    if (-not $Suppress) {
        $export.EmailBody = New-EmailBodyCloudDevices -CurrentRun $export.CurrentRun
        $export
    }
}
