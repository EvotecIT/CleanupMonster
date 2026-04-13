<#
.SYNOPSIS
Preview stale AzureAD registered mobile devices from the cloud side.

.DESCRIPTION
This example builds a report for iOS and Android devices using the new
cloud-device cleanup workflow. It is intentionally non-destructive and
is the recommended starting point before enabling retire, disable, or delete.

The report distinguishes between:
- matched devices present in both Entra and Intune
- Entra-only records
- Intune-only orphan records

Discovery includes orphan records by default, but action stages require
explicit orphan-inclusion switches before those records can be actioned.
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
    Disable                       = $true
    Delete                        = $true
    ReportOnly                    = $true
    WhatIfRetire                  = $true
    WhatIfDisable                 = $true
    WhatIfDelete                  = $true
    IncludeOperatingSystem        = @('iOS*', 'Android*')
    DataStorePath                 = "$PSScriptRoot\ProcessedCloudDevices.xml"
    ReportPath                    = "$PSScriptRoot\Reports\CleanupCloudDevicesPreview_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    LogPath                       = "$PSScriptRoot\Logs\CleanupCloudDevicesPreview_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    ShowHTML                      = $true
    SafetyEntraLimit              = 10
    SafetyIntuneLimit             = 10
}

$output = Invoke-CloudDevicesCleanup @configuration
$output
