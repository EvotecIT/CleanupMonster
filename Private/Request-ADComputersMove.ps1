function Request-ADComputersMove {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [nullable[bool]] $Delete,
        [System.Collections.IDictionary] $Report,
        [switch] $ReportOnly,
        [switch] $WhatIfMove,
        [int] $MoveLimit,
        [System.Collections.IDictionary] $ProcessedComputers,
        [DateTime] $Today,
        [Object] $TargetOrganizationalUnit,
        [switch] $DontWriteToEventLog,
        [switch] $DoNotAddToPendingList
    )

    if ($TargetOrganizationalUnit -is [System.Collections.IDictionary]) {
        $OrganizationalUnit = $TargetOrganizationalUnit
    } elseif ($TargetOrganizationalUnit -is [string]) {
        $DomainCN = ConvertFrom-DistinguishedName -DistinguishedName $TargetOrganizationalUnit -ToDomainCN
        $OrganizationalUnit = [ordered] @{
            $DomainCN = $TargetOrganizationalUnit
        }
    } else {
        Write-Color -Text "[-] TargetOrganizationalUnit is not a string or hashtable. Skipping moving to proper OU." -Color Yellow, Red
        return
    }
    $CountMoveLimit = 0
    # :top means name of the loop, so we can break it
    :topLoop foreach ($Domain in $Report.Keys) {
        foreach ($Computer in $Report["$Domain"]['Computers']) {
            $Server = $Report["$Domain"]['Server']
            if ($Computer.Action -ne 'Move') {
                continue
            }
            if ($ReportOnly) {
                $Computer
            } else {
                if ($OrganizationalUnit[$Domain]) {
                    # we check if the computer is already in the correct OU
                    if ($Computer.OrganizationalUnit -eq $OrganizationalUnit[$Domain]) {
                        # this shouldn't really happen as we should have filtered it out earlier
                    } else {
                        Write-Color -Text "[i] Moving computer ", $Computer.SamAccountName, ' DN: ', $Computer.DistinguishedName, ' Enabled: ', $Computer.Enabled, ' Operating System: ', $Computer.OperatingSystem, ' LastLogon: ', $Computer.LastLogonDate, " / " , $Computer.LastLogonDays , ' days, PasswordLastSet: ', $Computer.PasswordLastSet, " / ", $Computer.PasswordLastChangedDays, " days" -Color Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green
                        try {
                            $MovedObject = Move-ADObject -Identity $Computer.DistinguishedName -WhatIf:$WhatIfMove -Server $Server -ErrorAction Stop -Confirm:$false -TargetPath $OrganizationalUnit[$Domain] -PassThru
                            $Computer.DistinguishedNameAfterMove = $MovedObject.DistinguishedName
                            Write-Color -Text "[+] Moving computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfMove.IsPresent)) successful." -Color Yellow, Green, Yellow
                            if (-not $DontWriteToEventLog) {
                                Write-Event -ID 11 -LogName 'Application' -EntryType Warning -Category 1000 -Source 'CleanupComputers' -Message "Moving computer $($Computer.SamAccountName) successful." -AdditionalFields @('Move', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfMove) -WarningAction SilentlyContinue -WarningVariable warnings
                            }
                            foreach ($W in $Warnings) {
                                Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                            }
                            if (-not $Delete) {
                                # lets remove computer from $ProcessedComputers
                                # we only remove it if Delete is not part of the removal process and move is the last step
                                if (-not $DoNotAddToPendingList) {
                                    $ComputerOnTheList = -join ($Computer.SamAccountName, "@", $Domain)
                                    $ProcessedComputers.Remove("$ComputerOnTheList")
                                }
                            }
                            $Success = $true
                        } catch {
                            $Success = $false
                            Write-Color -Text "[-] Moving computer ", $Computer.DistinguishedName, " (WhatIf: $($WhatIfMove.IsPresent)) failed. Error: $($_.Exception.Message)" -Color Yellow, Red, Yellow
                            if (-not $DontWriteToEventLog) {
                                Write-Event -ID 11 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Moving computer $($Computer.SamAccountName) failed." -AdditionalFields @('Move', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfMove, $($_.Exception.Message)) -WarningAction SilentlyContinue -WarningVariable warnings
                            }
                            foreach ($W in $Warnings) {
                                Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                            }
                            $Computer.ActionComment = $_.Exception.Message
                        }
                        $Computer.ActionDate = $Today
                        if ($WhatIfMove.IsPresent) {
                            $Computer.ActionStatus = 'WhatIf'
                        } else {
                            $Computer.ActionStatus = $Success
                        }
                        # return computer to $ReportMoved so we can see summary just in case
                        $Computer
                        $CountMoveLimit++
                        if ($MoveLimit) {
                            if ($MoveLimit -eq $CountMoveLimit) {
                                break topLoop # this breaks top loop
                            }
                        }
                    }
                } else {
                    Write-Color -Text "[-] Moving computer ", $Computer.SamAccountName, " failed. TargetOrganizationalUnit for domain $Domain not found." -Color Yellow, Red, Yellow
                    if (-not $DontWriteToEventLog) {
                        Write-Event -ID 11 -LogName 'Application' -EntryType Error -Category 1000 -Source 'CleanupComputers' -Message "Moving computer $($Computer.SamAccountName) failed." -AdditionalFields @('Move', $Computer.SamAccountName, $Computer.DistinguishedName, $Computer.Enabled, $Computer.OperatingSystem, $Computer.LastLogonDate, $Computer.PasswordLastSet, $WhatIfMove, "TargetOrganizationalUnit for domain $Domain not found.") -WarningAction SilentlyContinue -WarningVariable warnings
                    }
                    foreach ($W in $Warnings) {
                        Write-Color -Text "[-] ", "Warning: ", $W -Color Yellow, Cyan, Red
                    }
                    $Computer.ActionComment = "TargetOrganizationalUnit for domain $Domain not found."
                    $Computer.ActionDate = $Today
                    $Computer.ActionStatus = $false
                    # return computer to $ReportMoved so we can see summary just in case
                    $Computer
                    $CountMoveLimit++
                    if ($MoveLimit) {
                        if ($MoveLimit -eq $CountMoveLimit) {
                            break topLoop # this breaks top loop
                        }
                    }
                }
            }
        }
    }
}