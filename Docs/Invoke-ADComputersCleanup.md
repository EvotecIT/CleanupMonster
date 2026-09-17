---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version: https://github.com/EvotecIT/CleanupMonster
schema: 2.0.0
---
# Invoke-ADComputersCleanup
## SYNOPSIS
Active Directory Cleanup function that can disable or delete computers
that have not been logged on for a certain amount of time.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-ADComputersCleanup [[-Forest] <string>] [[-IncludeDomains] <string[]>] [[-ExcludeDomains] <string[]>] [[-DisableAndMoveOrder] <string>] [[-DisableIsEnabled] <Boolean>] [[-DisableNoServicePrincipalName] <Boolean>] [[-DisableLastLogonDateMoreThan] <Int32>] [[-DisablePasswordLastSetMoreThan] <Int32>] [[-DisableRequireWhenCreatedMoreThan] <Int32>] [[-DisablePasswordLastSetOlderThan] <DateTime>] [[-DisableLastLogonDateOlderThan] <DateTime>] [[-DisableLastSeenAzureMoreThan] <Int32>] [[-DisableLastSeenIntuneMoreThan] <Int32>] [[-DisableLastSyncAzureMoreThan] <Int32>] [[-DisableLastContactJamfMoreThan] <Int32>] [[-DisableExcludeSystems] <array>] [[-DisableIncludeSystems] <array>] [[-DisableExcludeServicePrincipalName] <array>] [[-DisableIncludeServicePrincipalName] <array>] [[-DisableLimit] <int>] [[-DisableMoveTargetOrganizationalUnit] <Object>] [[-MoveIsEnabled] <Boolean>] [[-MoveNoServicePrincipalName] <Boolean>] [[-MoveLastLogonDateMoreThan] <Int32>] [[-MovePasswordLastSetMoreThan] <Int32>] [[-MoveListProcessedMoreThan] <Int32>] [[-MoveRequireWhenCreatedMoreThan] <Int32>] [[-MovePasswordLastSetOlderThan] <DateTime>] [[-MoveLastLogonDateOlderThan] <DateTime>] [[-MoveLastSeenAzureMoreThan] <Int32>] [[-MoveLastSeenIntuneMoreThan] <Int32>] [[-MoveLastSyncAzureMoreThan] <Int32>] [[-MoveLastContactJamfMoreThan] <Int32>] [[-MoveExcludeSystems] <array>] [[-MoveIncludeSystems] <array>] [[-MoveExcludeServicePrincipalName] <array>] [[-MoveIncludeServicePrincipalName] <array>] [[-MoveLimit] <int>] [[-MoveTargetOrganizationalUnit] <Object>] [[-DeleteIsEnabled] <Boolean>] [[-DeleteNoServicePrincipalName] <Boolean>] [[-DeleteLastLogonDateMoreThan] <Int32>] [[-DeletePasswordLastSetMoreThan] <Int32>] [[-DeleteRequireWhenCreatedMoreThan] <Int32>] [[-DeleteListProcessedMoreThan] <Int32>] [[-DeletePasswordLastSetOlderThan] <DateTime>] [[-DeleteLastLogonDateOlderThan] <DateTime>] [[-DeleteLastSeenAzureMoreThan] <Int32>] [[-DeleteLastSeenIntuneMoreThan] <Int32>] [[-DeleteLastSyncAzureMoreThan] <Int32>] [[-DeleteLastContactJamfMoreThan] <Int32>] [[-DeleteExcludeSystems] <array>] [[-DeleteIncludeSystems] <array>] [[-DeleteExcludeServicePrincipalName] <array>] [[-DeleteIncludeServicePrincipalName] <array>] [[-DeleteLimit] <int>] [[-Exclusions] <array>] [[-Filter] <Object>] [[-SearchBase] <Object>] [[-DataStorePath] <string>] [[-ReportMaximum] <int>] [[-LogPath] <string>] [[-LogMaximum] <int>] [[-LogTimeFormat] <string>] [[-ReportPath] <string>] [[-SafetyADLimit] <Int32>] [[-SafetyAzureADLimit] <Int32>] [[-SafetyIntuneLimit] <Int32>] [[-SafetyJamfLimit] <Int32>] [[-TargetServers] <Object>] [[-ADQueryMaxRetries] <int>] [[-ADQueryRetryDelay] <int>] [[-ADQueryConnectionTimeout] <int>] [[-ADQueryIdleTimeout] <int>] [[-ADQueryPageSize] <int>] [[-DomainFailureAction] <string>] [-Disable] [-DisableAndMove] [-DisableDoNotAddToPendingList] [-Move] [-Delete] [-DisableModifyDescription] [-DisableModifyAdminDescription] [-ReportOnly] [-WhatIfDelete] [-WhatIfDisable] [-WhatIfMove] [-LogShowTime] [-Suppress] [-ShowHTML] [-Online] [-DontWriteToEventLog] [-RemoveProtectedFromAccidentalDeletionFlag] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Active Directory Cleanup function that can disable or delete computers
that have not been logged on for a certain amount of time.
It has many options to customize the cleanup process.
When Azure AD or Intune integration is used, device matching tries AD name,
DNS host name, and samAccountName aliases so computers with truncated AD names can still match their cloud records.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > $Output = Invoke-ADComputersCleanup -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output
```


### EXAMPLE 2
```powershell
PS > $Output = Invoke-ADComputersCleanup -DeleteListProcessedMoreThan 100 -Disable -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output
```


### EXAMPLE 3
```powershell
PS > # this is a fresh run and it will provide report only according to it's defaults
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
$Output
```


### EXAMPLE 4
```powershell
PS > # this is a fresh run and it will try to disable computers according to it's defaults
# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Disable -ShowHTML -WhatIfDisable -WhatIfDelete -Delete
$Output
```


### EXAMPLE 5
```powershell
PS > # this is a fresh run and it will try to delete computers according to it's defaults
# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output
```


### EXAMPLE 6
```powershell
PS > # remove the protection flag only when a move or delete action actually needs it
$Output = Invoke-ADComputersCleanup -Disable -DisableAndMove -DisableMoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -RemoveProtectedFromAccidentalDeletionFlag -WhatIfDisable -ShowHTML
$Output
```


### EXAMPLE 7
```powershell
PS > # Configure retry parameters for large AD environments with enumeration context errors
$Configuration = @{
    Delete                = $true
    DeleteIsEnabled       = $false
    DeleteListProcessedMoreThan = 90
    ADQueryMaxRetries     = 5      # Increase retries for unreliable environments
    ADQueryRetryDelay     = 10     # Increase delay between retries
    ADQueryConnectionTimeout = 15  # Bound unavailable-DC connection attempts
    ADQueryIdleTimeout       = 120 # Stop a query that stops producing results
    ADQueryPageSize       = 500    # Smaller page size for large environments
    WhatIfDelete          = $true
    ShowHTML             = $true
    LogPath              = "$PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    ReportPath           = "$PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
}
$Output = Invoke-ADComputersCleanup @Configuration
$Output
```


### EXAMPLE 8
```powershell
PS > # Prefer two manually selected DCs per domain, retain detected DCs as fallbacks,
# and suppress every write if any domain still cannot be inventoried.
$TargetServers = @{
    'contoso.com'       = @('dc1.contoso.com', 'dc2.contoso.com')
    'child.contoso.com' = @('dc1.child.contoso.com', 'dc2.child.contoso.com')
}
Invoke-ADComputersCleanup -Disable -TargetServers $TargetServers -DomainFailureAction Stop -ShowHTML
```


### EXAMPLE 9
```powershell
PS > # Run the script
$Configuration = @{
    Disable                        = $true
    DisableNoServicePrincipalName  = $null
    DisableIsEnabled               = $true
    DisableLastLogonDateMoreThan   = 90
    DisablePasswordLastSetMoreThan = 90
    DisableExcludeSystems          = @(
        # 'Windows Server*'
    )
    DisableIncludeSystems          = @()
    DisableLimit                   = 2 # 0 means unlimited, ignored for reports
    DisableModifyDescription       = $false
    DisableAdminModifyDescription  = $true
    Delete                         = $true
    DeleteIsEnabled                = $false
    DeleteNoServicePrincipalName   = $null
    DeleteLastLogonDateMoreThan    = 180
    DeletePasswordLastSetMoreThan  = 180
    DeleteListProcessedMoreThan    = 90 # 90 days since computer was added to list
    DeleteExcludeSystems           = @(
        # 'Windows Server*'
    )
    DeleteIncludeSystems           = @(
    )
    DeleteLimit                    = 2 # 0 means unlimited, ignored for reports
    Exclusions                     = @(
        '*OU=Domain Controllers*'
        '*OU=Servers,OU=Production*'
        'EVOMONSTER$'
        'EVOMONSTER.AD.EVOTEC.XYZ'
    )
    Filter                         = '*'
    WhatIfDisable                  = $true
    WhatIfDelete                   = $true
    LogPath                        = "$PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                  = "$PSScriptRoot\DeleteComputers_ListProcessed.xml"
    ReportPath                     = "$PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                       = $true
}
# Run one time as admin: Write-EVXEvent -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers' -CreateSource
$Output = Invoke-ADComputersCleanup @Configuration
$Output
```


## PARAMETERS

### -ADQueryConnectionTimeout
Maximum number of seconds allowed for the isolated AD query process to connect to a domain controller before retrying or failing over. Default is 15.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 72
Default value: 15
Accept pipeline input: False
Accept wildcard characters: False
```

