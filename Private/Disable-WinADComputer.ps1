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
        if ($Success -and $Computer.Enabled -eq $true) {
            $DN = Get-ADComputerCurrentDistinguishedName -Computer $Computer
            Write-Color -Text "[i] Disabling computer ", $Computer.SamAccountName, ' DN: ', $DN, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
            try {
                Add-Member -InputObject $Computer -MemberType NoteProperty -Name 'ActionAttempted' -Value $true -Force
                Disable-ADAccount -Identity $DN -Server $Server -WhatIf:$WhatIfDisable -ErrorAction Stop
                Add-Member -InputObject $Computer -MemberType NoteProperty -Name 'DisableActionResult' -Value $(if ($WhatIfDisable) { 'WhatIf' } else { 'True' }) -Force
                Write-Color -Text "[+] Disabling computer ", $DN, " (WhatIf: $WhatIfDisable) successful." -Color Yellow, Green, Yellow
                if (-not $DontWriteToEventLog) {
                    Write-EVXEvent -ID 10 -LogName 'Application' -EntryType Information -Category 1000 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) successful." -AdditionalFields @('Disable', $Computer.SamAccountName, $DN, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable) -WarningAction SilentlyContinue -WarningVariable warnings
                }
                foreach ($W in $Warnings) {
                    Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                }
                $Success = $true
            } catch {
                Add-Member -InputObject $Computer -MemberType NoteProperty -Name 'DisableActionResult' -Value 'False' -Force
                $Computer.ActionComment = $_.Exception.Message
                $Success = $false
                Write-Color -Text "[-] Disabling computer ", $DN, " (WhatIf: $WhatIfDisable) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                if (-not $DontWriteToEventLog) {
                    Write-EVXEvent -ID 10 -LogName 'Application' -EntryType Error -Category 1001 -Source 'CleanupComputers' -Message "Disabling computer $($Computer.SamAccountName) failed. Error: $($_.Exception.Message)" -AdditionalFields @('Disable', $Computer.SamAccountName, $DN, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfDisable, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                }
                foreach ($W in $Warnings) {
                    Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                }
            }
        } else {
            Add-Member -InputObject $Computer -MemberType NoteProperty -Name 'DisableActionResult' -Value 'AlreadySatisfied' -Force
            Write-Color -Text "[i] Computer ", $Computer.SamAccountName, " is already disabled." -Color Yellow, Green, Yellow
        }
    }
    $Success
}
