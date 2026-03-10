<#
.SYNOPSIS
Computer cleanup that cross-checks AD, Azure AD, Intune, and optionally Jamf.

.DESCRIPTION
This example is for environments that do not want to disable or delete AD
computers unless cloud-management signals also show inactivity.

Use it when Azure AD or Intune is part of your device lifecycle and you want
to protect against deleting machines that are still active elsewhere.

Before running for real, review:
- cloud safety limits
- Graph scopes
- whether Jamf should also be enabled
- WhatIf settings
#>

Import-Module .\CleanupMonster.psd1 -Force

Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.ReadWrite.All, DeviceManagementConfiguration.Read.All
#Connect-Jamf -Organization 'Evotec' -UserName 'API_AD_CLEANUP' -Suppress -Force -PasswordEncrypted 'dsdsdd'

# this is a fresh run and it will provide report only according to it's defaults
$invokeADComputersCleanupSplat = @{
    # safety limits (minimum amount of computers that has to be returned from each source)
    SafetyADLimit                  = 40
    SafetyAzureADLimit             = 5
    SafetyIntuneLimit              = 2
    #SafetyJamfLimit                = 50
    # disable settings
    Disable                        = $true
    DisableLimit                   = 10
    DisableLastLogonDateMoreThan   = 90
    DisablePasswordLastSetMoreThan = 90
    DisableLastSeenAzureMoreThan   = 90
    DisableLastSyncAzureMoreThan   = 90
    #DisableLastContactJamfMoreThan = 90
    DisableLastSeenIntuneMoreThan  = 90
    # delete settings
    Delete                         = $true
    DeleteLimit                    = 10
    DeleteLastLogonDateMoreThan    = 180
    DeletePasswordLastSetMoreThan  = 180
    DeleteLastSeenAzureMoreThan    = 180
    DeleteLastSyncAzureMoreThan    = 180
    # DeleteLastContactJamfMoreThan  = 180
    DeleteLastSeenIntuneMoreThan   = 180
    DeleteListProcessedMoreThan    = 90
    DeleteIsEnabled                = $false # Computer has to be disabled to be deleted
    # global exclusions
    Exclusions                     = @(
        '*OU=Domain Controllers*' # exclude Domain Controllers
    )
    # filter for AD search
    Filter                         = '*'
    # logs, reports and datastores
    LogPath                        = "$PSScriptRoot\Logs\CleanupComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                  = "$PSScriptRoot\CleanupComputers_ListProcessed.xml"
    ReportPath                     = "$PSScriptRoot\Reports\CleanupComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    # WhatIf settings
    #ReportOnly                     = $true
    WhatIfDisable                  = $true
    WhatIfDelete                   = $true
    ShowHTML                       = $true
}

$Output = Invoke-ADComputersCleanup @invokeADComputersCleanupSplat
$Output
