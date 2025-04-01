function Move-WinADComputer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool] $Success,
        [bool] $DisableAndMove,
        [System.Collections.IDictionary] $OrganizationalUnit,
        [PSCustomObject] $Computer,
        [switch] $WhatIfDisable,
        [switch] $DontWriteToEventLog,
        [string] $Server,
        [switch] $RemoveProtectedFromAccidentalDeletionFlag
    )
    if ($Success -and $DisableAndMove) {
        # we only move if we successfully disabled the computer
        if ($OrganizationalUnit[$Domain]) {
            if ($Computer.OrganizationalUnit -eq $OrganizationalUnit[$Domain]) {
                Write-Color -Text "[i] Computer ", $Computer.DistinguishedName, " is already in the correct OU." -Color Yellow, Green, Yellow
            } else {
                if ($Computer.ProtectedFromAccidentalDeletion) {
                    if ($RemoveProtectedFromAccidentalDeletionFlag) {
                        try {
                            Write-Color -Text "[i] Removing protected from accidental move flag for computer ", $Computer.DistinguishedName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                            Set-ADObject -ProtectedFromAccidentalDeletion $false -Identity $Computer.DistinguishedName -Server $Server -ErrorAction Stop -Confirm:$false -WhatIf:$WhatIfDisable
                            if (-not $DontWriteToEventLog) {
                                Write-Event -ID 15 -LogName 'Application' -EntryType Warning -Category 1000 -Source 'CleanupComputers' -Message "Removing protected from accidental move flag for computer $($Computer.SamAccountName) successful." -AdditionalFields @('RemoveProtection', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable) -WarningAction SilentlyContinue -WarningVariable warnings
                            }
                            $Success = $true
                        } catch {
                            $Success = $false
                            Write-Color -Text "[-] Removing protected from accidental move flag for computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDisable.IsPresent)) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                            if (-not $DontWriteToEventLog) {
                                Write-Event -ID 15 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Removing protected from accidental move flag for computer $($Computer.SamAccountName) failed." -AdditionalFields @('RemoveProtection', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                            }
                            foreach ($W in $Warnings) {
                                Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                            }
                        }
                    } else {
                        Write-Color -Text "[i] Computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' is protected from accidental move. Move skipped.' -Color Yellow, Green, Yellow
                        if (-not $DontWriteToEventLog) {
                            Write-Event -ID 15 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Computer $($Computer.SamAccountName) is protected from accidental move. Move skipped." -AdditionalFields @('RemoveProtection', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable) -WarningAction SilentlyContinue -WarningVariable warnings
                        }
                        $Success = $false
                    }
                } else {
                    $Success = $true
                }
                if ($Success) {
                    $Success = $false
                    try {
                        $MovedObject = Move-ADObject -Identity $Computer.DistinguishedName -WhatIf:$WhatIfDisable -Server $Server -ErrorAction Stop -Confirm:$false -TargetPath $OrganizationalUnit[$Domain] -PassThru
                        Write-Color -Text "[+] Moving computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDisable.IsPresent)) successful." -Color Yellow, Green, Yellow
                        if (-not $DontWriteToEventLog) {
                            Write-Event -ID 11 -LogName 'Application' -EntryType Warning -Category 1000 -Source 'CleanupComputers' -Message "Moving computer $($Computer.SamAccountName) successful." -AdditionalFields @('Move', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable) -WarningAction SilentlyContinue -WarningVariable warnings
                        }
                        foreach ($W in $Warnings) {
                            Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                        }
                        $Computer.DistinguishedNameAfterMove = $MovedObject.DistinguishedName
                        $Success = $true
                    } catch {
                        $Success = $false
                        Write-Color -Text "[-] Moving computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDisable.IsPresent)) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                        if (-not $DontWriteToEventLog) {
                            Write-Event -ID 11 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Moving computer $($Computer.SamAccountName) failed." -AdditionalFields @('Move', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                        }
                        foreach ($W in $Warnings) {
                            Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                        }
                        $Computer.ActionComment = $Computer.ActionComment + [System.Environment]::NewLine + $_.Exception.Message
                    }
                }
            }
        }
    }
    $Success
}