Import-Module .\CleanupMonster.psd1 -Force

# connect to graph for Email sending
Connect-MgGraph -Scopes Mail.Send -NoWelcome

$invokeADComputersCleanupSplat = @{
    #ExcludeDomains                      = 'ad.evotec.xyz'
    # safety limits (minimum amount of computers that has to be returned from each source)
    SafetyADLimit                       = 30
    #SafetyAzureADLimit                  = 5
    #SafetyIntuneLimit                   = 3
    #SafetyJamfLimit                     = 50
    # disable settings
    Disable                             = $true
    DisableAndMove                      = $true
    DisableAndMoveOrder                 = 'MoveAndDisable' # DisableAndMove, MoveAndDisable
    #DisableIsEnabled                    = $true
    DisableLimit                        = 1
    DisableLastLogonDateMoreThan        = 90
    DisablePasswordLastSetMoreThan      = 2280
    #DisableLastSeenAzureMoreThan        = 90
    DisableRequireWhenCreatedMoreThan   = 90
    #DisablePasswordLastSetOlderThan     = Get-Date -Year 2023 -Month 1 -Day 1
    #DisableLastSyncAzureMoreThan   = 90
    #DisableLastContactJamfMoreThan = 90
    #DisableLastSeenIntuneMoreThan       = 90
    DisableMoveTargetOrganizationalUnit = @{
        'ad.evotec.xyz' = 'OU=Disabled,OU=Computers,OU=Devices,OU=Production,DC=ad,DC=evotec,DC=xyz'
        'ad.evotec.pl'  = 'OU=Disabled,OU=Computers,OU=Devices,OU=Production,DC=ad,DC=evotec,DC=pl'
    }
    SearchBase                          = @{
        'ad.evotec.xyz' = 'DC=ad,DC=evotec,DC=xyz'
        'ad.evotec.pl'  = 'DC=ad,DC=evotec,DC=pl'
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
    Delete                              = $false
    DeleteLimit                         = 2
    DeleteLastLogonDateMoreThan         = 180
    DeletePasswordLastSetMoreThan       = 180
    #DeleteLastSeenAzureMoreThan         = 180
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

# Now lets send email using Graph
[Array] $DisabledObjects = $Output.CurrentRun | Where-Object { $_.Action -eq 'Disable' }
[Array] $DeletedObjects = $Output.CurrentRun | Where-Object { $_.Action -eq 'Delete' }

$EmailBody = EmailBody -EmailBody {
    EmailText -Text "Hello,"

    EmailText -LineBreak

    EmailText -Text "This is an automated email from Automations run on ", $Env:COMPUTERNAME, " on ", (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), " by ", $Env:UserName -Color None, Green, None, Green, None, Green -FontWeight normal, bold, normal, bold, normal, bold

    EmailText -LineBreak

    EmailText -Text "Following is a summary for the computer object cleanup:" -FontWeight bold
    EmailList {
        EmailListItem -Text "Objects actioned: ", $Output.CurrentRun.Count -Color None, Green -FontWeight normal, bold
        EmailListItem -Text "Objects deleted: ", $DeletedObjects.Count -Color None, Salmon -FontWeight normal, bold
        EmailListItem -Text "Objects disabled: ", $DisabledObjects.Count -Color None, Orange -FontWeight normal, bold
    }

    EmailText -Text "Following objects were actioned:" -LineBreak -FontWeight bold -Color Salmon
    EmailTable -DataTable $Output.CurrentRun -HideFooter {
        New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace -Inline
        New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow -Inline
        New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen -Inline
        New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon -Inline
        New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue -Inline
    }

    EmailText -LineBreak

    EmailText -Text "Regards,"
    EmailText -Text "Automations Team" -FontWeight bold
}
#Save-Html -HTML $EmailBody -ShowHTML
# send email using Mailozaurr
#Send-EmailMessage -To 'przemyslaw.klys@test.pl' -From 'przemyslaw.klys@test.pl' -MgGraphRequest -Subject "Automated Computer Cleanup Report" -Body $EmailBody -Priority Low -Verbose -WhatIf