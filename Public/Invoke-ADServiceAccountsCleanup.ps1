function Invoke-ADServiceAccountsCleanup {
    <#
    .SYNOPSIS
    Cleans up Managed Service Accounts (MSA) and Group Managed Service Accounts (GMSA) from Active Directory based on various filtering criteria.

    .DESCRIPTION
    This function identifies and manages MSA/GMSA accounts in Active Directory based on specified filters.
    It can disable, move, or delete MSA/GMSA accounts that meet the specified criteria.
    The function allows for detailed reporting before making any changes.

    .PARAMETER Forest
    The name of the forest to process. If not specified, uses the current forest.

    .PARAMETER IncludeDomains
    An array of domain names to include in the cleanup process.

    .PARAMETER ExcludeDomains
    An array of domain names to exclude from the cleanup process.

    .PARAMETER IncludeOrganizationalUnit
    An array of organizational units to include in the cleanup process.
    Supports wildcards using the -like operator. For example: "*OU=ServiceAccounts,OU=Production*"

    .PARAMETER ExcludeOrganizationalUnit
    An array of organizational units to exclude from the cleanup process.
    Supports wildcards using the -like operator. For example: "*OU=Test*"

    .PARAMETER Disable
    Enable the disable process, meaning the service accounts that meet the criteria will be disabled.

    .PARAMETER DisableIsEnabled
    Disable service account only if it's Enabled or only if it's Disabled.
    By default it will try to disable all service accounts that are either disabled or enabled.

    .PARAMETER DisablePasswordLastSetMoreThan
    Disable service account only if it has a PasswordLastSet that is more than the specified number of days.

    .PARAMETER DisableRequireWhenCreatedMoreThan
    Disable service account only if it was created more than the specified number of days ago.

    .PARAMETER DisablePasswordLastSetOlderThan
    Disable service account only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER DisableIncludeType
    Include only specified service account types: 'MSA', 'GMSA', or both.
    By default includes both MSA and GMSA accounts.

    .PARAMETER DisableExcludeType
    Exclude specified service account types: 'MSA', 'GMSA'.

    .PARAMETER DisableExcludeNames
    Exclude service accounts with names matching these patterns.
    Supports wildcards using the -like operator.

    .PARAMETER DisableIncludeNames
    Include only service accounts with names matching these patterns.
    Supports wildcards using the -like operator.

    .PARAMETER DisableLimit
    Limit the number of service accounts that will be disabled. 0 = unlimited. Default is 1.
    This is to prevent accidental disabling of all service accounts that meet the criteria.

    .PARAMETER DisableDoNotAddToPendingList
    By default, service accounts that are disabled are added to the list of accounts that will be actioned later (deleted).
    If you want to disable accounts, but not add them to the list of accounts that will be actioned later (aka pending list), use this switch.

    .PARAMETER Delete
    Enable the delete process, meaning the service accounts that meet the criteria will be deleted.

    .PARAMETER DeleteIsEnabled
    Delete service account only if it's Enabled or only if it's Disabled.
    By default it will try to delete all service accounts that are either disabled or enabled.

    .PARAMETER DeletePasswordLastSetMoreThan
    Delete service account only if it has a PasswordLastSet that is more than the specified number of days.

    .PARAMETER DeleteRequireWhenCreatedMoreThan
    Delete service account only if it was created more than the specified number of days ago.

    .PARAMETER DeleteListProcessedMoreThan
    Delete service account only if it has been processed by this script more than the specified number of days ago.
    This is useful if you want to delete service accounts that have been disabled for a certain amount of time.

    .PARAMETER DeletePasswordLastSetOlderThan
    Delete service account only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER DeleteIncludeType
    Include only specified service account types: 'MSA', 'GMSA', or both.
    By default includes both MSA and GMSA accounts.

    .PARAMETER DeleteExcludeType
    Exclude specified service account types: 'MSA', 'GMSA'.

    .PARAMETER DeleteExcludeNames
    Exclude service accounts with names matching these patterns.
    Supports wildcards using the -like operator.

    .PARAMETER DeleteIncludeNames
    Include only service accounts with names matching these patterns.
    Supports wildcards using the -like operator.

    .PARAMETER DeleteLimit
    Limit the number of service accounts that will be deleted. 0 = unlimited. Default is 1.
    This is to prevent accidental deletion of all service accounts that meet the criteria.

    .PARAMETER Exclusions
    List of service accounts to exclude from the process.
    You can specify multiple accounts by separating them with a comma.
    It's using the -like operator, so you can use wildcards.
    You can use SamAccountName, DistinguishedName, or Name property of the service account object for comparison.

    .PARAMETER DisableModifyDescription
    Modify the description of the service account object to include the date and time when it was disabled.
    By default it will not modify the description.

    .PARAMETER DisableModifyAdminDescription
    Modify the admin description of the service account object to include the date and time when it was disabled.
    By default it will not modify the admin description.

    .PARAMETER Filter
    Filter to use when searching for service accounts in Get-ADServiceAccount cmdlet.
    Default is '*'

    .PARAMETER SearchBase
    SearchBase to use when searching for service accounts in Get-ADServiceAccount cmdlet.
    Default is not set. It will search the whole domain.
    You can provide a string or hashtable of domains with their SearchBase.

    .PARAMETER DataStorePath
    Path to the XML file that will be used to store the list of processed service accounts, current run, and history data.
    Default is $PSScriptRoot\ProcessedServiceAccounts.xml

    .PARAMETER ReportOnly
    Only generate the report, don't disable or delete service accounts.

    .PARAMETER ReportMaximum
    Maximum number of reports to keep. Default is Unlimited (0).

    .PARAMETER WhatIfDisable
    WhatIf parameter for the Disable process.
    It's not necessary to specify this parameter if you use WhatIf parameter which applies to all processes.

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

    .PARAMETER ReportPath
    Path to the HTML report file. Default is $PSScriptRoot\ProcessedServiceAccounts.html

    .PARAMETER SafetyADLimit
    Minimum number of service accounts that must be returned by AD cmdlets to proceed with the process.
    Default is not to check.
    This is there to prevent accidental deletion of all service accounts if there is a problem with AD.

    .PARAMETER DontWriteToEventLog
    By default the function will write to the event log making sure the cleanup process is logged.
    This parameter will prevent the function from writing to the event log.

    .PARAMETER TargetServers
    Target servers to use when connecting to Active Directory.
    It can take a string with server name, or hashtable with key being the domain, and value being the server name.

    .PARAMETER RemoveProtectedFromAccidentalDeletionFlag
    Remove the ProtectedFromAccidentalDeletion flag from the service account object before deleting it.
    By default it will not remove the flag, and require it to be removed manually.

    .EXAMPLE
    $Output = Invoke-ADServiceAccountsCleanup -DisableIsEnabled $true -Disable -WhatIfDisable -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DisableServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DisableServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
    $Output

    .EXAMPLE
    $Output = Invoke-ADServiceAccountsCleanup -DeleteListProcessedMoreThan 100 -Disable -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
    $Output

    .EXAMPLE
    # this is a fresh run and it will provide report only according to it's defaults
    $Output = Invoke-ADServiceAccountsCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
    $Output

    .EXAMPLE
    # Run the script with specific GMSA targeting
    $Configuration = @{
        Disable                        = $true
        DisableIsEnabled               = $true
        DisablePasswordLastSetMoreThan = 90
        DisableIncludeType             = @('GMSA')
        DisableLimit                   = 2 # 0 means unlimited, ignored for reports
        DisableModifyDescription       = $false
        DisableModifyAdminDescription  = $true

        Delete                         = $true
        DeleteIsEnabled                = $false
        DeletePasswordLastSetMoreThan  = 180
        DeleteListProcessedMoreThan    = 90 # 90 days since account was added to list
        DeleteIncludeType              = @('GMSA')
        DeleteLimit                    = 2 # 0 means unlimited, ignored for reports

        Exclusions                     = @(
            '*OU=Protected Service Accounts*'
            'CriticalGMSA$'
        )

        Filter                         = '*'
        WhatIfDisable                  = $true
        WhatIfDelete                   = $true
        LogPath                        = "$PSScriptRoot\Logs\ServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
        DataStorePath                  = "$PSScriptRoot\ProcessedServiceAccounts.xml"
        ReportPath                     = "$PSScriptRoot\Reports\ServiceAccounts_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
        ShowHTML                       = $true
    }

    $Output = Invoke-ADServiceAccountsCleanup @Configuration
    $Output

    .NOTES
    This function follows the same pattern as Invoke-ADComputersCleanup but is specifically designed for MSA and GMSA service accounts.
    MSA accounts end with $ and have msDS-ManagedPasswordId attribute.
    GMSA accounts end with $ and have msDS-ManagedPasswordInterval attribute.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Forest,
        [alias('Domain')][string[]] $IncludeDomains,
        [string[]] $ExcludeDomains,
        [string[]] $IncludeOrganizationalUnit,
        [string[]] $ExcludeOrganizationalUnit,
        # Disable options
        [switch] $Disable,
        [nullable[bool]] $DisableIsEnabled,
        [nullable[int]] $DisablePasswordLastSetMoreThan = 180,
        [nullable[int]] $DisableRequireWhenCreatedMoreThan = 90,
        [nullable[DateTime]] $DisablePasswordLastSetOlderThan,
        [ValidateSet('MSA', 'GMSA')][Array] $DisableIncludeType = @('MSA', 'GMSA'),
        [ValidateSet('MSA', 'GMSA')][Array] $DisableExcludeType = @(),
        [Array] $DisableExcludeNames = @(),
        [Array] $DisableIncludeNames = @(),
        [int] $DisableLimit = 1, # 0 = unlimited
        [switch] $DisableDoNotAddToPendingList,
        # Delete options
        [switch] $Delete,
        [nullable[bool]] $DeleteIsEnabled,
        [nullable[int]] $DeletePasswordLastSetMoreThan = 180,
        [nullable[int]] $DeleteRequireWhenCreatedMoreThan = 90,
        [nullable[int]] $DeleteListProcessedMoreThan,
        [nullable[DateTime]] $DeletePasswordLastSetOlderThan,
        [ValidateSet('MSA', 'GMSA')][Array] $DeleteIncludeType = @('MSA', 'GMSA'),
        [ValidateSet('MSA', 'GMSA')][Array] $DeleteExcludeType = @(),
        [Array] $DeleteExcludeNames = @(),
        [Array] $DeleteIncludeNames = @(),
        [int] $DeleteLimit = 1, # 0 = unlimited
        # General options
        [Array] $Exclusions = @(),
        [switch] $DisableModifyDescription,
        [alias('DisableAdminModifyDescription')][switch] $DisableModifyAdminDescription,
        [object] $Filter = '*',
        [object] $SearchBase,
        [string] $DataStorePath,
        [switch] $ReportOnly,
        [int] $ReportMaximum,
        [switch] $WhatIfDelete,
        [switch] $WhatIfDisable,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $LogShowTime,
        [string] $LogTimeFormat,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,
        [string] $ReportPath,
        [nullable[int]] $SafetyADLimit,
        [switch] $DontWriteToEventLog,
        [Object] $TargetServers,
        [switch] $RemoveProtectedFromAccidentalDeletionFlag
    )
    # just in case user wants to use -WhatIf instead of -WhatIfDelete and -WhatIfDisable
    if (-not $WhatIfDelete -and -not $WhatIfDisable) {
        $WhatIfDelete = $WhatIfDisable = $WhatIfPreference
    }

    # lets enable global logging
    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    # prepare configuration
    $DisableOnlyIf = [ordered] @{
        # Active directory
        IsEnabled                  = $DisableIsEnabled
        PasswordLastSetMoreThan    = $DisablePasswordLastSetMoreThan
        PasswordLastSetOlderThan   = $DisablePasswordLastSetOlderThan
        RequireWhenCreatedMoreThan = $DisableRequireWhenCreatedMoreThan
        IncludeType                = $DisableIncludeType
        ExcludeType                = $DisableExcludeType
        ExcludeNames               = $DisableExcludeNames
        IncludeNames               = $DisableIncludeNames
        DoNotAddToPendingList      = $DisableDoNotAddToPendingList
    }

    $DeleteOnlyIf = [ordered] @{
        # Active directory
        IsEnabled                  = $DeleteIsEnabled
        PasswordLastSetMoreThan    = $DeletePasswordLastSetMoreThan
        ListProcessedMoreThan      = $DeleteListProcessedMoreThan
        PasswordLastSetOlderThan   = $DeletePasswordLastSetOlderThan
        RequireWhenCreatedMoreThan = $DeleteRequireWhenCreatedMoreThan
        IncludeType                = $DeleteIncludeType
        ExcludeType                = $DeleteExcludeType
        ExcludeNames               = $DeleteExcludeNames
        IncludeNames               = $DeleteIncludeNames
    }

    if (-not $DataStorePath) {
        $DataStorePath = $($MyInvocation.PSScriptRoot) + '\ProcessedServiceAccounts.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = $($MyInvocation.PSScriptRoot) + '\ProcessedServiceAccounts.html'
    }

    # lets create report path, reporting is enabled by default
    Set-ReportingCapabilities -ReportPath $ReportPath -ReportMaximum $ReportMaximum -ScriptPath $MyInvocation.ScriptName

    $Success = Assert-InitialSettings -DisableOnlyIf $DisableOnlyIf -DeleteOnlyIf $DeleteOnlyIf
    if ($Success -contains $false) {
        return
    }

    $Today = Get-Date
    $Properties = 'DistinguishedName', 'Name', 'SamAccountName', 'Enabled', 'PasswordLastSet', 'WhenCreated', 'WhenChanged', 'ProtectedFromAccidentalDeletion', 'Description', 'msDS-ManagedPasswordId', 'msDS-ManagedPasswordInterval', 'msDS-GroupMSAMembership', 'ObjectClass'

    $Export = [ordered] @{
        Version         = Get-GitHubVersion -Cmdlet 'Invoke-ADServiceAccountsCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun      = $null
        History         = $null
        PendingDeletion = $null
    }

    Write-Color '[i] ', "[CleanupMonster] ", 'Version', ' [Informative] ', $Export['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta
    Write-Color -Text "[i] ", "Started process of cleaning up MSA/GMSA service accounts" -Color Yellow, White
    Write-Color -Text "[i] ", "Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Yellow, White, Green, White

    try {
        $ForestInformation = Get-WinADForestDetails -PreferWritable -Forest $Forest -Extended -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains
    } catch {
        Write-Color -Text "[i] ", "Couldn't get forest. Terminating. Lack of domain contact? Error: $($_.Exception.Message)." -Color Yellow, Red
        return
    }

    if (-not $ReportOnly) {
        $ProcessedServiceAccounts = Import-ServiceAccountsData -Export $Export -DataStorePath $DataStorePath
        if ($ProcessedServiceAccounts -eq $false) {
            return
        }
        Write-Color -Text "[i] ", "Loaded ", $($ProcessedServiceAccounts.Count), " service accounts from $($DataStorePath) and added to pending list of service accounts." -Color Yellow, White, Green, White
    }

    if (-not $Disable -and -not $Delete) {
        Write-Color -Text "[i] ", "No action can be taken. You need to enable Disable or/and Delete feature to have any action." -Color Yellow, Red
        return
    }

    $Report = [ordered] @{}

    $SplatADServiceAccounts = [ordered] @{
        Report                       = $Report
        ForestInformation            = $ForestInformation
        Filter                       = $Filter
        SearchBase                   = $SearchBase
        Properties                   = $Properties
        Disable                      = $Disable
        Delete                       = $Delete
        DisableOnlyIf                = $DisableOnlyIf
        DeleteOnlyIf                 = $DeleteOnlyIf
        Exclusions                   = $Exclusions
        ProcessedServiceAccounts     = $ProcessedServiceAccounts
        SafetyADLimit                = $SafetyADLimit
        TargetServers                = $TargetServers
        IncludeOrganizationalUnit    = $IncludeOrganizationalUnit
        ExcludeOrganizationalUnit    = $ExcludeOrganizationalUnit
    }

    $AllServiceAccounts = Get-InitialADServiceAccounts @SplatADServiceAccounts
    if ($AllServiceAccounts -eq $false) {
        return
    }

    foreach ($Domain in $Report.Keys) {
        if ($Disable) {
            if ($DisableLimit -eq 0) {
                $DisableLimitText = 'Unlimited'
            } else {
                $DisableLimitText = $DisableLimit
            }
            Write-Color "[i] ", "Service accounts to be disabled for domain $Domain`: ", $Report["$Domain"]['ServiceAccountsToBeDisabled'], ". Current disable limit: ", $DisableLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }

        if ($Delete) {
            if ($DeleteLimit -eq 0) {
                $DeleteLimitText = 'Unlimited'
            } else {
                $DeleteLimitText = $DeleteLimit
            }
            Write-Color "[i] ", "Service accounts to be deleted for domain $Domain`: ", $Report["$Domain"]['ServiceAccountsToBeDeleted'], ". Current delete limit: ", $DeleteLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }
    }

    if ($Disable) {
        $requestADServiceAccountsDisableSplat = @{
            Delete                                    = $Delete
            Report                                    = $Report
            WhatIfDisable                             = $WhatIfDisable
            WhatIf                                    = $WhatIfPreference
            DisableModifyDescription                  = $DisableModifyDescription.IsPresent
            DisableModifyAdminDescription             = $DisableModifyAdminDescription.IsPresent
            DisableLimit                              = $DisableLimit
            ReportOnly                                = $ReportOnly
            Today                                     = $Today
            DontWriteToEventLog                       = $DontWriteToEventLog
            DoNotAddToPendingList                     = $DisableDoNotAddToPendingList
            RemoveProtectedFromAccidentalDeletionFlag = $RemoveProtectedFromAccidentalDeletionFlag.IsPresent
        }
        [Array] $ReportDisabled = Request-ADServiceAccountsDisable @requestADServiceAccountsDisableSplat
    }

    if ($Delete) {
        $requestADServiceAccountsDeleteSplat = @{
            Report                                    = $Report
            WhatIfDelete                              = $WhatIfDelete
            WhatIf                                    = $WhatIfPreference
            DeleteLimit                               = $DeleteLimit
            ReportOnly                                = $ReportOnly
            Today                                     = $Today
            ProcessedServiceAccounts                  = $ProcessedServiceAccounts
            DontWriteToEventLog                       = $DontWriteToEventLog
            RemoveProtectedFromAccidentalDeletionFlag = $RemoveProtectedFromAccidentalDeletionFlag.IsPresent
        }
        [Array] $ReportDeleted = Request-ADServiceAccountsDelete @requestADServiceAccountsDeleteSplat
    }

    Write-Color "[i] ", "Cleanup process for processed service accounts that no longer exists in AD" -Color Yellow, Green
    foreach ($FullName in [string[]] $ProcessedServiceAccounts.Keys) {
        if (-not $AllServiceAccounts["$($FullName)"]) {
            Write-Color -Text "[*] Removing service account from pending list ", $ProcessedServiceAccounts[$FullName].SamAccountName, " ($($ProcessedServiceAccounts[$FullName].DistinguishedName))" -Color Yellow, Green, Yellow
            $ProcessedServiceAccounts.Remove("$($FullName)")
        }
    }

    # Building up summary
    $Export.PendingDeletion = $ProcessedServiceAccounts
    $Export.CurrentRun = @(
        if ($ReportDisabled.Count -gt 0) {
            $ReportDisabled
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
    Write-Color -Text "[i] ", "Summary of cleaning up MSA/GMSA service accounts" -Color Yellow, Cyan
    foreach ($Domain in $Report.Keys) {
        if ($Disable) {
            $DisableCount = $Report["$Domain"]['ServiceAccountsToBeDisabled']
            if ($DisableCount -gt 0) {
                Write-Color -Text "[i] ", "Service accounts to be disabled for domain $Domain`: ", $DisableCount -Color Yellow, Cyan, Red
            } else {
                Write-Color -Text "[i] ", "Service accounts to be disabled for domain $Domain`: ", "None found" -Color Yellow, Cyan, Green
            }
        }
        if ($Delete) {
            $DeleteCount = $Report["$Domain"]['ServiceAccountsToBeDeleted']
            if ($DeleteCount -gt 0) {
                Write-Color -Text "[i] ", "Service accounts to be deleted for domain $Domain`: ", $DeleteCount -Color Yellow, Cyan, Red
            } else {
                Write-Color -Text "[i] ", "Service accounts to be deleted for domain $Domain`: ", "None found" -Color Yellow, Cyan, Green
            }
        }
    }
    if (-not $ReportOnly) {
        $PendingCount = if ($Export['PendingDeletion']) { $Export['PendingDeletion'].Count } else { 0 }
        Write-Color -Text "[i] ", "Service accounts on pending list`: ", $(if ($PendingCount -gt 0) { $PendingCount } else { "None" }) -Color Yellow, Cyan, $(if ($PendingCount -gt 0) { 'Red' } else { 'Green' })
    }
    if ($Disable -and -not $ReportOnly) {
        $DisabledCount = if ($ReportDisabled) { $ReportDisabled.Count } else { 0 }
        Write-Color -Text "[i] ", "Service accounts disabled in this run`: ", $(if ($DisabledCount -gt 0) { $DisabledCount } else { "None" }) -Color Yellow, Cyan, $(if ($DisabledCount -gt 0) { 'Green' } else { 'DarkGray' })
    }
    if ($Delete -and -not $ReportOnly) {
        $DeletedCount = if ($ReportDeleted) { $ReportDeleted.Count } else { 0 }
        Write-Color -Text "[i] ", "Service accounts deleted in this run`: ", $(if ($DeletedCount -gt 0) { $DeletedCount } else { "None" }) -Color Yellow, Cyan, $(if ($DeletedCount -gt 0) { 'Green' } else { 'DarkGray' })
    }

    if ($Export -and $ReportPath) {
        [Array] $ServiceAccountsToProcess = foreach ($Domain in $Report.Keys) {
            if ($Report["$Domain"]['ServiceAccounts'].Count -gt 0) {
                $Report["$Domain"]['ServiceAccounts']
            }
        }
        $ServiceAccountsCount = $ServiceAccountsToProcess.Count
        Write-Color -Text "[i] ", "Service accounts to be processed for HTML report`: ", $(if ($ServiceAccountsCount -gt 0) { $ServiceAccountsCount } else { "None found" }) -Color Yellow, Cyan, $(if ($ServiceAccountsCount -gt 0) { 'Green' } else { 'DarkGray' })
        $Export.Statistics = New-ADServiceAccountsStatistics -ServiceAccountsToProcess $ServiceAccountsToProcess

        $newHTMLProcessedServiceAccountsSplat = @{
            Export                      = $Export
            FilePath                    = $ReportPath
            Online                      = $Online.IsPresent
            ShowHTML                    = $ShowHTML.IsPresent
            LogFile                     = $LogPath
            ServiceAccountsToProcess    = $ServiceAccountsToProcess
            DisableOnlyIf               = $DisableOnlyIf
            DeleteOnlyIf                = $DeleteOnlyIf
            Delete                      = $Delete
            Disable                     = $Disable
            ReportOnly                  = $ReportOnly
        }
        Write-Color "[i] ", "Generating HTML report ($ReportPath)" -Color Yellow, Magenta
        New-HTMLProcessedServiceAccounts @newHTMLProcessedServiceAccountsSplat
    }

    Write-Color -Text "[i] Finished process of cleaning up MSA/GMSA service accounts" -Color Green

    if (-not $Suppress) {
        $newEmailBodyServiceAccountsSplat = @{
            Export                   = $Export
            ServiceAccountsToProcess = $allServiceAccountsToProcess
            DisableOnlyIf           = $DisableOnlyIf
            DeleteOnlyIf            = $DeleteOnlyIf
            Delete                  = $Delete
            Disable                 = $Disable
            ReportOnly              = $ReportOnly
        }
        $Export.EmailBody = New-EmailBodyServiceAccounts @newEmailBodyServiceAccountsSplat
        $Export
    }
}