### -ADQueryIdleTimeout
Maximum number of seconds an established AD inventory query may make no result progress before its isolated process is stopped and the query is retried or failed over. This is an idle timeout, not a limit on the total time required to return a large domain. Default is 120.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 73
Default value: 120
Accept pipeline input: False
Accept wildcard characters: False
```

### -ADQueryMaxRetries
Maximum number of query attempts per domain controller before failing over to the next server. Default is 3.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 70
Default value: 3
Accept pipeline input: False
Accept wildcard characters: False
```

### -ADQueryPageSize
Page size for AD query operations. Default is 1000.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 74
Default value: 1000
Accept pipeline input: False
Accept wildcard characters: False
```

### -ADQueryRetryDelay
Delay in seconds between retries for AD query operations. Default is 5.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 71
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -DataStorePath
Path to the XML file that will be used to store the list of processed computers, current run, and history data.
Default is $PSScriptRoot\ProcessedComputers.xml

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 59
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Delete
Enable the delete process, meaning the computers that meet the criteria will be deleted.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteExcludeServicePrincipalName
Delete computer only if it's not on the list of excluded ServicePrincipalNames.
You can also specify multiple ServicePrincipalNames by providing an array of entries.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 53
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteExcludeSystems
Delete computer only if it's not on the list of excluded operating systems.
If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.
It's using OperatingSystem property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 51
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIncludeServicePrincipalName
Delete computer only if it's on the list of included ServicePrincipalNames.
You can also specify multiple ServicePrincipalNames by providing an array of entries.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 54
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIncludeSystems
Delete computer only if it's on the list of included operating systems.
If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 52
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIsEnabled
Delete computer only if it's Enabled or only if it's Disabled.
By default it will try to delete all computers that are either disabled or enabled.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 39
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastContactJamfMoreThan
Delete computer only if it Last Contacted in Jamf is more than the specified number of days.
Please note that you need to make connection to Jamf using PowerJamf PowerShell Module first.
Additionally you will need PowerJamf PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 50
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastLogonDateMoreThan
Delete computer only if it has a LastLogonDate that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 41
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastLogonDateOlderThan
Delete computer only if it has a LastLogonDate that is older than the specified date.

```yaml
Type: DateTime
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 46
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastSeenAzureMoreThan
Delete computer only if it Last Seen in Azure is more than the specified number of days.
Please note that you need to make connection to Azure using Connect-MgGraph with proper permissions first.
Additionally yopu will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 47
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastSeenIntuneMoreThan
Delete computer only if it Last Seen in Intune is more than the specified number of days.
Please note that you need to make connection to Intune using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 48
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastSyncAzureMoreThan
Delete computer only if it Last Synced in Azure is more than the specified number of days.
Please note that you need to make connection to Azure AD using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 49
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLimit
Limit the number of computers that will be deleted. 0 = unlimited. Default is 1.
This is to prevent accidental deletion of all computers that meet the criteria.
Adjust the limit to your needs.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 55
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteListProcessedMoreThan
Delete computer only if it has been processed by this script more than the specified number of days ago.
This is useful if you want to delete computers that have been disabled for a certain amount of time.
It uses XML file to store the list of processed computers, so please make sure to not remove it or it will start over.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 44
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteNoServicePrincipalName
Delete computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
By default it doesn't care if it has a ServicePrincipalName or not.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 40
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeletePasswordLastSetMoreThan
Delete computer only if it has a PasswordLastSet that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 42
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeletePasswordLastSetOlderThan
Delete computer only if it has a PasswordLastSet that is older than the specified date.

