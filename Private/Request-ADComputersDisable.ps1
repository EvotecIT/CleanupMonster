function Request-ADComputersDisable {
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [System.Collections.IDictionary] $Report,
        [switch] $WhatIfDisable,
        [switch] $DisableModifyDescription,
        [switch] $DisableModifyAdminDescription,
        [int] $DisableLimit,
        [switch] $ReportOnly,
        [DateTime] $Today
    )
    $CountDisable = 0
    # :top means name of the loop, so we can break it
    :topLoop foreach ($Domain in $Report.Keys) {
        Write-Color "[i] ", "Starting process of disabling computers for domain $Domain" -Color Yellow, Green
        foreach ($Computer in $Report["$Domain"]['ComputersToBeDisabled']) {
            $Server = $Report["$Domain"]['Server']
            if ($Computer.Action -ne 'Disable') {
                continue
            }
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