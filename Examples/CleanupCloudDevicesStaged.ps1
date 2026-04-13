<#
.SYNOPSIS
Baseline staged lifecycle for AzureAD registered mobile devices.

.DESCRIPTION
This example uses a conservative sequence:
- retire stale managed devices after 120 days
- disable Entra device objects after 30 days on the pending list
- delete only after an additional 30-day grace period

This layout is aimed at production automation where you want reviewable,
incremental changes with low action limits and reusable datastore/history.

Orphan records are discovered and reported automatically, but this example
keeps orphan actioning disabled by default. Enable the stage-specific
switches only after you review the report and decide which orphan states
you want to process in production.
#>

Import-Module .\CleanupMonster.psd1 -Force

Connect-MgGraph -Scopes `
    Device.Read.All, `
    Device.ReadWrite.All, `
    DeviceManagementManagedDevices.Read.All, `
    DeviceManagementManagedDevices.ReadWrite.All, `
    DeviceManagementManagedDevices.PrivilegedOperations.All

$configuration = @{
    Retire                        = $true
    RetireLastSeenIntuneMoreThan  = 120
    RetireLimit                   = 10

    Disable                       = $true
    DisableListProcessedMoreThan  = 30
    DisableLastSeenEntraMoreThan  = 150
    DisableLimit                  = 10

    Delete                        = $true
    DeleteListProcessedMoreThan   = 30
    DeleteLastSeenIntuneMoreThan  = 180
    DeleteLastSeenEntraMoreThan   = 180
    DeleteRemoveIntuneRecord      = $true
    DeleteLimit                   = 5

    # Optional orphan handling:
    # RetireIncludeIntuneOnly     = $true
    # DisableIncludeEntraOnly     = $true
    # DeleteIncludeEntraOnly      = $true
    # DeleteIncludeIntuneOnly     = $true

    IncludeOperatingSystem        = @('iOS*', 'Android*')
    Exclusions                    = @(
        'Shared-*'
    )

    DataStorePath                 = "$PSScriptRoot\ProcessedCloudDevices.xml"
    ReportPath                    = "$PSScriptRoot\Reports\CleanupCloudDevices_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    LogPath                       = "$PSScriptRoot\Logs\CleanupCloudDevices_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    ShowHTML                      = $true

    WhatIfRetire                  = $true
    WhatIfDisable                 = $true
    WhatIfDelete                  = $true

    SafetyEntraLimit              = 10
    SafetyIntuneLimit             = 10
}

$output = Invoke-CloudDevicesCleanup @configuration
$output
