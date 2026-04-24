function Invoke-CloudDevicesCleanup {
    <#
    .SYNOPSIS
    Cleans up stale AzureAD registered cloud devices.

    .DESCRIPTION
    Handles staged cleanup for AzureAD registered mobile devices from the cloud side.
    The workflow is designed for iOS and Android devices and supports:
    - Intune retire for stale managed devices
    - Microsoft Entra disable after a grace period
    - Final deletion from Microsoft Entra and optional Intune record removal

    Blank activity timestamps are intentionally excluded from destructive actions by default.
    This follows Microsoft guidance for stale-device cleanup where activity timestamps can be empty
    even for active devices.

    .PARAMETER Retire
    Enables the Intune retire stage.

    .PARAMETER Disable
    Enables the Microsoft Entra disable stage.

    .PARAMETER Delete
    Enables the final delete stage.

    .PARAMETER RetireLastSeenIntuneMoreThan
    Retire devices only if Intune LastSeenDays is greater than this number.

    .PARAMETER RetireIncludeIntuneOnly
    Allows retire-stage processing of Intune-only orphan records.
    By default, orphan Intune records are discovered and reported but not actioned.

    .PARAMETER DisableListProcessedMoreThan
    Disable devices only after they were previously actioned and remained pending longer than this number of days.

    .PARAMETER DisableIncludeEntraOnly
    Allows disable-stage processing of Entra-only records.
    By default, Entra-only records are discovered and reported but not actioned.

    .PARAMETER DeleteListProcessedMoreThan
    Delete devices only after they were previously actioned and remained pending longer than this number of days.

    .PARAMETER DeleteIncludeEntraOnly
    Allows delete-stage processing of Entra-only orphan records.

    .PARAMETER DeleteIncludeIntuneOnly
    Allows delete-stage processing of Intune-only orphan records.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -ReportOnly -ShowHTML

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -Disable -Delete -RetireLastSeenIntuneMoreThan 120 -DisableListProcessedMoreThan 30 -DeleteListProcessedMoreThan 30
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

    if (-not $ReportOnly) {
        $processedDevices = Import-CloudDevicesData -DataStorePath $DataStorePath -Export $export
        if ($processedDevices -eq $false) {
            return
        }
    } else {
        $processedDevices = [ordered] @{}
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
            $reportRetired = Request-CloudDevicesRetire -Devices $devicesToRetire -ProcessedDevices $processedDevices -Today $today -RetireLimit $RetireLimit -ReportOnly:$ReportOnly -WhatIfRetire:$WhatIfRetire -WhatIf:$WhatIfPreference
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
            $reportDisabled = Request-CloudDevicesDisable -Devices $devicesToDisable -ProcessedDevices $processedDevices -Today $today -DisableLimit $DisableLimit -ReportOnly:$ReportOnly -WhatIfDisable:$WhatIfDisable -WhatIf:$WhatIfPreference
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
            $reportDeleted = Request-CloudDevicesDelete -Devices $devicesToDelete -ProcessedDevices $processedDevices -Today $today -DeleteLimit $DeleteLimit -DeleteRemoveIntuneRecord:$DeleteRemoveIntuneRecord -ReportOnly:$ReportOnly -WhatIfDelete:$WhatIfDelete -WhatIf:$WhatIfPreference
        }
    }

    $export.PendingActions = $processedDevices
    $export.CurrentRun = @(
        if ($reportRetired.Count -gt 0) { $reportRetired }
        if ($reportDisabled.Count -gt 0) { $reportDisabled }
        if ($reportDeleted.Count -gt 0) { $reportDeleted }
    )
    $export.History = @(
        if ($export.History) { $export.History }
        if ($reportRetired.Count -gt 0) { $reportRetired }
        if ($reportDisabled.Count -gt 0) { $reportDisabled }
        if ($reportDeleted.Count -gt 0) { $reportDeleted }
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