```yaml
Type: DateTime
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 45
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteRequireWhenCreatedMoreThan
Delete computer only if it was created more than the specified number of days ago.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 43
Default value: 90
Accept pipeline input: False
Accept wildcard characters: False
```

### -Disable
Enable the disable process, meaning the computers that meet the criteria will be disabled.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableAndMove
Enable the disable and move process, meaning the computers that meet the criteria will be disabled and moved (in that order).
This is useful if you want to disable computers first and then move them to a different OU right after.
It's integral part of disabling process.
If you want Move as a separate process, use Move settings.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableAndMoveOrder
Order of the Disable and Move process. Default is 'DisableAndMove'.
If you want to move computers first and then disable them, use 'MoveAndDisable'.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: DisableAndMove, MoveAndDisable

Required: False
Position: 3
Default value: DisableAndMove
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableDoNotAddToPendingList
By default, computers that are disabled are added to the list of computers that will be actioned later (moved/deleted).
If you want to disable computers, but not add them to the list of computers that will be actioned later (aka pending list),  use this switch.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableExcludeServicePrincipalName
Disable computer only if it's not on the list of excluded ServicePrincipalNames.
You can also specify multiple ServicePrincipalNames by providing an array of entries.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 17
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableExcludeSystems
Disable computer only if it's not on the list of excluded operating systems.
If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*' or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.
It's using OperatingSystem property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 15
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIncludeServicePrincipalName
Disable computer only if it's on the list of included ServicePrincipalNames.
You can also specify multiple ServicePrincipalNames by providing an array of entries.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 18
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIncludeSystems
Disable computer only if it's on the list of included operating systems.
If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 16
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIsEnabled
Disable computer only if it's Enabled or only if it's Disabled.
By default it will try to disable all computers that are either disabled or enabled.
While counter-intuitive for already disabled computers,
this is useful if you want preproceess computers for deletion and need to get them on the list.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastContactJamfMoreThan
Disable computer only if it Last Contacted in Jamf is more than the specified number of days.
Please note that you need to make connection to Jamf using PowerJamf PowerShell Module first.
Additionally you will need PowerJamf PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 14
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastLogonDateMoreThan
Disable computer only if it has a LastLogonDate that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 6
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastLogonDateOlderThan
Disable computer only if it has a LastLogonDate that is older than the specified date.

