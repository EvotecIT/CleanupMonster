function Invoke-ADComputersCleanup {
    <#
    .SYNOPSIS
    Active Directory Cleanup function that can disable or delete computers
    that have not been logged on for a certain amount of time.

    .DESCRIPTION
    Active Directory Cleanup function that can disable or delete computers
    that have not been logged on for a certain amount of time.
    It has many options to customize the cleanup process.

    .PARAMETER Disable
    Enable the disable process, meaning the computers that meet the criteria will be disabled.

    .PARAMETER Delete
    Enable the delete process, meaning the computers that meet the criteria will be deleted.

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

    .PARAMETER DisablePasswordLastSetOlderThan
    Disable computer only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER DisableLastLogonDateOlderThan
    Disable computer only if it has a LastLogonDate that is older than the specified date.

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

    .PARAMETER DeleteIsEnabled
    Delete computer only if it's Enabled or only if it's Disabled. By default it will try to delete all computers that are either disabled or enabled.

    .PARAMETER DeleteNoServicePrincipalName
    Delete computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
    By default it doesn't care if it has a ServicePrincipalName or not.

    .PARAMETER DeleteLastLogonDateMoreThan
    Delete computer only if it has a LastLogonDate that is more than the specified number of days.

    .PARAMETER DeletePasswordLastSetMoreThan
    Delete computer only if it has a PasswordLastSet that is more than the specified number of days.

    .PARAMETER DisablePasswordLastSetOlderThan
    Delete computer only if it has a PasswordLastSet that is older than the specified date.

    .PARAMETER DisableLastLogonDateOlderThan
    Delete computer only if it has a LastLogonDate that is older than the specified date.

    .PARAMETER DeleteListProcessedMoreThan
    Delete computer only if it has been processed by this script more than the specified number of days ago.
    This is useful if you want to delete computers that have been disabled for a certain amount of time.
    It uses XML file to store the list of processed computers, so please make sure to not remove it or it will start over.

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

    .PARAMETER DataStorePath
    Path to the XML file that will be used to store the list of processed computers, current run, and history data.
    Default is $PSScriptRoot\ProcessedComputers.xml

    .PARAMETER ReportOnly
    Only generate the report, don't disable or delete computers.

    .PARAMETER ReportMaximum
    Maximum number of reports to keep. Default is Unlimited (0).

    .PARAMETER WhatIfDelete
    WhatIf parameter for the Delete process.
    It's not nessessary to specify this parameter if you use WhatIf parameter which applies to both processes.

    .PARAMETER WhatIfDisable
    WhatIf parameter for the Disable process.
    It's not nessessary to specify this parameter if you use WhatIf parameter which applies to both processes.

    .PARAMETER LogPath
    Path to the log file. Default is no logging to file.

    .PARAMETER LogMaximum
    Maximum number of log files to keep. Default is 5.

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
        [switch] $Disable,
        [switch] $Delete,
        [nullable[bool]] $DisableIsEnabled,
        [nullable[bool]] $DisableNoServicePrincipalName = $null,
        [nullable[int]] $DisableLastLogonDateMoreThan = 180,
        [nullable[int]] $DisablePasswordLastSetMoreThan = 180,
        [nullable[DateTime]] $DisablePasswordLastSetOlderThan,
        [nullable[DateTime]] $DisableLastLogonDateOlderThan,
        [Array] $DisableExcludeSystems = @(),
        [Array] $DisableIncludeSystems = @(),
        [nullable[bool]] $DeleteIsEnabled,
        [nullable[bool]] $DeleteNoServicePrincipalName = $null,
        [nullable[int]] $DeleteLastLogonDateMoreThan = 180,
        [nullable[int]] $DeletePasswordLastSetMoreThan = 180,
        [nullable[int]] $DeleteListProcessedMoreThan,
        [nullable[DateTime]] $DeletePasswordLastSetOlderThan,
        [nullable[DateTime]] $DeleteLastLogonDateOlderThan,
        [Array] $DeleteExcludeSystems = @(),
        [Array] $DeleteIncludeSystems = @(),
        [int] $DeleteLimit = 1, # 0 = unlimited
        [int] $DisableLimit = 1, # 0 = unlimited
        [Array] $Exclusions = @(
            # default exclusions
            '*OU=Domain Controllers*'
        ),
        [switch] $DisableModifyDescription,
        [switch] $DisableModifyAdminDescription,
        [string] $Filter = '*',
        [string] $DataStorePath,
        [switch] $ReportOnly,
        [int] $ReportMaximum,
        [switch] $WhatIfDelete,
        [switch] $WhatIfDisable,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,
        [string] $ReportPath
    )

    # just in case user wants to use -WhatIf instead of -WhatIfDelete and -WhatIfDisable
    if (-not $WhatIfDelete -and -not $WhatIfDisable) {
        $WhatIfDelete = $WhatIfDisable = $WhatIfPreference
    }

    # lets enable global logging
    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum

    # prepare configuration
    $DisableOnlyIf = [ordered] @{
        IsEnabled                = $DisableIsEnabled
        NoServicePrincipalName   = $DisableNoServicePrincipalName
        LastLogonDateMoreThan    = $DisableLastLogonDateMoreThan
        PasswordLastSetMoreThan  = $DisablePasswordLastSetMoreThan
        ExcludeSystems           = $DisableExcludeSystems
        IncludeSystems           = $DisableIncludeSystems
        PasswordLastSetOlderThan = $DisablePasswordLastSetOlderThan
        LastLogonDateOlderThan   = $DisableLastLogonDateOlderThan
    }
    $DeleteOnlyIf = [ordered] @{
        IsEnabled                = $DeleteIsEnabled
        NoServicePrincipalName   = $DeleteNoServicePrincipalName
        LastLogonDateMoreThan    = $DeleteLastLogonDateMoreThan
        PasswordLastSetMoreThan  = $DeletePasswordLastSetMoreThan
        ListProcessedMoreThan    = $DeleteListProcessedMoreThan
        ExcludeSystems           = $DeleteExcludeSystems
        IncludeSystems           = $DeleteIncludeSystems
        PasswordLastSetOlderThan = $DeletePasswordLastSetOlderThan
        LastLogonDateOlderThan   = $DeleteLastLogonDateOlderThan
    }

    if (-not $DataStorePath) {
        $DataStorePath = $($MyInvocation.PSScriptRoot) + '\ProcessedComputers.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = $($MyInvocation.PSScriptRoot) + '\ProcessedComputers.html'
    }

    # lets create report path, reporting is enabled by default
    Set-ReportingCapabilities -ReportPath $ReportPath -ReportMaximum $ReportMaximum

    $Today = Get-Date
    $Properties = 'DistinguishedName', 'DNSHostName', 'SamAccountName', 'Enabled', 'OperatingSystem', 'OperatingSystemVersion', 'LastLogonDate', 'PasswordLastSet', 'PasswordExpired', 'servicePrincipalName', 'logonCount', 'ManagedBy', 'Description', 'WhenCreated', 'WhenChanged'

    $Export = [ordered] @{
        Version         = Get-GitHubVersion -Cmdlet 'Invoke-ADComputersCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun      = $null
        History         = $null
        PendingDeletion = $null
    }

    Write-Color '[i] ', "[CleanupMonster] ", 'Version', ' [Informative] ', $Export['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta
    Write-Color -Text "[i] Started process of cleaning up stale computers" -Color Green
    Write-Color -Text "[i] Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Green
    try {
        $Forest = Get-ADForest
    } catch {
        Write-Color -Text "[i] ", "Couldn't get forest. Terminating. Lack of domain contact? Error: $($_.Exception.Message)." -Color Yellow, Red
        return
    }

    if (-not $ReportOnly) {
        $ProcessedComputers = Import-ComputersData -Export $Export -DataStorePath $DataStorePath
    }

    if (-not $Disable -and -not $Delete) {
        Write-Color -Text "[i] ", "No action was taken. You need to enable Disable or/and Delete feature to have any action." -Color Yellow, Red
        return
    }

    $AllComputers = [ordered] @{}
    $Report = [ordered] @{ }
    foreach ($Domain in $Forest.Domains) {
        $Report["$Domain"] = @{ }
        $DC = Get-ADDomainController -Discover -DomainName $Domain
        $Server = $DC.HostName[0]
        $DomainInformation = Get-ADDomain -Identity $Domain -Server $Server
        $Report["$Domain"]['Server'] = $Server
        Write-Color "[i] Getting all computers for domain ", $Domain -Color Yellow, Magenta, Yellow
        [Array] $Computers = Get-ADComputer -Filter $Filter -Server $Server -Properties $Properties
        foreach ($Computer in $Computers) {
            $AllComputers[$($Computer.DistinguishedName)] = $Computer
        }
        Write-Color "[i] ", "Computers found for domain $Domain`: ", $($Computers.Count) -Color Yellow, Cyan, Green
        if ($Disable) {
            Write-Color "[i] ", "Processing computers to disable for domain $Domain" -Color Yellow, Cyan, Green
            Write-Color "[i] ", "Looking for computers with LastLogonDate more than ", $DisableLastLogonDateMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            Write-Color "[i] ", "Looking for computers with PasswordLastSet more than ", $DisablePasswordLastSetMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            if ($DisableNoServicePrincipalName) {
                Write-Color "[i] ", "Looking for computers with no ServicePrincipalName" -Color Yellow, Cyan, Green
            }
            $Report["$Domain"]['ComputersToBeDisabled'] = @(
                Get-ADComputersToDisable -Computers $Computers -DisableOnlyIf $DisableOnlyIf -Exclusions $Exclusions -DomainInformation $DomainInformation -ProcessedComputers $ProcessedComputers
            )
        }
        if ($Delete) {
            Write-Color "[i] ", "Processing computers to delete for domain $Domain" -Color Yellow, Cyan, Green
            Write-Color "[i] ", "Looking for computers with LastLogonDate more than ", $DeleteLastLogonDateMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            Write-Color "[i] ", "Looking for computers with PasswordLastSet more than ", $DeletePasswordLastSetMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            if ($DeleteNoServicePrincipalName) {
                Write-Color "[i] ", "Looking for computers with no ServicePrincipalName" -Color Yellow, Cyan, Green
            }
            if ($null -ne $DeleteIsEnabled) {
                if ($DeleteIsEnabled) {
                    Write-Color "[i] ", "Looking for computers that are enabled" -Color Yellow, Cyan, Green
                } else {
                    Write-Color "[i] ", "Looking for computers that are disabled" -Color Yellow, Cyan, Green
                }
            }
            $Report["$Domain"]['ComputersToBeDeleted'] = @(
                Get-ADComputersToDelete -Computers $Computers -DeleteOnlyIf $DeleteOnlyIf -Exclusions $Exclusions -DomainInformation $DomainInformation -ProcessedComputers $ProcessedComputers
            )
        }
    }

    foreach ($Domain in $Report.Keys) {
        if ($Disable) {
            if ($DisableLimit -eq 0) {
                $DisableLimitText = 'Unlimited'
            } else {
                $DisableLimitText = $DisableLimit
            }
            # $ComputersToBeDisabled = if ($null -ne $Report["$Domain"]['ComputersToBeDisabled']) { $Report["$Domain"]['ComputersToBeDisabled'].Count } else { 0 }
            Write-Color "[i] ", "Computers to be disabled for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDisabled'].Count, ". Current disable limit: ", $DisableLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }
        if ($Delete) {
            if ($DeleteLimit -eq 0) {
                $DeleteLimitText = 'Unlimited'
            } else {
                $DeleteLimitText = $DeleteLimit
            }
            #$ComputersToBeDeleted = if ($null -ne $Report["$Domain"]['ComputersToBeDeleted']) { $Report["$Domain"]['ComputersToBeDeleted'].Count } else { 0 }
            Write-Color "[i] ", "Computers to be deleted for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDeleted'].Count, ". Current delete limit: ", $DeleteLimitText -Color Yellow, Cyan, Green, Cyan, Yellow
        }
    }

    if ($Disable) {
        $CountDisable = 0
        # :top means name of the loop, so we can break it
        [Array] $ReportDisabled = :topLoop foreach ($Domain in $Report.Keys) {
            Write-Color "[i] ", "Starting process of disabling computers for domain $Domain" -Color Yellow, Green
            foreach ($Computer in $Report["$Domain"]['ComputersToBeDisabled']) {
                $Server = $Report["$Domain"]['Server']
                if ($ReportOnly) {
                    $Computer
                } else {
                    Write-Color -Text "[i] Disabling computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                    try {
                        Disable-ADAccount -Identity $Computer.DistinguishedName -Server $Server -WhatIf:$WhatIfDisable -ErrorAction Stop
                        Write-Color -Text "[+] Disabling computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) successful." -Color Yellow, Green, Yellow
                        Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 1000 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) successful." -AdditionalFields @('Disable', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable) -WarningAction SilentlyContinue -WarningVariable warnings
                        foreach ($W in $Warnings) {
                            Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                        }
                        $Success = $true
                    } catch {
                        $Computer.ActionComment = $_.Exception.Message
                        $Success = $false
                        Write-Color -Text "[-] Disabling computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        Write-Event -ID 10 -LogName 'Application' -EntryType Error -Category 1001 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) failed. Error: $($_.Exception.Message)" -AdditionalFields @('Disable', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                        foreach ($W in $Warnings) {
                            Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                        }
                    }
                    if ($Success) {
                        if ($DisableModifyDescription -eq $true) {
                            $DisableModifyDescriptionText = "Disabled by a script, LastLogon $($Computer.LastLogonDate) ($($DisableOnlyIf.LastLogonDateMoreThan)), PasswordLastSet $($Computer.PasswordLastSet) ($($DisableOnlyIf.PasswordLastSetMoreThan))"
                            try {
                                Set-ADComputer -Identity $Computer.DistinguishedName -Description $DisableModifyDescriptionText -WhatIf:$WhatIfDisable -ErrorAction Stop -Server $Server
                                Write-Color -Text "[+] ", "Setting description on disabled computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) successful. Set to: ", $DisableModifyDescriptionText -Color Yellow, Green, Yellow, Green, Yellow
                            } catch {
                                $Computer.ActionComment = $Computer.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                                Write-Color -Text "[-] ", "Setting description on disabled computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                            }
                        }
                        if ($DisableModifyAdminDescription) {
                            $DisableModifyAdminDescriptionText = "Disabled by a script, LastLogon $($Computer.LastLogonDate) ($($DisableOnlyIf.LastLogonDateMoreThan)), PasswordLastSet $($Computer.PasswordLastSet) ($($DisableOnlyIf.PasswordLastSetMoreThan))"
                            try {
                                Set-ADObject -Identity $Computer.DistinguishedName -Replace @{ AdminDescription = $DisableModifyAdminDescriptionText } -WhatIf:$WhatIfDisable -ErrorAction Stop -Server $Server
                                Write-Color -Text "[+] ", "Setting admin description on disabled computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) successful. Set to: ", $DisableModifyAdminDescriptionText -Color Yellow, Green, Yellow, Green, Yellow
                            } catch {
                                $Computer.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                                Write-Color -Text "[-] ", "Setting admin description on disabled computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                            }
                        }
                    }

                    # this is to store actual disabling time - we can't trust WhenChanged date
                    $Computer.ActionDate = $Today
                    if ($WhatIfDisable.IsPresent) {
                        $Computer.ActionStatus = 'WhatIf'
                    } else {
                        $Computer.ActionStatus = $Success
                    }
                    $ProcessedComputers["$($Computer.DistinguishedName)"] = $Computer
                    # return computer to $ReportDisabled so we can see summary just in case
                    $Computer
                    $CountDisable++
                    if ($DisableLimit) {
                        if ($DisableLimit -eq $CountDisable) {
                            break topLoop # this breaks top loop
                        }
                    }
                }
            }
        }
    }

    if ($Delete) {
        $CountDeleteLimit = 0
        # :top means name of the loop, so we can break it
        [Array] $ReportDeleted = :topLoop foreach ($Domain in $Report.Keys) {
            foreach ($Computer in $Report["$Domain"]['ComputersToBeDeleted']) {
                $Server = $Report["$Domain"]['Server']
                if ($ReportOnly) {
                    $Computer
                } else {
                    Write-Color -Text "[i] Deleting computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                    try {
                        $Success = $true
                        Remove-ADObject -Identity $Computer.DistinguishedName -Recursive -WhatIf:$WhatIfDelete -Server $Server -ErrorAction Stop -Confirm:$false
                        Write-Color -Text "[+] Deleting computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDelete.IsPresent)) successful." -Color Yellow, Green, Yellow
                        Write-Event -ID 10 -LogName 'Application' -EntryType Warning -Category 1000 -Source 'CleanupComputers' -Message "Deleting computer $($Computer.SamAccountName) successful." -AdditionalFields @('Delete', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDelete) -WarningAction SilentlyContinue -WarningVariable warnings
                        foreach ($W in $Warnings) {
                            Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                        }

                    } catch {
                        $Success = $false
                        Write-Color -Text "[-] Deleting computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDelete.IsPresent)) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        Write-Event -ID 10 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Deleting computer $($Computer.SamAccountName) failed." -AdditionalFields @('Delete', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDelete, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                        foreach ($W in $Warnings) {
                            Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                        }
                        $Computer.ActionComment = $_.Exception.Message
                    }
                    $Computer.ActionDate = $Today
                    if ($WhatIfDelete.IsPresent) {
                        $Computer.ActionStatus = 'WhatIf'
                    } else {
                        $Computer.ActionStatus = $Success
                    }
                    $ProcessedComputers.Remove("$($Computer.DistinguishedName)")

                    # return computer to $ReportDeleted so we can see summary just in case
                    $Computer
                    $CountDeleteLimit++
                    if ($DeleteLimit) {
                        if ($DeleteLimit -eq $CountDeleteLimit) {
                            break topLoop # this breaks top loop
                        }
                    }
                }
            }
        }
    }

    Write-Color "[i] ", "Cleanup process for processed computers that no longer exists in AD" -Color Yellow, Green
    foreach ($DN in [string[]] $ProcessedComputers.Keys) {
        if (-not $AllComputers["$($DN)"]) {
            Write-Color -Text "[*] Removing computer from pending list ", $ProcessedComputers[$DN].SamAccountName, " ($DN)" -Color Yellow, Green, Yellow
            $ProcessedComputers.Remove("$($DN)")
        }
    }

    # Building up summary
    $Export.PendingDeletion = $ProcessedComputers
    $Export.CurrentRun = @($ReportDisabled + $ReportDeleted)
    $Export.History = @($Export.History + $ReportDisabled + $ReportDeleted)

    #if ($DeleteListProcessedMoreThan) {
    Write-Color "[i] ", "Exporting Processed List" -Color Yellow, Magenta
    if (-not $ReportOnly) {
        try {
            $Export | Export-Clixml -LiteralPath $DataStorePath -Encoding Unicode -WhatIf:$false -ErrorAction Stop
        } catch {
            Write-Color -Text "[-] Exporting Processed List failed. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    }
    Write-Color -Text "[i] ", "Summary of cleaning up stale computers" -Color Yellow, Cyan
    foreach ($Domain in $Report.Keys | Where-Object { $_ -notin 'ReportPendingDeletion', 'ReportDisabled', 'ReportDeleted' }) {
        if ($Disable) {
            Write-Color -Text "[i] ", "Computers to be disabled for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDisabled'].Count -Color Yellow, Cyan, Green
        }
        if ($Delete) {
            Write-Color -Text "[i] ", "Computers to be deleted for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDeleted'].Count -Color Yellow, Cyan, Green
        }
    }
    if (-not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers pending deletion`:", $Report['ReportPendingDeletion'].Count -Color Yellow, Cyan, Green
    }
    if ($Disable -and -not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers disabled in this run`: ", $ReportDisabled.Count -Color Yellow, Cyan, Green
    }
    if ($Delete -and -not $ReportOnly) {
        Write-Color -Text "[i] ", "Computers deleted in this run`: ", $ReportDeleted.Count -Color Yellow, Cyan, Green
    }

    if ($Export -and $ReportPath) {
        Write-Color "[i] ", "Generating HTML report ($ReportPath)" -Color Yellow, Magenta
        $ComputersToProcess = foreach ($Domain in $Report.Keys | Where-Object { $_ -notin 'ReportPendingDeletion', 'ReportDisabled', 'ReportDeleted' }) {
            if ($Report["$Domain"]['ComputersToBeDisabled'].Count -gt 0) {
                $Report["$Domain"]['ComputersToBeDisabled']
            }
            if ($Report["$Domain"]['ComputersToBeDeleted'].Count -gt 0) {
                $Report["$Domain"]['ComputersToBeDeleted']
            }
        }

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
            Delete             = $Delete
            Disable            = $Disable
            ReportOnly         = $ReportOnly
        }
        New-HTMLProcessedComputers @newHTMLProcessedComputersSplat
    }

    Write-Color -Text "[i] Finished process of cleaning up stale computers" -Color Green

    if (-not $Suppress) {
        $Export
    }
}