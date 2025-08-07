function Invoke-ADComputersCleanup {
    <#
    .SYNOPSIS
    Active Directory Cleanup function that can disable or delete computers
    that have not been logged on for a certain amount of time.

    .DESCRIPTION
    Active Directory Cleanup function that can disable or delete computers
    that have not been logged on for a certain amount of time.
    It has many options to customize the cleanup process.

    .PARAMETER Forest
    Forest to use when connecting to Active Directory.

    .PARAMETER IncludeDomains
    List of domains to include in the process.

    .PARAMETER ExcludeDomains
    List of domains to exclude from the process.

    .PARAMETER Disable
    Enable the disable process, meaning the computers that meet the criteria will be disabled.

    .PARAMETER DisableAndMove
    Enable the disable and move process, meaning the computers that meet the criteria will be disabled and moved (in that order).
    This is useful if you want to disable computers first and then move them to a different OU right after.
    It's integral part of disabling process.
    If you want Move as a separate process, use Move settings.

    .PARAMETER DisableAndMoveOrder
    Order of the Disable and Move process. Default is 'DisableAndMove'.
    If you want to move computers first and then disable them, use 'MoveAndDisable'.

    .PARAMETER DisableIsEnabled
    Disable computer only if it's Enabled or only if it's Disabled.
    By default it will try to disable all computers that are either disabled or enabled.
    While counter-intuitive for already disabled computers,
    this is useful if you want preproceess computers for deletion and need to get them on the list.

    .PARAMETER DisableNoServicePrincipalName
    Disable computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
    By default it doesn't care if it has a ServicePrincipalName or not.

    .PARAMETER DisableLastLogonDateMoreThan
    Disable computer only if it has a LastLogonDate that is more than the specified number of days.

    .PARAMETER DisablePasswordLastSetMoreThan
    Disable computer only if it has a PasswordLastSet that is more than the specified number of days.

    .PARAMETER DisableRequireWhenCreatedMoreThan
    Disable computer only if it was created more than the specified number of days ago.

    .PARAMETER DisablePasswordLastSetOlderThan
    Disable computer only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER DisableLastLogonDateOlderThan
    Disable computer only if it has a LastLogonDate that is older than the specified date.

    .PARAMETER DisableLastSeenAzureMoreThan
    Disable computer only if it Last Seen in Azure is more than the specified number of days.
    Please note that you need to make connection to Azure using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER DisableLastSeenIntuneMoreThan
    Disable computer only if it Last Seen in Intune is more than the specified number of days.
    Please note that you need to make connection to Intune using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER DisableLastSyncAzureMoreThan
    Disable computer only if it Last Synced in Azure is more than the specified number of days.
    Please note that you need to make connection to Azure AD using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER DisableLastContactJamfMoreThan
    Disable computer only if it Last Contacted in Jamf is more than the specified number of days.
    Please note that you need to make connection to Jamf using PowerJamf PowerShell Module first.
    Additionally you will need PowerJamf PowerShell Module installed.

    .PARAMETER DisableExcludeSystems
    Disable computer only if it's not on the list of excluded operating systems.
    If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*' or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
    You can also specify multiple operating systems by separating them with a comma.
    It's using the -like operator, so you can use wildcards.
    It's using OperatingSystem property of the computer object for comparison.

    .PARAMETER DisableIncludeSystems
    Disable computer only if it's on the list of included operating systems.
    If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
    or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
    You can also specify multiple operating systems by separating them with a comma.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER DisableExcludeServicePrincipalName
    Disable computer only if it's not on the list of excluded ServicePrincipalNames.
    You can also specify multiple ServicePrincipalNames by providing an array of entries.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER DisableIncludeServicePrincipalName
    Disable computer only if it's on the list of included ServicePrincipalNames.
    You can also specify multiple ServicePrincipalNames by providing an array of entries.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER DisableMoveTargetOrganizationalUnit
    Move computer to the specified OU after it's disabled.
    It can take a string with DistinguishedName, or hashtable with key being the domain, and value being the DistinguishedName.
    If you have a forest with multiple domains and want to move computers to different OUs based on their domain, you can use hashtable.

    .PARAMETER DisableDoNotAddToPendingList
    By default, computers that are disabled are added to the list of computers that will be actioned later (moved/deleted).
    If you want to disable computers, but not add them to the list of computers that will be actioned later (aka pending list),  use this switch.

    .PARAMETER Delete
    Enable the delete process, meaning the computers that meet the criteria will be deleted.

    .PARAMETER DeleteIsEnabled
    Delete computer only if it's Enabled or only if it's Disabled.
    By default it will try to delete all computers that are either disabled or enabled.

    .PARAMETER DeleteNoServicePrincipalName
    Delete computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
    By default it doesn't care if it has a ServicePrincipalName or not.

    .PARAMETER DeleteLastLogonDateMoreThan
    Delete computer only if it has a LastLogonDate that is more than the specified number of days.

    .PARAMETER DeletePasswordLastSetMoreThan
    Delete computer only if it has a PasswordLastSet that is more than the specified number of days.

    .PARAMETER DeleteRequireWhenCreatedMoreThan
    Delete computer only if it was created more than the specified number of days ago.

    .PARAMETER DeleteListProcessedMoreThan
    Delete computer only if it has been processed by this script more than the specified number of days ago.
    This is useful if you want to delete computers that have been disabled for a certain amount of time.
    It uses XML file to store the list of processed computers, so please make sure to not remove it or it will start over.

    .PARAMETER DeletePasswordLastSetOlderThan
    Delete computer only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER DeleteLastLogonDateOlderThan
    Delete computer only if it has a LastLogonDate that is older than the specified date.

    .PARAMETER DeleteLastSeenAzureMoreThan
    Delete computer only if it Last Seen in Azure is more than the specified number of days.
    Please note that you need to make connection to Azure using Connect-MgGraph with proper permissions first.
    Additionally yopu will need GraphEssentials PowerShell Module installed.

    .PARAMETER DeleteLastSeenIntuneMoreThan
    Delete computer only if it Last Seen in Intune is more than the specified number of days.
    Please note that you need to make connection to Intune using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER DeleteLastSyncAzureMoreThan
    Delete computer only if it Last Synced in Azure is more than the specified number of days.
    Please note that you need to make connection to Azure AD using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER DeleteLastContactJamfMoreThan
    Delete computer only if it Last Contacted in Jamf is more than the specified number of days.
    Please note that you need to make connection to Jamf using PowerJamf PowerShell Module first.
    Additionally you will need PowerJamf PowerShell Module installed.

    .PARAMETER DeleteExcludeSystems
    Delete computer only if it's not on the list of excluded operating systems.
    If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*'
    or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
    You can also specify multiple operating systems by separating them with a comma.
    It's using the -like operator, so you can use wildcards.
    It's using OperatingSystem property of the computer object for comparison.

    .PARAMETER DeleteIncludeSystems
    Delete computer only if it's on the list of included operating systems.
    If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
    or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
    You can also specify multiple operating systems by separating them with a comma.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER DeleteExcludeServicePrincipalName
    Delete computer only if it's not on the list of excluded ServicePrincipalNames.
    You can also specify multiple ServicePrincipalNames by providing an array of entries.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER DeleteIncludeServicePrincipalName
    Delete computer only if it's on the list of included ServicePrincipalNames.
    You can also specify multiple ServicePrincipalNames by providing an array of entries.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER DeleteLimit
    Limit the number of computers that will be deleted. 0 = unlimited. Default is 1.
    This is to prevent accidental deletion of all computers that meet the criteria.
    Adjust the limit to your needs.

    .PARAMETER MoveIsEnabled
    Move computer only if it's Enabled or only if it's Disabled.
    By default it will try to Move all computers that are either disabled or enabled.

    .PARAMETER MoveNoServicePrincipalName
    Move computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
    By default it doesn't care if it has a ServicePrincipalName or not.

    .PARAMETER MoveLastLogonDateMoreThan
    Move computer only if it has a LastLogonDate that is more than the specified number of days.

    .PARAMETER MovePasswordLastSetMoreThan
    Move computer only if it has a PasswordLastSet that is more than the specified number of days.

    .PARAMETER MoveListProcessedMoreThan
    Move computer only if it has been processed by this script more than the specified number of days ago.
    This is useful if you want to Move computers that have been disabled for a certain amount of time.
    It uses XML file to store the list of processed computers, so please make sure to not remove it or it will start over.

    .PARAMETER MovePasswordLastSetOlderThan
    Move computer only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER MoveRequireWhenCreatedMoreThan
    Move computer only if it was created more than the specified number of days ago.

    .PARAMETER MoveLastLogonDateOlderThan
    Move computer only if it has a LastLogonDate that is older than the specified date.

    .PARAMETER MoveLastSeenAzureMoreThan
    Move computer only if it Last Seen in Azure is more than the specified number of days.
    Please note that you need to make connection to Azure using Connect-MgGraph with proper permissions first.
    Additionally yopu will need GraphEssentials PowerShell Module installed.

    .PARAMETER MoveLastSeenIntuneMoreThan
    Move computer only if it Last Seen in Intune is more than the specified number of days.
    Please note that you need to make connection to Intune using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER MoveLastSyncAzureMoreThan
    Move computer only if it Last Synced in Azure is more than the specified number of days.
    Please note that you need to make connection to Azure AD using Connect-MgGraph with proper permissions first.
    Additionally you will need GraphEssentials PowerShell Module installed.

    .PARAMETER MoveLastContactJamfMoreThan
    Move computer only if it Last Contacted in Jamf is more than the specified number of days.
    Please note that you need to make connection to Jamf using PowerJamf PowerShell Module first.
    Additionally you will need PowerJamf PowerShell Module installed.

    .PARAMETER MoveExcludeSystems
    Move computer only if it's not on the list of excluded operating systems.
    If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*'
    or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
    You can also specify multiple operating systems by separating them with a comma.
    It's using the -like operator, so you can use wildcards.
    It's using OperatingSystem property of the computer object for comparison.

    .PARAMETER MoveIncludeSystems
    Move computer only if it's on the list of included operating systems.
    If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
    or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
    You can also specify multiple operating systems by separating them with a comma.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER MoveExcludeServicePrincipalName
    Move computer only if it's not on the list of excluded ServicePrincipalNames.
    You can also specify multiple ServicePrincipalNames by providing an array of entries.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER MoveIncludeServicePrincipalName
    Move computer only if it's on the list of included ServicePrincipalNames.
    You can also specify multiple ServicePrincipalNames by providing an array of entries.
    It's using the -like operator, so you can use wildcards.

    .PARAMETER MoveTargetOrganizationalUnit
    Target Organizational Unit where the computer will be moved as part of Move action.
    It can take a string with DistinguishedName, or hashtable with key being the domain, and value being the DistinguishedName.
    If you have a forest with multiple domains and want to move computers to different OUs based on their domain, you can use hashtable.

    .PARAMETER MoveLimit
    Limit the number of computers that will be moved. 0 = unlimited. Default is 1.
    This is to prevent accidental move of all computers that meet the criteria.
    Adjust the limit to your needs.

    .PARAMETER MoveDoNotAddToPendingList
    By default the script will add computers that are moved to a list of computers that will be actioned later (deleted).
    If you want to move computers, but not add them to the list of computers that will be action later (aka pending list),  use this switch.

    .PARAMETER DeleteLimit
    Limit the number of computers that will be deleted. 0 = unlimited. Default is 1.
    This is to prevent accidental deletion of all computers that meet the criteria.
    Adjust the limit to your needs.

    .PARAMETER DisableLimit
    Limit the number of computers that will be disabled. 0 = unlimited. Default is 1.
    This is to prevent accidental disabling of all computers that meet the criteria.
    Adjust the limit to your needs.

    .PARAMETER Exclusions
    List of computers to exclude from the process.
    You can specify multiple computers by separating them with a comma.
    It's using the -like operator, so you can use wildcards.
    You can use SamAccoutName (remember about ending $), DistinguishedName,
    or DNSHostName property of the computer object for comparison.

    .PARAMETER DisableModifyDescription
    Modify the description of the computer object to include the date and time when it was disabled.
    By default it will not modify the description.

    .PARAMETER DisableModifyAdminDescription
    Modify the admin description of the computer object to include the date and time when it was disabled.
    By default it will not modify the admin description.

    .PARAMETER Filter
    Filter to use when searching for computers in Get-ADComputer cmdlet.
    Default is '*'

    .PARAMETER SearchBase
    SearchBase to use when searching for computers in Get-ADComputer cmdlet.
    Default is not set. It will search the whole domain.
    You can provide a string or hashtable of domains with their SearchBase.

    .PARAMETER DataStorePath
    Path to the XML file that will be used to store the list of processed computers, current run, and history data.
    Default is $PSScriptRoot\ProcessedComputers.xml

    .PARAMETER ReportOnly
    Only generate the report, don't disable or delete computers.

    .PARAMETER ReportMaximum
    Maximum number of reports to keep. Default is Unlimited (0).

    .PARAMETER WhatIfDelete
    WhatIf parameter for the Delete process.
    It's not nessessary to specify this parameter if you use WhatIf parameter which applies to all processes.

    .PARAMETER WhatIfDisable
    WhatIf parameter for the Disable process.
    It's not nessessary to specify this parameter if you use WhatIf parameter which applies to all processes.

    .PARAMETER WhatIfMove
    WhatIf parameter for the Move process.
    It's not nessessary to specify this parameter if you use WhatIf parameter which applies to all processes.

    .PARAMETER LogPath
    Path to the log file. Default is no logging to file.

    .PARAMETER LogMaximum
    Maximum number of log files to keep. Default is 5.

    .PARAMETER LogShowTime
    Show time in the log file. Default is $false

    .PARAMETER LogTimeFormat
    Time format to use when logging to file. Default is 'yyyy-MM-dd HH:mm:ss'

    .PARAMETER Suppress
    Suppress output of the object and only display to console

    .PARAMETER ShowHTML
    Show HTML report in the browser once the function is complete

    .PARAMETER Online
    Online parameter causes HTML report to use CDN for CSS and JS files.
    This can be useful to minimize the size of the HTML report.
    Otherwise the report will start with at least 2MB in size.

    .PARAMETER ReportPath
    Path to the HTML report file. Default is $PSScriptRoot\ProcessedComputers.html

    .PARAMETER SafetyADLimit
    Minimum number of computers that must be returned by AD cmdlets to proceed with the process.
    Default is not to check.
    This is there to prevent accidental deletion of all computers if there is a problem with AD.

    .PARAMETER SafetyAzureADLimit
    Minimum number of computers that must be returned by AzureAD cmdlets to proceed with the process.
    Default is not to check.
    This is there to prevent accidental deletion of all computers if there is a problem with AzureAD.
    It only applies if Azure AD parameters are used.

    .PARAMETER SafetyIntuneLimit
    Minimum number of computers that must be returned by Intune cmdlets to proceed with the process.
    Default is not to check.
    This is there to prevent accidental deletion of all computers if there is a problem with Intune.
    It only applies if Intune parameters are used.

    .PARAMETER SafetyJamfLimit
    Minimum number of computers that must be returned by Jamf cmdlets to proceed with the process.
    Default is not to check.
    This is there to prevent accidental deletion of all computers if there is a problem with Jamf.
    It only applies if Jamf parameters are used.

    .PARAMETER DontWriteToEventLog
    By default the function will write to the event log making sure the cleanup process is logged.
    This parameter will prevent the function from writing to the event log.

    .PARAMETER TargetServers
    Target servers to use when connecting to Active Directory.
    It can take a string with server name, or hashtable with key being the domain, and value being the server name.
    If you have a forest with multiple domains and want to use different servers for different domains, you can use hashtable.
    It will use the default server if no server is provided for a domain, which is default approach.
    This feature is only nessecary if you have specific requirments per domain/forest rather than using the automatic detection.

    .PARAMETER RemoveProtectedFromAccidentalDeletionFlag
    Remove the ProtectedFromAccidentalDeletion flag from the computer object before disabling, moving, or deleting it.
    By default it will not remove the flag, and require it to be removed manually.

    .PARAMETER ADQueryMaxRetries
    Maximum number of retries for AD query operations. Default is 3.

    .PARAMETER ADQueryRetryDelay
    Delay in seconds between retries for AD query operations. Default is 5.

    .PARAMETER ADQueryPageSize
    Page size for AD query operations. Default is 1000.

    .EXAMPLE
    $Output = Invoke-ADComputersCleanup -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
    $Output

    .EXAMPLE
    $Output = Invoke-ADComputersCleanup -DeleteListProcessedMoreThan 100 -Disable -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
    $Output

    .EXAMPLE
    # this is a fresh run and it will provide report only according to it's defaults
    $Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
    $Output

    .EXAMPLE
    # this is a fresh run and it will try to disable computers according to it's defaults
    # read documentation to understand what it does
    $Output = Invoke-ADComputersCleanup -Disable -ShowHTML -WhatIfDisable -WhatIfDelete -Delete
    $Output

    .EXAMPLE
    # this is a fresh run and it will try to delete computers according to it's defaults
    # read documentation to understand what it does
    $Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
    $Output

    .EXAMPLE
    # Configure retry parameters for large AD environments with enumeration context errors
    $Configuration = @{
        Delete                = $true
        DeleteIsEnabled       = $false
        DeleteListProcessedMoreThan = 90
        ADQueryMaxRetries     = 5      # Increase retries for unreliable environments
        ADQueryRetryDelay     = 10     # Increase delay between retries
        ADQueryPageSize       = 500    # Smaller page size for large environments
        WhatIfDelete          = $true
        ShowHTML             = $true
        LogPath              = "$PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
        ReportPath           = "$PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    }
    $Output = Invoke-ADComputersCleanup @Configuration
    $Output

    .EXAMPLE
    # Run the script
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

    # Run one time as admin: Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers'
    $Output = Invoke-ADComputersCleanup @Configuration
    $Output

    .NOTES
    General notes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Forest,
        [alias('Domain')][string[]] $IncludeDomains,
        [string[]] $ExcludeDomains,
        # Disable options
        [switch] $Disable,
        [switch] $DisableAndMove,
        [ValidateSet(
            'DisableAndMove',
            'MoveAndDisable'
        )][string] $DisableAndMoveOrder = 'DisableAndMove',
        [nullable[bool]] $DisableIsEnabled,
        [nullable[bool]] $DisableNoServicePrincipalName,
        [nullable[int]] $DisableLastLogonDateMoreThan = 180,
        [nullable[int]] $DisablePasswordLastSetMoreThan = 180,
        [nullable[int]] $DisableRequireWhenCreatedMoreThan = 90,
        [nullable[DateTime]] $DisablePasswordLastSetOlderThan,
        [nullable[DateTime]] $DisableLastLogonDateOlderThan,
        [nullable[int]] $DisableLastSeenAzureMoreThan,
        [nullable[int]] $DisableLastSeenIntuneMoreThan,
        [nullable[int]] $DisableLastSyncAzureMoreThan,
        [nullable[int]] $DisableLastContactJamfMoreThan,
        [Array] $DisableExcludeSystems = @(),
        [Array] $DisableIncludeSystems = @(),
        [Array] $DisableExcludeServicePrincipalName = @(),
        [Array] $DisableIncludeServicePrincipalName = @(),
        [int] $DisableLimit = 1, # 0 = unlimited
        [Object] $DisableMoveTargetOrganizationalUnit,
        [switch] $DisableDoNotAddToPendingList,
        # Move options
        [switch] $Move,
        [nullable[bool]] $MoveIsEnabled,
        [nullable[bool]] $MoveNoServicePrincipalName,
        [nullable[int]] $MoveLastLogonDateMoreThan,
        [nullable[int]] $MovePasswordLastSetMoreThan,
        [nullable[int]] $MoveListProcessedMoreThan,
        [nullable[int]] $MoveRequireWhenCreatedMoreThan,
        [nullable[DateTime]] $MovePasswordLastSetOlderThan,
        [nullable[DateTime]] $MoveLastLogonDateOlderThan,
        [nullable[int]] $MoveLastSeenAzureMoreThan,
        [nullable[int]] $MoveLastSeenIntuneMoreThan,
        [nullable[int]] $MoveLastSyncAzureMoreThan,
        [nullable[int]] $MoveLastContactJamfMoreThan,
        [Array] $MoveExcludeSystems = @(),
        [Array] $MoveIncludeSystems = @(),
        [Array] $MoveExcludeServicePrincipalName = @(),
        [Array] $MoveIncludeServicePrincipalName = @(),
        [int] $MoveLimit = 1, # 0 = unlimited
        [Object] $MoveTargetOrganizationalUnit,
        # Delete options
        [switch] $Delete,
        [nullable[bool]] $DeleteIsEnabled,
        [nullable[bool]] $DeleteNoServicePrincipalName,
        [nullable[int]] $DeleteLastLogonDateMoreThan = 180,
        [nullable[int]] $DeletePasswordLastSetMoreThan = 180,
        [nullable[int]] $DeleteRequireWhenCreatedMoreThan = 90,
        [nullable[int]] $DeleteListProcessedMoreThan,
        [nullable[DateTime]] $DeletePasswordLastSetOlderThan,
        [nullable[DateTime]] $DeleteLastLogonDateOlderThan,
        [nullable[int]] $DeleteLastSeenAzureMoreThan,
        [nullable[int]] $DeleteLastSeenIntuneMoreThan,
        [nullable[int]] $DeleteLastSyncAzureMoreThan,
        [nullable[int]] $DeleteLastContactJamfMoreThan,
        [Array] $DeleteExcludeSystems = @(),
        [Array] $DeleteIncludeSystems = @(),
        [Array] $DeleteExcludeServicePrincipalName = @(),
        [Array] $DeleteIncludeServicePrincipalName = @(),
        [int] $DeleteLimit = 1, # 0 = unlimited
        # General options
        [Array] $Exclusions = @(
            # default globalexclusions
            '*OU=Domain Controllers*'
        ),
        [switch] $DisableModifyDescription,
        [alias('DisableAdminModifyDescription')][switch] $DisableModifyAdminDescription,
        [object] $Filter = '*',
        [object] $SearchBase,
        [string] $DataStorePath,
        [switch] $ReportOnly,
        [int] $ReportMaximum,
        [switch] $WhatIfDelete,
        [switch] $WhatIfDisable,
        [switch] $WhatIfMove,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $LogShowTime,
        [string] $LogTimeFormat,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,
        [string] $ReportPath,
        [nullable[int]] $SafetyADLimit,
        [nullable[int]] $SafetyAzureADLimit,
        [nullable[int]] $SafetyIntuneLimit,
        [nullable[int]] $SafetyJamfLimit,
        [switch] $DontWriteToEventLog,
        [Object] $TargetServers,
        [switch] $RemoveProtectedFromAccidentalDeletionFlag,
        # AD Query retry parameters
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ADQueryMaxRetries = 3,
        [ValidateRange(0, [int]::MaxValue)]
        [int] $ADQueryRetryDelay = 5,
        [ValidateRange(1, 10000)]
        [int] $ADQueryPageSize = 1000
    )
    # we will use it to check for intune/azuread/jamf functionality
    $Script:CleanupOptions = [ordered] @{}

    # just in case user wants to use -WhatIf instead of -WhatIfDelete and -WhatIfDisable
    if (-not $WhatIfDelete -and -not $WhatIfDisable) {
        $WhatIfDelete = $WhatIfDisable = $WhatIfPreference
    }

    # lets enable global logging
    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    # prepare configuration
    $DisableOnlyIf = [ordered] @{
        # Active directory
        IsEnabled                    = $DisableIsEnabled
        NoServicePrincipalName       = $DisableNoServicePrincipalName
        LastLogonDateMoreThan        = $DisableLastLogonDateMoreThan
        PasswordLastSetMoreThan      = $DisablePasswordLastSetMoreThan
        ExcludeSystems               = $DisableExcludeSystems
        IncludeSystems               = $DisableIncludeSystems
        ExcludeServicePrincipalName  = $DisableExcludeServicePrincipalName
        IncludeServicePrincipalName  = $DisableIncludeServicePrincipalName
        PasswordLastSetOlderThan     = $DisablePasswordLastSetOlderThan
        LastLogonDateOlderThan       = $DisableLastLogonDateOlderThan
        # Intune
        LastSeenIntuneMoreThan       = $DisableLastSeenIntuneMoreThan
        # Azure
        LastSyncAzureMoreThan        = $DisableLastSyncAzureMoreThan
        LastSeenAzureMoreThan        = $DisableLastSeenAzureMoreThan
        # Jamf
        LastContactJamfMoreThan      = $DisableLastContactJamfMoreThan

        DoNotAddToPendingList        = $DisableDoNotAddToPendingList
        MoveTargetOrganizationalUnit = $DisableMoveTargetOrganizationalUnit
        DisableAndMove               = $DisableAndMove.IsPresent
        RequireWhenCreatedMoreThan   = $DisableRequireWhenCreatedMoreThan
    }

    $MoveOnlyIf = [ordered] @{
        # Active directory
        IsEnabled                   = $MoveIsEnabled
        NoServicePrincipalName      = $MoveNoServicePrincipalName
        LastLogonDateMoreThan       = $MoveLastLogonDateMoreThan
        PasswordLastSetMoreThan     = $MovePasswordLastSetMoreThan
        ListProcessedMoreThan       = $MoveListProcessedMoreThan
        ExcludeSystems              = $MoveExcludeSystems
        IncludeSystems              = $MoveIncludeSystems
        ExcludeServicePrincipalName = $MoveExcludeServicePrincipalName
        IncludeServicePrincipalName = $MoveIncludeServicePrincipalName
        PasswordLastSetOlderThan    = $MovePasswordLastSetOlderThan
        LastLogonDateOlderThan      = $MoveLastLogonDateOlderThan
        # Intune
        LastSeenIntuneMoreThan      = $MoveLastSeenIntuneMoreThan
        # Azure
        LastSeenAzureMoreThan       = $MoveLastSeenAzureMoreThan
        LastSyncAzureMoreThan       = $MoveLastSyncAzureMoreThan
        # Jamf
        LastContactJamfMoreThan     = $MoveLastContactJamfMoreThan
        # special option for move only
        TargetOrganizationalUnit    = $MoveTargetOrganizationalUnit

        DoNotAddToPendingList       = $MoveDoNotAddToPendingList
        #MoveTargetOrganizationalUnit = $MoveTargetOrganizationalUnit
        RequireWhenCreatedMoreThan  = $MoveRequireWhenCreatedMoreThan
    }

    $DeleteOnlyIf = [ordered] @{
        # Active directory
        IsEnabled                   = $DeleteIsEnabled
        NoServicePrincipalName      = $DeleteNoServicePrincipalName
        LastLogonDateMoreThan       = $DeleteLastLogonDateMoreThan
        PasswordLastSetMoreThan     = $DeletePasswordLastSetMoreThan
        ListProcessedMoreThan       = $DeleteListProcessedMoreThan
        ExcludeSystems              = $DeleteExcludeSystems
        IncludeSystems              = $DeleteIncludeSystems
        ExcludeServicePrincipalName = $DeleteExcludeServicePrincipalName
        IncludeServicePrincipalName = $DeleteIncludeServicePrincipalName
        PasswordLastSetOlderThan    = $DeletePasswordLastSetOlderThan
        LastLogonDateOlderThan      = $DeleteLastLogonDateOlderThan
        # Intune
        LastSeenIntuneMoreThan      = $DeleteLastSeenIntuneMoreThan
        # Azure
        LastSeenAzureMoreThan       = $DeleteLastSeenAzureMoreThan
        LastSyncAzureMoreThan       = $DeleteLastSyncAzureMoreThan
        # Jamf
        LastContactJamfMoreThan     = $DeleteLastContactJamfMoreThan
        RequireWhenCreatedMoreThan  = $DeleteRequireWhenCreatedMoreThan
    }

    if (-not $DataStorePath) {
        $DataStorePath = $($MyInvocation.PSScriptRoot) + '\ProcessedComputers.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = $($MyInvocation.PSScriptRoot) + '\ProcessedComputers.html'
    }

    # lets create report path, reporting is enabled by default
    Set-ReportingCapabilities -ReportPath $ReportPath -ReportMaximum $ReportMaximum -ScriptPath $MyInvocation.ScriptName

    $Success = Assert-InitialSettings -DisableOnlyIf $DisableOnlyIf -MoveOnlyIf $MoveOnlyIf -DeleteOnlyIf $DeleteOnlyIf
    if ($Success -contains $false) {
        return
    }

    $Today = Get-Date
    $Properties = 'DistinguishedName', 'DNSHostName', 'SamAccountName', 'Enabled', 'OperatingSystem', 'OperatingSystemVersion', 'LastLogonDate', 'PasswordLastSet', 'PasswordExpired', 'servicePrincipalName', 'logonCount', 'ManagedBy', 'Description', 'WhenCreated', 'WhenChanged', 'ProtectedFromAccidentalDeletion'

    $Export = [ordered] @{
        Version         = Get-GitHubVersion -Cmdlet 'Invoke-ADComputersCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun      = $null
        History         = $null
        PendingDeletion = $null
    }

    Write-Color '[i] ', "[CleanupMonster] ", 'Version', ' [Informative] ', $Export['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta
    Write-Color -Text "[i] ", "Started process of cleaning up stale computers" -Color Yellow, White
    Write-Color -Text "[i] ", "Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Yellow, White, Green, White

    try {
        $ForestInformation = Get-WinADForestDetails -PreferWritable -Forest $Forest -Extended -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains
    } catch {
        Write-Color -Text "[i] ", "Couldn't get forest. Terminating. Lack of domain contact? Error: $($_.Exception.Message)." -Color Yellow, Red
        return
    }

    if (-not $ReportOnly) {
        $ProcessedComputers = Import-ComputersData -Export $Export -DataStorePath $DataStorePath
        if ($ProcessedComputers -eq $false) {
            return
        }
        Write-Color -Text "[i] ", "Loaded ", $($ProcessedComputers.Count), " computers from $($DataStorePath) and added to pending list of computers." -Color Yellow, White, Green, White
    }

    if (-not $Disable -and -not $Delete) {
        Write-Color -Text "[i] ", "No action can be taken. You need to enable Disable or/and Delete feature to have any action." -Color Yellow, Red
        return
    }

    $Report = [ordered] @{}

    $getInitialGraphComputersSplat = [ordered] @{
        SafetyAzureADLimit            = $SafetyAzureADLimit
        SafetyIntuneLimit             = $SafetyIntuneLimit
        DeleteLastSeenAzureMoreThan   = $DeleteLastSeenAzureMoreThan
        DeleteLastSeenIntuneMoreThan  = $DeleteLastSeenIntuneMoreThan
        DeleteLastSyncAzureMoreThan   = $DeleteLastSyncAzureMoreThan
        DisableLastSeenAzureMoreThan  = $DisableLastSeenAzureMoreThan
        DisableLastSeenIntuneMoreThan = $DisableLastSeenIntuneMoreThan
        DisableLastSyncAzureMoreThan  = $DisableLastSyncAzureMoreThan
        MoveLastSeenAzureMoreThan     = $MoveLastSeenAzureMoreThan
        MoveLastSeenIntuneMoreThan    = $MoveLastSeenIntuneMoreThan
        MoveLastSyncAzureMoreThan     = $MoveLastSyncAzureMoreThan
    }
    Remove-EmptyValue -Hashtable $getInitialGraphComputersSplat
    $AzureInformationCache = Get-InitialGraphComputers @getInitialGraphComputersSplat
    if ($AzureInformationCache -eq $false) {
        return
    }

    $getInitialJamf = @{
        DisableLastContactJamfMoreThan = $DisableLastContactJamfMoreThan
        DeleteLastContactJamfMoreThan  = $DeleteLastContactJamfMoreThan
        MoveLastContactJamfMoreThan    = $MoveLastContactJamfMoreThan
        SafetyJamfLimit                = $SafetyJamfLimit
    }
    Remove-EmptyValue -Hashtable $getInitialJamf
    $JamfInformationCache = Get-InitialJamfComputers @getInitialJamf
    if ($JamfInformationCache -eq $false) {
        return
    }

    $SplatADComputers = [ordered] @{
        Report                = $Report
        ForestInformation     = $ForestInformation
        Filter                = $Filter
        SearchBase            = $SearchBase
        Properties            = $Properties
        Disable               = $Disable
        Delete                = $Delete
        Move                  = $Move
        DisableOnlyIf         = $DisableOnlyIf
        DeleteOnlyIf          = $DeleteOnlyIf
        MoveOnlyIf            = $MoveOnlyIf
        Exclusions            = $Exclusions
        ProcessedComputers    = $ProcessedComputers
        SafetyADLimit         = $SafetyADLimit
        AzureInformationCache = $AzureInformationCache
        JamfInformationCache  = $JamfInformationCache
        TargetServers         = $TargetServers
        ADQueryMaxRetries     = $ADQueryMaxRetries
        ADQueryRetryDelay     = $ADQueryRetryDelay
        ADQueryPageSize       = $ADQueryPageSize
    }

    $AllComputers = Get-InitialADComputers @SplatADComputers
    if ($AllComputers -eq $false) {
        return
    }

    foreach ($Domain in $Report.Keys) {
        if ($Disable -or $DisableAndMove) {
            if ($DisableLimit -eq 0) {
                $DisableLimitText = 'Unlimited'
            } else {
                $DisableLimitText = $DisableLimit
            }
            Write-Color "[i] ", "Computers to be disabled for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDisabled'], ". Current disable limit: ", $DisableLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }

        if ($Move) {
            if ($MoveLimit -eq 0) {
                $MoveLimitText = 'Unlimited'
            } else {
                $MoveLimitText = $MoveLimit
            }
            Write-Color "[i] ", "Computers to be moved for domain $Domain`: ", $Report["$Domain"]['ComputersToBeMoved'], ". Current move limit: ", $MoveLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }

        if ($Delete) {
            if ($DeleteLimit -eq 0) {
                $DeleteLimitText = 'Unlimited'
            } else {
                $DeleteLimitText = $DeleteLimit
            }
            Write-Color "[i] ", "Computers to be deleted for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDeleted'], ". Current delete limit: ", $DeleteLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }
    }


    if ($Disable -or $DisableAndMove) {
        $requestADComputersDisableSplat = @{
            # those 2 are added only to make sure we don't add to processing list
            # if there is no process later on
            Delete                                    = $Delete
            Move                                      = $Move
            # we can disable and move on one go
            DisableAndMove                            = $DisableAndMove
            Report                                    = $Report
            WhatIfDisable                             = $WhatIfDisable
            WhatIf                                    = $WhatIfPreference
            DisableModifyDescription                  = $DisableModifyDescription.IsPresent
            DisableModifyAdminDescription             = $DisableModifyAdminDescription.IsPresent
            DisableLimit                              = $DisableLimit
            ReportOnly                                = $ReportOnly
            Today                                     = $Today
            DontWriteToEventLog                       = $DontWriteToEventLog
            DisableMoveTargetOrganizationalUnit       = $DisableMoveTargetOrganizationalUnit
            DoNotAddToPendingList                     = $DisableDoNotAddToPendingList
            DisableAndMoveOrder                       = $DisableAndMoveOrder
            RemoveProtectedFromAccidentalDeletionFlag = $RemoveProtectedFromAccidentalDeletionFlag.IsPresent
        }
        [Array] $ReportDisabled = Request-ADComputersDisable @requestADComputersDisableSplat
    }

    if ($Move) {
        $requestADComputersMoveSplat = @{
            Report                                    = $Report
            WhatIfMove                                = $WhatIfMove
            WhatIf                                    = $WhatIfPreference
            MoveLimit                                 = $MoveLimit
            ReportOnly                                = $ReportOnly
            Today                                     = $Today
            ProcessedComputers                        = $ProcessedComputers
            TargetOrganizationalUnit                  = $MoveTargetOrganizationalUnit
            DontWriteToEventLog                       = $DontWriteToEventLog
            Delete                                    = $Delete
            DoNotAddToPendingList                     = $MoveDoNotAddToPendingList
            RemoveProtectedFromAccidentalDeletionFlag = $RemoveProtectedFromAccidentalDeletionFlag.IsPresent
        }
        [Array] $ReportMoved = Request-ADComputersMove @requestADComputersMoveSplat
    }

    if ($Delete) {
        $requestADComputersDeleteSplat = @{
            Report                                    = $Report
            WhatIfDelete                              = $WhatIfDelete
            WhatIf                                    = $WhatIfPreference
            DeleteLimit                               = $DeleteLimit
            ReportOnly                                = $ReportOnly
            Today                                     = $Today
            ProcessedComputers                        = $ProcessedComputers
            DontWriteToEventLog                       = $DontWriteToEventLog
            RemoveProtectedFromAccidentalDeletionFlag = $RemoveProtectedFromAccidentalDeletionFlag.IsPresent
        }
        [Array] $ReportDeleted = Request-ADComputersDelete @requestADComputersDeleteSplat
    }

    Write-Color "[i] ", "Cleanup process for processed computers that no longer exists in AD" -Color Yellow, Green
    foreach ($FullName in [string[]] $ProcessedComputers.Keys) {
        if (-not $AllComputers["$($FullName)"]) {
            Write-Color -Text "[*] Removing computer from pending list ", $ProcessedComputers[$FullName].SamAccountName, " ($($ProcessedComputers[$FullName].DistinguishedName))" -Color Yellow, Green, Yellow
            $ProcessedComputers.Remove("$($FullName)")
        }
    }

    # Building up summary
    $Export.PendingDeletion = $ProcessedComputers
    $Export.CurrentRun = @(
        if ($ReportDisabled.Count -gt 0) {
            $ReportDisabled
        }
        if ($ReportMoved.Count -gt 0) {
            $ReportMoved
        }
        if ($ReportDeleted.Count -gt 0) {
            $ReportDeleted
        }
    )
    $Export.History = @(
        if ($Export.History) {
            $Export.History
        }
        if ($ReportDisabled.Count -gt 0) {
            $ReportDisabled
        }
        if ($ReportMoved.Count -gt 0) {
            $ReportMoved
        }
        if ($ReportDeleted.Count -gt 0) {
            $ReportDeleted
        }
    )

    Write-Color "[i] ", "Exporting Processed List" -Color Yellow, Magenta
    if (-not $ReportOnly) {
        try {
            $Export | Export-Clixml -LiteralPath $DataStorePath -Encoding Unicode -WhatIf:$false -ErrorAction Stop
        } catch {
            Write-Color -Text "[-] Exporting Processed List failed. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    }
    Write-Color -Text "[i] ", "Summary of cleaning up stale computers" -Color Yellow, Cyan
    foreach ($Domain in $Report.Keys) {
        if ($Disable -or $DisableAndMove) {
            Write-Color -Text "[i] ", "Computers to be disabled for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDisabled'] -Color Yellow, Cyan, Green
        }
        if ($Move) {
            Write-Color -Text "[i] ", "Computers to be moved for domain $Domain`: ", $Report["$Domain"]['ComputersToBeMoved'] -Color Yellow, Cyan, Green
        }
        if ($Delete) {
            Write-Color -Text "[i] ", "Computers to be deleted for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDeleted'] -Color Yellow, Cyan, Green
        }
    }
    if (-not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers on pending list`: ", $Export['PendingDeletion'].Count -Color Yellow, Cyan, Green
    }
    if (($Disable -or $DisableAndMove) -and -not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers disabled in this run`: ", $ReportDisabled.Count -Color Yellow, Cyan, Green
    }
    if ($Move -and -not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers moved in this run`: ", $ReportMoved.Count -Color Yellow, Cyan, Green
    }
    if ($Delete -and -not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers deleted in this run`: ", $ReportDeleted.Count -Color Yellow, Cyan, Green
    }

    if ($Export -and $ReportPath) {
        [Array] $ComputersToProcess = foreach ($Domain in $Report.Keys) {
            if ($Report["$Domain"]['Computers'].Count -gt 0) {
                $Report["$Domain"]['Computers']
            }
        }
        Write-Color -Text "[i] ", "Computers to be processed for HTML report`: ", $ComputersToProcess.Count -Color Yellow, Cyan, Green
        $Export.Statistics = New-ADComputersStatistics -ComputersToProcess $ComputersToProcess

        $newHTMLProcessedComputersSplat = @{
            Export             = $Export
            FilePath           = $ReportPath
            Online             = $Online.IsPresent
            ShowHTML           = $ShowHTML.IsPresent
            LogFile            = $LogPath
            ComputersToProcess = $ComputersToProcess
            DisableOnlyIf      = $DisableOnlyIf
            DeleteOnlyIf       = $DeleteOnlyIf
            MoveOnlyIf         = $MoveOnlyIf
            Delete             = $Delete
            Disable            = $Disable
            Move               = $Move
            ReportOnly         = $ReportOnly
        }
        Write-Color "[i] ", "Generating HTML report ($ReportPath)" -Color Yellow, Magenta
        New-HTMLProcessedComputers @newHTMLProcessedComputersSplat
    }

    Write-Color -Text "[i] Finished process of cleaning up stale computers" -Color Green

    if (-not $Suppress) {
        $Export.EmailBody = New-EmailBodyComputers -CurrentRun $Export.CurrentRun
        $Export
    }
}