```yaml
Type: DateTime
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastSeenAzureMoreThan
Disable computer only if it Last Seen in Azure is more than the specified number of days.
Please note that you need to make connection to Azure using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 11
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastSeenIntuneMoreThan
Disable computer only if it Last Seen in Intune is more than the specified number of days.
Please note that you need to make connection to Intune using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastSyncAzureMoreThan
Disable computer only if it Last Synced in Azure is more than the specified number of days.
Please note that you need to make connection to Azure AD using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLimit
Limit the number of computers that will be disabled. 0 = unlimited. Default is 1.
This is to prevent accidental disabling of all computers that meet the criteria.
Adjust the limit to your needs.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 19
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableModifyAdminDescription
Modify the admin description of the computer object to include the date and time when it was disabled.
By default it will not modify the admin description.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: DisableAdminModifyDescription
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableModifyDescription
Modify the description of the computer object to include the date and time when it was disabled.
By default it will not modify the description.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableMoveTargetOrganizationalUnit
Move computer to the specified OU after it's disabled.
It can take a string with DistinguishedName, or hashtable with key being the domain, and value being the DistinguishedName.
If you have a forest with multiple domains and want to move computers to different OUs based on their domain, you can use hashtable.

```yaml
Type: Object
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 20
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableNoServicePrincipalName
Disable computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
By default it doesn't care if it has a ServicePrincipalName or not.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisablePasswordLastSetMoreThan
Disable computer only if it has a PasswordLastSet that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 7
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisablePasswordLastSetOlderThan
Disable computer only if it has a PasswordLastSet that is older than the specified date.

