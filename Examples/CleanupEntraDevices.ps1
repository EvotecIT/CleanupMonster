# Run the existing scheduled task's Connect-MgGraph block before this script.
# Keep its client secret outside the repository. No Jamf connection is needed.

$TenantId = '<tenant-guid>' # Use the tenant ID from the existing computer cleanup job.
$Today = Get-Date -Format 'yyyy-MM-dd_HH_mm_ss'

Import-Module GraphEssentials -MinimumVersion '0.0.63' -ErrorAction Stop
Import-Module CleanupMonster -MinimumVersion '3.1.15' -ErrorAction Stop

if ([string] (Get-MgContext).TenantId -ne $TenantId) {
    throw "Connect-MgGraph to tenant $TenantId before running cloud cleanup."
}

$invokeCloudDevicesCleanupSplat = @{
    # Starting values from the old job; cloud-scoped counts may differ.
    SafetyEntraLimit             = 20000
    SafetyIntuneLimit            = 19000

    Disable                      = $true
    DisableLimit                 = 10
    DisableLastSeenEntraMoreThan = 90
    DisableRegisteredMoreThan    = 90
    DisableListProcessedMoreThan = $null
    DisableIncludeEntraOnly      = $true

    Delete                       = $true
    DeleteLimit                  = 5
    DeleteLastSeenEntraMoreThan  = 180
    DeleteRegisteredMoreThan     = 180
    DeleteListProcessedMoreThan  = 90
    DeleteIncludeEntraOnly       = $true
    DeleteRemoveIntuneRecord     = $true
    DeleteAutopilotIdentity      = $true

    IncludeJoinType              = @('AzureAD joined', 'AzureAD registered')
    IncludeOperatingSystem       = @('Windows*', 'Android*', 'iOS*', 'iPadOS*', 'macOS*', 'Mac OS*')
    IncludeCompanyOwned          = $true
    ProtectRecentIntuneActivity  = $true
    PreserveDuplicateDeviceNames = $true
    Exclusions                   = @() # Add approved cloud device names or IDs.
    ExcludeAutopilotGroupTag     = @() # Add protected group tags if needed.

    # Use a new, persistent datastore for this cloud policy. Keep it across runs.
    DataStorePath                = 'E:\Support\Scripts\CleanupCloudDevices_ListProcessed.xml'
    ReportPath                   = "E:\Support\Reporting\Custom\CleanupCloudDevices_$Today.html"
    LogPath                      = "E:\Support\Logs\CleanupComputersCloud\CleanupCloudDevices_$Today.log"

    ReportOnly                   = $true
    WhatIfDisable                = $false
    WhatIfDelete                 = $false
    ShowHTML                     = $false
}

$Output = Invoke-CloudDevicesCleanup @invokeCloudDevicesCleanupSplat
$Output
