Import-Module .\CleanupMonster.psd1 -Force

# connect to graph for Azure AD, Intune (requires GraphEssentials module)
Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.ReadWrite.All, DeviceManagementConfiguration.Read.All
# connect to jamf (requires PowerJamf module)
#Connect-Jamf -Organization 'aaa' -UserName 'aaa' -Suppress -Force -PasswordEncrypted 'aaaaa'

$invokeADComputersCleanupSplat = @{
    # safety limits (minimum amount of computers that has to be returned from each source)
    SafetyADLimit                       = 30
    SafetyAzureADLimit                  = 5
    SafetyIntuneLimit                   = 3
    SafetyJamfLimit                     = 50
    # disable settings
    Disable                             = $true
    DisableAndMove                      = $false
    #DisableIsEnabled                    = $true
    DisableLimit                        = 2
    DisableLastLogonDateMoreThan        = 90
    DisablePasswordLastSetMoreThan      = 90
    DisableLastSeenAzureMoreThan        = 90

    DisablePasswordLastSetOlderThan     = Get-Date -Year 2023 -Month 1 -Day 1
    #DisableLastSyncAzureMoreThan   = 90
    #DisableLastContactJamfMoreThan = 90
    DisableLastSeenIntuneMoreThan       = 90
    DisableMoveTargetOrganizationalUnit = @{
        'ad.evotec.xyz' = 'OU=Disabled,OU=Computers,OU=Devices,OU=Production,DC=ad,DC=evotec,DC=xyz'
        'ad.evotec.pl'  = 'OU=Disabled,OU=Computers,OU=Devices,OU=Production,DC=ad,DC=evotec,DC=pl'
    }
    # move settings
    Move                                = $false
    MoveLimit                           = 1
    MoveLastLogonDateMoreThan           = 90
    MovePasswordLastSetMoreThan         = 90
    #MoveLastSeenAzureMoreThan    = 180
    #MoveLastSyncAzureMoreThan    = 180
    #MoveLastContactJamfMoreThan  = 180
    #MoveLastSeenIntuneMoreThan   = 180
    #MoveListProcessedMoreThan    = 90 # disabled computer has to spend 90 days in list before it can be deleted
    MoveIsEnabled                       = $false # Computer has to be disabled to be moved
    MoveTargetOrganizationalUnit        = @{
        'ad.evotec.xyz' = 'OU=Disabled,OU=Computers,OU=Devices,OU=Production,DC=ad,DC=evotec,DC=xyz'
        'ad.evotec.pl'  = 'OU=Disabled,OU=Computers,OU=Devices,OU=Production,DC=ad,DC=evotec,DC=pl'
    }

    # delete settings
    Delete                              = $true
    DeleteLimit                         = 2
    DeleteLastLogonDateMoreThan         = 180
    DeletePasswordLastSetMoreThan       = 180
    DeleteLastSeenAzureMoreThan         = 180
    #DeleteLastSyncAzureMoreThan    = 180
    #DeleteLastContactJamfMoreThan  = 180
    #DeleteLastSeenIntuneMoreThan   = 180
    #DeleteListProcessedMoreThan    = 90 # disabled computer has to spend 90 days in list before it can be deleted
    DeleteIsEnabled                     = $false # Computer has to be disabled to be deleted
    # global exclusions
    Exclusions                          = @(
        '*OU=Domain Controllers*' # exclude Domain Controllers
    )
    # filter for AD search
    Filter                              = '*'
    # logs, reports and datastores
    LogPath                             = "$PSScriptRoot\Logs\CleanupComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                       = "$PSScriptRoot\CleanupComputers_ListProcessed.xml"
    ReportPath                          = "$PSScriptRoot\Reports\CleanupComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    # WhatIf settings
    ReportOnly                          = $false
    WhatIfDisable                       = $true
    WhatIfMove                          = $true
    WhatIfDelete                        = $true
    ShowHTML                            = $true

    DontWriteToEventLog                 = $true
}

$Output = Invoke-ADComputersCleanup @invokeADComputersCleanupSplat
$Output