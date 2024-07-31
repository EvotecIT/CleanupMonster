function Request-ADComputersDisable {
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [nullable[bool]] $Delete,
        [nullable[bool]] $Move,
        [nullable[bool]] $DisableAndMove,
        [System.Collections.IDictionary] $Report,
        [switch] $WhatIfDisable,
        [switch] $DisableModifyDescription,
        [switch] $DisableModifyAdminDescription,
        [int] $DisableLimit,
        [switch] $ReportOnly,
        [DateTime] $Today,
        [switch] $DontWriteToEventLog,
        [Object] $DisableMoveTargetOrganizationalUnit,
        [switch] $DoNotAddToPendingList,
        [ValidateSet(
            'DisableAndMove',
            'MoveAndDisable'
        )][string] $DisableAndMoveOrder = 'DisableAndMove'
    )

    if ($DisableAndMove -and $DisableMoveTargetOrganizationalUnit) {
        if ($DisableMoveTargetOrganizationalUnit -is [System.Collections.IDictionary]) {
            $OrganizationalUnit = $DisableMoveTargetOrganizationalUnit
        } elseif ($TargetOrganizationalUnit -is [string]) {
            $DomainCN = ConvertFrom-DistinguishedName -DistinguishedName $TargetOrganizationalUnit -ToDomainCN
            $OrganizationalUnit = [ordered] @{
                $DomainCN = $DisableMoveTargetOrganizationalUnit
            }
        } else {
            Write-Color -Text "[-] DisableMoveTargetOrganizationalUnit is not a string or hashtable. Skipping moving to proper OU." -Color Yellow, Red
            return
        }
    }

    $CountDisable = 0
    # :top means name of the loop, so we can break it
    :topLoop foreach ($Domain in $Report.Keys) {
        Write-Color "[i] ", "Starting process of disabling computers for domain $Domain" -Color Yellow, Green
        foreach ($Computer in $Report["$Domain"]['Computers']) {
            $Server = $Report["$Domain"]['Server']
            if ($Computer.Action -ne 'Disable') {
                continue
            }
            if ($ReportOnly) {
                $Computer
            } else {
                $Success = $true
                if ($DisableAndMoveOrder -eq 'DisableAndMove') {
                    $Success = Disable-WinADComputer -Success $Success -WhatIfDisable:$WhatIfDisable -DontWriteToEventLog:$DontWriteToEventLog -Computer $Computer -Server $Server
                    $Success = Move-WinADComputer -Success $Success -DisableAndMove $DisableAndMove -OrganizationalUnit $OrganizationalUnit -Computer $Computer -WhatIfDisable:$WhatIfDisable -DontWriteToEventLog:$DontWriteToEventLog -Server $Server
                } else {
                    $Success = Move-WinADComputer -Success $Success -DisableAndMove $DisableAndMove -OrganizationalUnit $OrganizationalUnit -Computer $Computer -WhatIfDisable:$WhatIfDisable -DontWriteToEventLog:$DontWriteToEventLog -Server $Server
                    $Success = Disable-WinADComputer -Success $Success -WhatIfDisable:$WhatIfDisable -DontWriteToEventLog:$DontWriteToEventLog -Computer $Computer -Server $Server
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

                # We add computer to pending list in all cases because otherwise we would be going in circles
                # if move or delete were not enabled
                # please use -DoNotAddToPendingList if you don't want to add computer to pending list
                if (-not $DoNotAddToPendingList) {
                    $FullComputerName = -join ($Computer.SamAccountName, '@', $Domain)
                    $ProcessedComputers[$FullComputerName] = $Computer
                }

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