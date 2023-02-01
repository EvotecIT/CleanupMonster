function Invoke-ADComputersCleanup {
    [CmdletBinding()]
    param(
        [nullable[bool]] $DisableIsEnabled = $null,
        [nullable[bool]] $DisableNoServicePrincipalName = $null,
        [int] $DisableLastLogonDateMoreThan = 60,
        [int] $DisablePasswordLastSetMoreThan = 60,
        [Array] $DisableExcludeSystems = @(),
        [Array] $DisableIncludeSystems = @(),
        [nullable[bool]] $DeleteIsEnabled = $null,
        [nullable[bool]] $DeleteNoServicePrincipalName = $null,
        [int] $DeleteLastLogonDateMoreThan = 60,
        [int] $DeletePasswordLastSetMoreThan = 60,
        [int] $DeleteListProcessedMoreThan = 90,
        [Array] $DeleteExcludeSystems = @(),
        [Array] $DeleteIncludeSystems = @(),
        [int] $DeleteLimit = 1, # 0 means unlimited
        [int] $DisableLimit = 1,
        [Array] $Exclusions = @('OU=Domain Controllers'),
        [switch] $DisableModifyDescription,
        [string] $Filter = '*',
        [string] $ListProcessed,
        [switch] $ReportOnly,
        [switch] $WhatIfDelete,
        [switch] $WhatIfDisable,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,
        [string] $ReportPath
    )

    Set-LoggingCapabilities -Configuration @{
        LogPath    = $LogPath
        LogMaximum = $LogMaximum
    }

    $DisableOnlyIf = [ordered] @{
        IsEnabled               = $DisableIsEnabled
        NoServicePrincipalName  = $DisableNoServicePrincipalName
        LastLogonDateMoreThan   = $DisableLastLogonDateMoreThan
        PasswordLastSetMoreThan = $DisablePasswordLastSetMoreThan
        ExcludeSystems          = $DisableExcludeSystems
        IncludeSystems          = $DisableIncludeSystems
    }
    $DeleteOnlyIf = [ordered] @{
        IsEnabled               = $DeleteIsEnabled
        NoServicePrincipalName  = $DeleteNoServicePrincipalName
        LastLogonDateMoreThan   = $DeleteLastLogonDateMoreThan
        PasswordLastSetMoreThan = $DeletePasswordLastSetMoreThan
        ListProcessedMoreThan   = $DeleteListProcessedMoreThan
        ExcludeSystems          = $DeleteExcludeSystems
        IncludeSystems          = $DeleteIncludeSystems
    }

    $Today = Get-Date
    $Properties = 'DistinguishedName', 'DNSHostName', 'SamAccountName', 'Enabled', 'OperatingSystem', 'OperatingSystemVersion', 'LastLogonDate', 'PasswordLastSet', 'PasswordExpired', 'servicePrincipalName', 'logonCount', 'ManagedBy', 'Description', 'WhenCreated', 'WhenChanged'
    Write-Color -Text "[i] Started process of cleaning up stale computers" -Color Green
    Write-Color -Text "[i] Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Green
    try {
        $Forest = Get-ADForest
    } catch {
        Write-Color -Text "[i] Couldn't get forest. Terminating. Lack of domain contact? - $($_.Exception.Message)." -Color Red
        return
    }
    try {
        $ProcessedComputers = Get-ProcessedComputers -FilePath $ListProcessed
        if (-not $ProcessedComputers) {
            $ProcessedComputers = [ordered] @{ }
        }
    } catch {
        Write-Color -Text "[i] couldn't read the list or wrong format." -Color Red
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
        Write-Color "[i] Getting all computers for domain $Domain" -Color Yellow
        [Array] $Computers = Get-ADComputer -Filter * -Server $Server -Properties $Properties
        foreach ($Computer in $Computers) {
            $AllComputers[$($Computer.DistinguishedName)] = $Computer
        }
        Write-Color "[i] Computers found for domain $Domain`: ", $($Computers.Count) -Color Yellow, Green
        Write-Color "[i] Processing computers to disable for domain $Domain" -Color Yellow
        $Report["$Domain"]['ComputersToBeDisabled'] = Get-ADComputersToDisable -Computers $Computers -DisableOnlyIf $DisableOnlyIf -Exclusions $Exclusions -DomainInformation $DomainInformation -ProcessedComputers $ProcessedComputers
        Write-Color "[i] Processing computers to delete for domain $Domain" -Color Yellow
        $Report["$Domain"]['ComputersToBeDeleted'] = Get-ADComputersToDelete -Computers $Computers -DeleteOnlyIf $DeleteOnlyIf -Exclusions $Exclusions -DomainInformation $DomainInformation -ProcessedComputers $ProcessedComputers
    }

    foreach ($Domain in $Report.Keys) {
        Write-Color "[i] Computers to be disabled for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDisabled'].Count -Color Yellow, Green
        Write-Color "[i] Computers to be deleted for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDeleted'].Count -Color Yellow, Green
    }

    $CountDisable = 0
    # :top means name of the loop, so we can break it
    [Array] $ReportDisabled = :topLoop foreach ($Domain in $Report.Keys) {
        Write-Color "[i] ", "Starting process of disabling computers for domain $Domain" -Color Yellow, Green
        foreach ($Computer in $Report["$Domain"]['ComputersToBeDisabled']) {
            $Server = $Report["$Domain"]['Server']
            if ($ReportOnly) {
                $Computer
            } else {
                Write-Color -Text "[i] Disabling computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, ' PasswordLastSet:', $Computer.PasswordLastSet -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                try {
                    Disable-ADAccount -Identity $Computer.DistinguishedName -Server $Server -WhatIf:$WhatIfDisable -ErrorAction Stop
                    Write-Color -Text "[+] Disabling computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) successful." -Color Yellow, Green, Yellow
                    Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 1000 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) successful." -AdditionalFields @('Disable', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable)
                    $DisabledSuccess = $true
                } catch {
                    $DisabledSuccess = $false
                    Write-Color -Text "[-] Disabling computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                    Write-Event -ID 10 -LogName 'Application' -EntryType Error -Category 1001 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) failed. Error: $($_.Exception.Message)" -AdditionalFields @('Disable', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable, $($_.Exception.Message))
                }
                if ($DisabledSuccess) {
                    if ($DisableModifyDescription -eq $true) {
                        $DisableModifyDescriptionText = "Disabled by a script, LastLogon $($Computer.LastLogonDate) ($($DisableOnlyIf.LastLogonDateMoreThan)), PasswordLastSet $($Computer.PasswordLastSet) ($($DisableOnlyIf.PasswordLastSetMoreThan))"
                        try {
                            Set-ADComputer -Identity $Computer.DistinguishedName -Description $DisableModifyDescriptionText -WhatIf:$WhatIfDisable -ErrorAction Stop -Server $Server
                            Write-Color -Text "[+] Setting description on disabled computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) successful. Set to: ", $DisableModifyDescriptionText -Color Yellow, Green, Yellow, Green, Yellow
                        } catch {
                            Write-Color -Text "[-] Setting description on disabled computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        }

                    }
                }

                # this is to store actual disabling time - we can't trust WhenChanged date
                $Computer.DateDisabled = $Today
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

    $CountDeleteLimit = 0
    # :top means name of the loop, so we can break it
    [Array] $ReportDeleted = :topLoop foreach ($Domain in $Report.Keys) {
        foreach ($Computer in $Report["$Domain"]['ComputersToBeDeleted']) {
            $Server = $Report["$Domain"]['Server']
            if ($ReportOnly) {
                $Computer
            } else {
                Write-Color -Text "[i] Deleting computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, ' PasswordLastSet:', $Computer.PasswordLastSet -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                try {
                    Remove-ADObject -Identity $Computer.DistinguishedName -Recursive -WhatIf:$WhatIfDelete -Server $Server -ErrorAction Stop -Confirm:$false
                    Write-Color -Text "[+] Deleting computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) successful." -Color Yellow, Green, Yellow
                    Write-Event -ID 10 -LogName 'Application' -EntryType Warning -Category 1000 -Source 'CleanupComputers' -Message "Deleting computer $($Computer.SamAccountName) successful." -AdditionalFields @('Delete', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDelete)
                } catch {
                    Write-Color -Text "[-] Deleting computer ", $Computer.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                    Write-Event -ID 10 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Deleting computer $($Computer.SamAccountName) failed." -AdditionalFields @('Delete', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDelete, $($_.Exception.Message))
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

    Write-Color "[i] ", "Cleanup process for processed computers that no longer exists in AD" -Color Yellow, Green
    foreach ($DN in [string[]] $ProcessedComputers.Keys) {
        if (-not $AllComputers["$($DN)"]) {
            Write-Color -Text "[*] Removing computer from pending list ", $ProcessedComputers[$DN].SamAccountName, " ($DN)" -Color Yellow, Green, Yellow
            $ProcessedComputers.Remove("$($DN)")
        }
    }
    Write-Color "[i] ", "Exporting Processed List" -Color Yellow, Green
    $ProcessedComputers | Export-Clixml -LiteralPath $ListProcessed -Encoding Unicode
    # Building up summary
    $Report.ReportPendingDeletion = $ProcessedComputers.Values
    $Report.ReportDisabled = $ReportDisabled
    $Report.ReportDeleted = $ReportDeleted
    if (-not $Suppress) {
        $Report
    }

    Write-Color -Text "[i] ", "Summary of cleaning up stale computers" -Color Yellow, Cyan
    foreach ($Domain in $Report.Keys | Where-Object { $_ -notin 'ReportPendingDeletion', 'ReportDisabled', 'ReportDeleted' }) {
        Write-Color -Text "[i] ", "Computers to be disabled for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDisabled'].Count -Color Yellow, Cyan, Green
        Write-Color -Text "[i] ", "Computers to be deleted for domain $Domain`: ", $Report["$Domain"]['ComputersToBeDeleted'].Count -Color Yellow, Cyan, Green
    }
    Write-Color -Text "[i] ", " Computers pending deletion`:", $Report['ReportPendingDeletion'].Count -Color Yellow, Cyan, Green
    Write-Color -Text "[i] ", " Computers disabled in this run`: ", $Report['ReportDisabled'].Count -Color Yellow, Cyan, Green
    Write-Color -Text "[i] ", " Computers deleted in this run`: ", $Report['ReportDeleted'].Count -Color Yellow, Cyan, Green


    if ($Report -and $ReportPath) {
        Write-Color "[i] ", "Generating HTML report" -Color Yellow, Cyan
        New-HTMLProcessedComputers -Report $Report -FilePath $ReportPath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent -LogFile $LogPath
    }

    Write-Color -Text "[i] Finished process of cleaning up stale computers" -Color Green
}