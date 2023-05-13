function Request-ADComputersDelete {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [System.Collections.IDictionary] $Report,
        [switch] $ReportOnly,
        [switch] $WhatIfDelete,
        [int] $DeleteLimit,
        [System.Collections.IDictionary] $ProcessedComputers,
        [DateTime] $Today
    )

    $CountDeleteLimit = 0
    # :top means name of the loop, so we can break it
    :topLoop foreach ($Domain in $Report.Keys) {
        foreach ($Computer in $Report["$Domain"]['Computers']) {
            $Server = $Report["$Domain"]['Server']
            if ($Computer.Action -ne 'Delete') {
                continue
            }
            if ($ReportOnly) {
                $Computer
            } else {
                Write-Color -Text "[i] Deleting computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                try {
                    $Success = $true
                    Remove-ADObject -Identity $Computer.DistinguishedName -Recursive -WhatIf:$WhatIfDelete -Server $Server -ErrorAction Stop -Confirm:$false
                    Write-Color -Text "[+] Deleting computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDelete.IsPresent)) successful." -Color Yellow, Green, Yellow
                    Write-Event -ID 12 -LogName 'Application' -EntryType Warning -Category 1000 -Source 'CleanupComputers' -Message "Deleting computer $($Computer.SamAccountName) successful." -AdditionalFields @('Delete', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDelete) -WarningAction SilentlyContinue -WarningVariable warnings
                    foreach ($W in $Warnings) {
                        Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                    }

                } catch {
                    $Success = $false
                    Write-Color -Text "[-] Deleting computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfDelete.IsPresent)) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                    Write-Event -ID 12 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Deleting computer $($Computer.SamAccountName) failed." -AdditionalFields @('Delete', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDelete, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
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
                # lets remove computer from $ProcessedComputers
                $ComputerOnTheList = -join ($Computer.SamAccountName, "@", $Domain)
                $ProcessedComputers.Remove("$ComputerOnTheList")

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