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

    $Report = [ordered]@{}
    foreach ($Domain in $ForestInformation.Domains) {
        $Server = $ForestInformation['QueryServers'][$Domain].HostName[0]
        Write-Color -Text "[i] ", "Getting service accounts for domain ", $Domain, " from ", $Server -Color Yellow, Magenta, Yellow, Magenta
        [Array]$Accounts = Get-ADServiceAccount -Filter * -Server $Server -Properties SamAccountName,Enabled,LastLogonDate,PasswordLastSet,WhenCreated,DistinguishedName,ObjectClass | Where-Object { $_.ObjectClass -in 'msDS-ManagedServiceAccount','msDS-GroupManagedServiceAccount' }
        foreach ($Account in $Accounts) {
            $Account | Add-Member -NotePropertyName DomainName -NotePropertyValue $Domain
            $Account | Add-Member -NotePropertyName Server -NotePropertyValue $Server
        }
        if ($IncludeAccounts) {
            $Accounts = foreach ($A in $Accounts) {
                foreach ($Inc in $IncludeAccounts) { if ($A.SamAccountName -like $Inc) { $A; break } }
            }
        }
        if ($ExcludeAccounts) {
            $Accounts = foreach ($A in $Accounts) {
                $Skip = $false
                foreach ($Exc in $ExcludeAccounts) { if ($A.SamAccountName -like $Exc) { $Skip = $true; break } }
                if (-not $Skip) { $A }
            }
        }
        $Report[$Domain] = [ordered]@{ Server = $Server; Accounts = $Accounts }
    }

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
    $Export.History = $Processed

    if ($ReportPath) {
        New-HTML -Title 'Service Accounts Cleanup' -FilePath $ReportPath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent {
            New-HTMLTable -DataTable $Export.CurrentRun -Filtering -ScrollX
        }
    }

    Write-Color -Text "[i] Finished process of cleaning up service accounts" -Color Green
    if (-not $Suppress) { $Export }
}
