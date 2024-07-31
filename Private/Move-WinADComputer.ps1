function Move-WinADComputer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool] $Success,
        [bool] $DisableAndMove,
        [System.Collections.IDictionary] $OrganizationalUnit,
        [PSCustomObject] $Computer,
        [switch] $WhatIfDisable,
        [switch] $DontWriteToEventLog,
        [string] $Server
    )
    if ($Success -and $DisableAndMove) {
        # we only move if we successfully disabled the computer
        if ($OrganizationalUnit[$Domain]) {
            if ($Computer.OrganizationalUnit -eq $OrganizationalUnit[$Domain]) {
                Write-Color -Text "[i] Computer ", $Computer.DistinguishedName, " is already in the correct OU." -Color Yellow, Green, Yellow
            } else {
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
    $Success
}