```yaml
Type: DateTime
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableRequireWhenCreatedMoreThan
Disable computer only if it was created more than the specified number of days ago.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 8
Default value: 90
Accept pipeline input: False
Accept wildcard characters: False
```

### -DomainFailureAction
Controls write behavior when one or more domains cannot be inventoried.
Stop is the safe default and suppresses all mutations while still producing an incomplete report.
ContinueSuccessfulDomains explicitly allows actions for successfully inventoried domains only.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Stop, ContinueSuccessfulDomains

Required: False
Position: 75
Default value: Stop
Accept pipeline input: False
Accept wildcard characters: False
```

### -DontWriteToEventLog
By default the function will write to the event log making sure the cleanup process is logged.
This parameter will prevent the function from writing to the event log.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeDomains
List of domains to exclude from the process.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclusions
List of computers to exclude from the process.
You can specify multiple computers by separating them with a comma.
It's using the -like operator, so you can use wildcards.
You can use SamAccoutName (remember about ending $), DistinguishedName,
or DNSHostName property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 56
Default value: @(
            # default globalexclusions
            '*OU=Domain Controllers*'
        )
Accept pipeline input: False
Accept wildcard characters: False
```

### -Filter
Filter to use when searching for computers in Get-ADComputer cmdlet.
Default is '*'

```yaml
Type: Object
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 57
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -Forest
Forest to use when connecting to Active Directory.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeDomains
List of domains to include in the process.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: Domain
Possible values:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogMaximum
Maximum number of log files to keep. Default is 5.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 62
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
Path to the log file. Default is no logging to file.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 61
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogShowTime
Show time in the log file. Default is $false

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogTimeFormat
Time format to use when logging to file. Default is 'yyyy-MM-dd HH:mm:ss'

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 63
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Move
Enable the move process, meaning computers that meet the move criteria will be moved to MoveTargetOrganizationalUnit.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveExcludeServicePrincipalName
Move computer only if it's not on the list of excluded ServicePrincipalNames.
You can also specify multiple ServicePrincipalNames by providing an array of entries.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 35
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveExcludeSystems
Move computer only if it's not on the list of excluded operating systems.
If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.
It's using OperatingSystem property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 33
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveIncludeServicePrincipalName
Move computer only if it's on the list of included ServicePrincipalNames.
You can also specify multiple ServicePrincipalNames by providing an array of entries.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 36
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveIncludeSystems
Move computer only if it's on the list of included operating systems.
If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 34
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveIsEnabled
Move computer only if it's Enabled or only if it's Disabled.
By default it will try to Move all computers that are either disabled or enabled.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 21
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLastContactJamfMoreThan
Move computer only if it Last Contacted in Jamf is more than the specified number of days.
Please note that you need to make connection to Jamf using PowerJamf PowerShell Module first.
Additionally you will need PowerJamf PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 32
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLastLogonDateMoreThan
Move computer only if it has a LastLogonDate that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 23
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLastLogonDateOlderThan
Move computer only if it has a LastLogonDate that is older than the specified date.

```yaml
Type: DateTime
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 28
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLastSeenAzureMoreThan
Move computer only if it Last Seen in Azure is more than the specified number of days.
Please note that you need to make connection to Azure using Connect-MgGraph with proper permissions first.
Additionally yopu will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 29
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLastSeenIntuneMoreThan
Move computer only if it Last Seen in Intune is more than the specified number of days.
Please note that you need to make connection to Intune using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 30
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLastSyncAzureMoreThan
Move computer only if it Last Synced in Azure is more than the specified number of days.
Please note that you need to make connection to Azure AD using Connect-MgGraph with proper permissions first.
Additionally you will need GraphEssentials PowerShell Module installed.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 31
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveLimit
Limit the number of computers that will be moved. 0 = unlimited. Default is 1.
This is to prevent accidental move of all computers that meet the criteria.
Adjust the limit to your needs.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 37
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveListProcessedMoreThan
Move computer only if it has been processed by this script more than the specified number of days ago.
This is useful if you want to Move computers that have been disabled for a certain amount of time.
It uses XML file to store the list of processed computers, so please make sure to not remove it or it will start over.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 25
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveNoServicePrincipalName
Move computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
By default it doesn't care if it has a ServicePrincipalName or not.

