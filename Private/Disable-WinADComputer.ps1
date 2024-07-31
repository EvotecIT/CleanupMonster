function Disable-WinADComputer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool] $Success,
        [switch] $WhatIfDisable,
        [switch] $DontWriteToEventLog,
        [PSCustomObject] $Computer,
        [string] $Server
    )
    if ($Success) {
        if ($Computer.Enabled -eq $true) {
            Write-Color -Text "[i] Disabling computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
            try {
                if ($Computer.DistinguishedNameAfterMove) {
                    $DN = $Computer.DistinguishedNameAfterMove
                } else {
                    $DN = $Computer.DistinguishedName
                }

                Disable-ADAccount -Identity $DN -Server $Server -WhatIf:$WhatIfDisable -ErrorAction Stop
                Write-Color -Text "[+] Disabling computer ", $DN, " (WhatIf: $WhatIfDisable) successful." -Color Yellow, Green, Yellow
                if (-not $DontWriteToEventLog) {
                    Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 1000 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) successful." -AdditionalFields @('Disable', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable) -WarningAction SilentlyContinue -WarningVariable warnings
                }
                foreach ($W in $Warnings) {
                    Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                }
                $Success = $true
            } catch {
                $Computer.ActionComment = $_.Exception.Message
                $Success = $false
                Write-Color -Text "[-] Disabling computer ", $DN, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                if (-not $DontWriteToEventLog) {
                    Write-Event -ID 10 -LogName 'Application' -EntryType Error -Category 1001 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) failed. Error: $($_.Exception.Message)" -AdditionalFields @('Disable', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                }
                foreach ($W in $Warnings) {
                    Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                }
            }
        } else {
            Write-Color -Text "[i] Computer ", $Computer.SamAccountName, " is already disabled." -Color Yellow, Green, Yellow
        }
    }
    $Success
}