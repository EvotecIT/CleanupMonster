function Request-ADServiceAccountsDisable {
    <#
    .SYNOPSIS
    Processes service accounts for disabling.

    .DESCRIPTION
    This function processes service accounts that meet the criteria for disabling.
    It can optionally modify descriptions and handle the actual disabling operation.
    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [nullable[bool]] $Delete,
        [System.Collections.IDictionary] $Report,
        [switch] $WhatIfDisable,
        [switch] $DisableModifyDescription,
        [switch] $DisableModifyAdminDescription,
        [int] $DisableLimit,
        [switch] $ReportOnly,
        [DateTime] $Today,
        [switch] $DontWriteToEventLog,
        [switch] $DoNotAddToPendingList,
        [switch] $RemoveProtectedFromAccidentalDeletionFlag
    )

    $CountDisable = 0
    $ReportDisabled = @()

    # Process each domain
    :topLoop foreach ($Domain in $Report.Keys) {
        Write-Color "[i] ", "Starting process of disabling service accounts for domain $Domain" -Color Yellow, Green
        foreach ($ServiceAccount in $Report["$Domain"]['ServiceAccounts']) {
            $Server = $Report["$Domain"]['Server']
            if ($ServiceAccount.Action -ne 'Disable') {
                continue
            }
            if ($ReportOnly) {
                $ReportDisabled += $ServiceAccount
            } else {
                $Success = $true

                # Perform the actual disable operation
                if ($PSCmdlet.ShouldProcess($ServiceAccount.DistinguishedName, "Disable Service Account")) {
                    try {
                        Set-ADServiceAccount -Identity $ServiceAccount.DistinguishedName -Enabled $false -WhatIf:$WhatIfDisable -ErrorAction Stop -Server $Server
                        Write-Color -Text "[+] ", "Disabling service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDisable) successful" -Color Yellow, Green, Yellow, Green

                        if (-not $DontWriteToEventLog -and -not $WhatIfDisable) {
                            Write-WinEvent -LogName 'Application' -Source 'CleanupMonster' -EntryType Information -EventId 100 -Message "Service account $($ServiceAccount.SamAccountName) has been disabled by CleanupMonster."
                        }
                    } catch {
                        $ServiceAccount.ActionComment = $ServiceAccount.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                        Write-Color -Text "[-] ", "Disabling service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        $Success = $false
                    }
                }

                if ($Success) {
                    if ($DisableModifyDescription -eq $true) {
                        $DisableModifyDescriptionText = "Disabled by CleanupMonster script on $($Today.ToString('yyyy-MM-dd HH:mm:ss')), PasswordLastSet: $($ServiceAccount.PasswordLastSet)"
                        try {
                            Set-ADServiceAccount -Identity $ServiceAccount.DistinguishedName -Description $DisableModifyDescriptionText -WhatIf:$WhatIfDisable -ErrorAction Stop -Server $Server
                            Write-Color -Text "[+] ", "Setting description on disabled service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDisable) successful. Set to: ", $DisableModifyDescriptionText -Color Yellow, Green, Yellow, Green, Yellow
                        } catch {
                            $ServiceAccount.ActionComment = $ServiceAccount.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                            Write-Color -Text "[-] ", "Setting description on disabled service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        }
                    }
                    if ($DisableModifyAdminDescription) {
                        $DisableModifyAdminDescriptionText = "Disabled by CleanupMonster script on $($Today.ToString('yyyy-MM-dd HH:mm:ss')), PasswordLastSet: $($ServiceAccount.PasswordLastSet)"
                        try {
                            Set-ADObject -Identity $ServiceAccount.DistinguishedName -Replace @{ AdminDescription = $DisableModifyAdminDescriptionText } -WhatIf:$WhatIfDisable -ErrorAction Stop -Server $Server
                            Write-Color -Text "[+] ", "Setting admin description on disabled service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDisable) successful. Set to: ", $DisableModifyAdminDescriptionText -Color Yellow, Green, Yellow, Green, Yellow
                        } catch {
                            $ServiceAccount.ActionComment = $ServiceAccount.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                            Write-Color -Text "[-] ", "Setting admin description on disabled service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        }
                    }
                }

                # Set action metadata
                $ServiceAccount.ActionDate = $Today
                if ($WhatIfDisable.IsPresent) {
                    $ServiceAccount.ActionStatus = 'WhatIf'
                } else {
                    $ServiceAccount.ActionStatus = $Success
                }

                # Add to pending list if needed
                if (-not $DoNotAddToPendingList) {
                    $DomainName = ConvertFrom-DistinguishedName -DistinguishedName $ServiceAccount.DistinguishedName -ToDomainCN
                    $FullServiceAccountName = -join ($ServiceAccount.SamAccountName, '@', $DomainName)
                    $ServiceAccount.TimeOnPendingList = 0
                    $ProcessedServiceAccounts[$FullServiceAccountName] = $ServiceAccount
                }

                $ReportDisabled += $ServiceAccount
                $CountDisable++

                # Check disable limit
                if ($DisableLimit -gt 0 -and $CountDisable -ge $DisableLimit) {
                    Write-Color -Text "[i] ", "Disable limit reached ($DisableLimit). Stopping disable process." -Color Yellow, Red
                    break topLoop
                }
            }
        }
    }

    Write-Color -Text "[i] ", "Disabled ", $CountDisable, " service accounts" -Color Yellow, Green, Green, Green
    return $ReportDisabled
}
