function Invoke-ADServiceAccountsCleanup {
    <#
    .SYNOPSIS
    Cleans up stale Active Directory service accounts.

    .DESCRIPTION
    Enumerates managed service accounts in Active Directory and disables or deletes
    accounts based on inactivity or age criteria.

    .PARAMETER Forest
    Forest to use when connecting to Active Directory.

    .PARAMETER IncludeDomains
    List of domains to include in the process.

    .PARAMETER ExcludeDomains
    List of domains to exclude from the process.

    .PARAMETER IncludeAccounts
    Include only service accounts that match these names (supports wildcards).

    .PARAMETER ExcludeAccounts
    Exclude service accounts that match these names (supports wildcards).

    .PARAMETER Disable
    Enable disabling of matching service accounts.

    .PARAMETER Delete
    Enable deletion of matching service accounts.

    .PARAMETER DisableLastLogonDateMoreThan
    Disable accounts that have not logged on for the specified number of days.

    .PARAMETER DisablePasswordLastSetMoreThan
    Disable accounts where password has not been changed for the specified number of days.

    .PARAMETER DisableWhenCreatedMoreThan
    Disable accounts created more than the specified number of days ago.

    .PARAMETER DeleteLastLogonDateMoreThan
    Delete accounts that have not logged on for the specified number of days.

    .PARAMETER DeletePasswordLastSetMoreThan
    Delete accounts where password has not been changed for the specified number of days.

    .PARAMETER DeleteWhenCreatedMoreThan
    Delete accounts created more than the specified number of days ago.

    .PARAMETER ReportOnly
    Only report accounts that would be processed.

    .PARAMETER ReportPath
    Path to save optional HTML report.

    .PARAMETER ShowHTML
    Show HTML report in a browser.

    .PARAMETER Online
    Use online resources (CDN) for HTML report.

    .PARAMETER WhatIfDisable
    Shows what would happen if accounts were disabled.

    .PARAMETER WhatIfDelete
    Shows what would happen if accounts were deleted.

    .EXAMPLE
    Invoke-ADServiceAccountsCleanup -Disable -DisableLastLogonDateMoreThan 90 -ReportOnly

    .EXAMPLE
    Invoke-ADServiceAccountsCleanup -Delete -DeleteLastLogonDateMoreThan 180 -WhatIfDelete
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Forest,
        [alias('Domain')][string[]] $IncludeDomains,
        [string[]] $ExcludeDomains,
        [string[]] $IncludeAccounts,
        [string[]] $ExcludeAccounts,
        [switch] $Disable,
        [switch] $Delete,
        [int] $DisableLastLogonDateMoreThan,
        [int] $DisablePasswordLastSetMoreThan,
        [int] $DisableWhenCreatedMoreThan,
        [int] $DeleteLastLogonDateMoreThan,
        [int] $DeletePasswordLastSetMoreThan,
        [int] $DeleteWhenCreatedMoreThan,
        [switch] $ReportOnly,
        [string] $ReportPath,
        [switch] $ShowHTML,
        [switch] $Online,
        [switch] $WhatIfDisable,
        [switch] $WhatIfDelete,
        [switch] $DontWriteToEventLog,
        [switch] $Suppress,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $LogShowTime,
        [string] $LogTimeFormat
    )

    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    $Export = [ordered]@{
        Date    = Get-Date
        Version = Get-GitHubVersion -Cmdlet 'Invoke-ADServiceAccountsCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun = @()
        History = @()
    }

    Write-Color -Text "[i] ", "Started process of cleaning up service accounts" -Color Yellow, White
    Write-Color -Text "[i] ", "Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Yellow, White, Green, White

    try {
        $ForestInformation = Get-WinADForestDetails -PreferWritable -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains
    } catch {
        Write-Color -Text "[i] ", "Couldn't get forest. Terminating. Error: $($_.Exception.Message)." -Color Yellow, Red
        return
    }

    if (-not $Disable -and -not $Delete) {
        Write-Color -Text "[i] ", "No action can be taken. Enable Disable and/or Delete." -Color Yellow, Red
        return
    }

    $Report = Get-InitialADServiceAccounts -ForestInformation $ForestInformation -IncludeAccounts $IncludeAccounts -ExcludeAccounts $ExcludeAccounts

    $Today = Get-Date
    [Array]$Processed = @()
    foreach ($Domain in $Report.Keys) {
        $Accounts = $Report[$Domain]['Accounts']
        if ($Disable) {
            $DisableOnlyIf = @{ LastLogonDateMoreThan = $DisableLastLogonDateMoreThan; PasswordLastSetMoreThan = $DisablePasswordLastSetMoreThan; WhenCreatedMoreThan = $DisableWhenCreatedMoreThan }
            $ToDisable = Get-ADServiceAccountsToProcess -Type 'Disable' -Accounts $Accounts -ActionIf $DisableOnlyIf -Exclusions $ExcludeAccounts
            $Report[$Domain]['AccountsToBeDisabled'] = $ToDisable.Count
            $Processed += Request-ADServiceAccountsDisable -Accounts $ToDisable -ReportOnly:$ReportOnly -WhatIfDisable:$WhatIfDisable -Today $Today -DontWriteToEventLog:$DontWriteToEventLog
        }
        if ($Delete) {
            $DeleteOnlyIf = @{ LastLogonDateMoreThan = $DeleteLastLogonDateMoreThan; PasswordLastSetMoreThan = $DeletePasswordLastSetMoreThan; WhenCreatedMoreThan = $DeleteWhenCreatedMoreThan }
            $ToDelete = Get-ADServiceAccountsToProcess -Type 'Delete' -Accounts $Accounts -ActionIf $DeleteOnlyIf -Exclusions $ExcludeAccounts
            $Report[$Domain]['AccountsToBeDeleted'] = $ToDelete.Count
            $Processed += Request-ADServiceAccountsDelete -Accounts $ToDelete -ReportOnly:$ReportOnly -WhatIfDelete:$WhatIfDelete -Today $Today -DontWriteToEventLog:$DontWriteToEventLog
        }
    }

    $Export.CurrentRun = $Processed
    $Export.History    = $Processed

    foreach ($Domain in $Report.Keys) {
        if ($Disable) {
            Write-Color -Text "[i] ", "Accounts to be disabled for domain $Domain`: ", $Report[$Domain]['AccountsToBeDisabled'] -Color Yellow, Cyan, Green
        }
        if ($Delete) {
            Write-Color -Text "[i] ", "Accounts to be deleted for domain $Domain`: ", $Report[$Domain]['AccountsToBeDeleted'] -Color Yellow, Cyan, Green
        }
    }

    if ($Export -and $ReportPath) {
        [Array] $AccountsToProcess = foreach ($Domain in $Report.Keys) { $Report[$Domain]['Accounts'] }
        $newHTMLProcessedServiceAccountsSplat = @{
            Export            = $Export
            FilePath          = $ReportPath
            Online            = $Online.IsPresent
            ShowHTML          = $ShowHTML.IsPresent
            LogFile           = $LogPath
            AccountsToProcess = $AccountsToProcess
            DisableOnlyIf     = $DisableOnlyIf
            DeleteOnlyIf      = $DeleteOnlyIf
            Disable           = $Disable
            Delete            = $Delete
            ReportOnly        = $ReportOnly
        }
        Write-Color -Text "[i] ", "Generating HTML report ($ReportPath)" -Color Yellow, Magenta
        New-HTMLProcessedServiceAccounts @newHTMLProcessedServiceAccountsSplat
    }

    Write-Color -Text "[i] Finished process of cleaning up service accounts" -Color Green
    if (-not $Suppress) { $Export }
}
