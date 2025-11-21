function Request-ADServiceAccountsDelete {
    <#
    .SYNOPSIS
    Processes service accounts for deletion.

    .DESCRIPTION
    This function processes service accounts that meet the criteria for deletion.
    It handles the actual deletion operation with appropriate safety checks.
    #>
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [System.Collections.IDictionary] $Report,
        [switch] $WhatIfDelete,
        [int] $DeleteLimit,
        [switch] $ReportOnly,
        [DateTime] $Today,
        [System.Collections.IDictionary] $ProcessedServiceAccounts,
        [switch] $DontWriteToEventLog,
        [switch] $RemoveProtectedFromAccidentalDeletionFlag
    )

    $CountDelete = 0
    $ReportDeleted = @()

    # Process each domain
    :topLoop foreach ($Domain in $Report.Keys) {
        Write-Color "[i] ", "Starting process of deleting service accounts for domain $Domain" -Color Yellow, Green
        foreach ($ServiceAccount in $Report["$Domain"]['ServiceAccounts']) {
            $Server = $Report["$Domain"]['Server']
            if ($ServiceAccount.Action -ne 'Delete') {
                continue
            }
            if ($ReportOnly) {
                $ReportDeleted += $ServiceAccount
            } else {
                $Success = $true

                # Remove protection from accidental deletion if requested
                if ($RemoveProtectedFromAccidentalDeletionFlag) {
                    try {
                        Set-ADObject -Identity $ServiceAccount.DistinguishedName -ProtectedFromAccidentalDeletion $false -WhatIf:$WhatIfDelete -ErrorAction Stop -Server $Server
                        Write-Color -Text "[+] ", "Removing ProtectedFromAccidentalDeletion flag from service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDelete) successful" -Color Yellow, Green, Yellow, Green
                    } catch {
                        $ServiceAccount.ActionComment = $ServiceAccount.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                        Write-Color -Text "[-] ", "Removing ProtectedFromAccidentalDeletion flag from service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDelete) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        $Success = $false
                    }
                }

                # Perform the actual delete operation
                if ($Success -and $PSCmdlet.ShouldProcess($ServiceAccount.DistinguishedName, "Delete Service Account")) {
                    try {
                        Remove-ADServiceAccount -Identity $ServiceAccount.DistinguishedName -WhatIf:$WhatIfDelete -ErrorAction Stop -Server $Server -Confirm:$false
                        Write-Color -Text "[+] ", "Deleting service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDelete) successful" -Color Yellow, Green, Yellow, Green

                        if (-not $DontWriteToEventLog -and -not $WhatIfDelete) {
                            Write-WinEvent -LogName 'Application' -Source 'CleanupMonster' -EntryType Information -EventId 101 -Message "Service account $($ServiceAccount.SamAccountName) has been deleted by CleanupMonster."
                        }
                    } catch {
                        $ServiceAccount.ActionComment = $ServiceAccount.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                        Write-Color -Text "[-] ", "Deleting service account ", $ServiceAccount.DistinguishedName, " (WhatIf: $WhatIfDelete) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        $Success = $false
                    }
                }

                # Set action metadata
                $ServiceAccount.ActionDate = $Today
                if ($WhatIfDelete.IsPresent) {
                    $ServiceAccount.ActionStatus = 'WhatIf'
                } else {
                    $ServiceAccount.ActionStatus = $Success
                }

                # Remove from pending list if successfully deleted
                if ($Success -and -not $WhatIfDelete) {
                    $DomainName = ConvertFrom-DistinguishedName -DistinguishedName $ServiceAccount.DistinguishedName -ToDomainCN
                    $FullServiceAccountName = -join ($ServiceAccount.SamAccountName, '@', $DomainName)
                    if ($ProcessedServiceAccounts.ContainsKey($FullServiceAccountName)) {
                        $ProcessedServiceAccounts.Remove($FullServiceAccountName)
                        Write-Color -Text "[*] ", "Removing service account from pending list: ", $ServiceAccount.SamAccountName -Color Yellow, Green, Yellow
                    }
                }

                $ReportDeleted += $ServiceAccount
                $CountDelete++

                # Check delete limit
                if ($DeleteLimit -gt 0 -and $CountDelete -ge $DeleteLimit) {
                    Write-Color -Text "[i] ", "Delete limit reached ($DeleteLimit). Stopping delete process." -Color Yellow, Red
                    break topLoop
                }
            }
        }
    }

    Write-Color -Text "[i] ", "Deleted ", $CountDelete, " service accounts" -Color Yellow, Green, Green, Green
    return $ReportDeleted
}