```yaml
Type: Boolean
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 22
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MovePasswordLastSetMoreThan
Move computer only if it has a PasswordLastSet that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 24
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MovePasswordLastSetOlderThan
Move computer only if it has a PasswordLastSet that is older than the specified date.

```yaml
Type: DateTime
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 27
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveRequireWhenCreatedMoreThan
Move computer only if it was created more than the specified number of days ago.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 26
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MoveTargetOrganizationalUnit
Target Organizational Unit where the computer will be moved as part of Move action.
It can take a string with DistinguishedName, or hashtable with key being the domain, and value being the DistinguishedName.
If you have a forest with multiple domains and want to move computers to different OUs based on their domain, you can use hashtable.

```yaml
Type: Object
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 38
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Online
Online parameter causes HTML report to use CDN for CSS and JS files.
This can be useful to minimize the size of the HTML report.
Otherwise the report will start with at least 2MB in size.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveProtectedFromAccidentalDeletionFlag
Remove the ProtectedFromAccidentalDeletion flag from the computer object before moving or deleting it.
Disable-only workflows leave the flag untouched.
By default it will not remove the flag, and require it to be removed manually.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportMaximum
Maximum number of reports to keep. Default is Unlimited (0).

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 60
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportOnly
Only generate the report, don't disable or delete computers.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportPath
Path to the HTML report file. Default is $PSScriptRoot\ProcessedComputers.html

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 64
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyADLimit
Minimum number of computers that must be returned by AD cmdlets before mutations are allowed.
Default is not to check.
If the limit is not met, mutations are suppressed and the HTML report is still generated.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 65
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyAzureADLimit
Minimum number of computers that must be returned by AzureAD cmdlets to proceed with the process.
Default is not to check.
This is there to prevent accidental deletion of all computers if there is a problem with AzureAD.
It only applies if Azure AD parameters are used.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 66
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyIntuneLimit
Minimum number of computers that must be returned by Intune cmdlets to proceed with the process.
Default is not to check.
This is there to prevent accidental deletion of all computers if there is a problem with Intune.
It only applies if Intune parameters are used.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 67
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyJamfLimit
Minimum number of computers that must be returned by Jamf cmdlets to proceed with the process.
Default is not to check.
This is there to prevent accidental deletion of all computers if there is a problem with Jamf.
It only applies if Jamf parameters are used.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 68
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SearchBase
SearchBase to use when searching for computers in Get-ADComputer cmdlet.
Default is not set. It will search the whole domain.
You can provide a string or hashtable of domains with their SearchBase.

```yaml
Type: Object
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 58
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowHTML
Show HTML report in the browser once the function is complete

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Suppress
Suppress output of the object and only display to console

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetServers
Target servers to use when connecting to Active Directory.
It can take one server name, an array of server names, or a hashtable whose keys are domains and whose values are one or more server names.
Manually configured servers are tried in order before auto-detected writable domain controllers.

```yaml
Type: Object
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 69
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDelete
WhatIf parameter for the Delete process.
It's not nessessary to specify this parameter if you use WhatIf parameter which applies to all processes.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDisable
WhatIf parameter for the Disable process.
It's not nessessary to specify this parameter if you use WhatIf parameter which applies to all processes.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfMove
WhatIf parameter for the Move process.
It's not nessessary to specify this parameter if you use WhatIf parameter which applies to all processes.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
