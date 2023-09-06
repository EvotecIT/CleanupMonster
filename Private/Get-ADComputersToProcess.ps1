function Get-ADComputersToProcess {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)][ValidateSet('Disable', 'Move', 'Delete')][string] $Type,
        [Array] $Computers,
        [alias('DeleteOnlyIf', 'DisableOnlyIf', 'MoveOnlyIf')][System.Collections.IDictionary] $ActionIf,
        [Array] $Exclusions,
        [System.Collections.IDictionary] $DomainInformation,
        [System.Collections.IDictionary] $ProcessedComputers,
        [System.Collections.IDictionary] $AzureInformationCache,
        [System.Collections.IDictionary] $JamfInformationCache,
        [switch] $IncludeAzureAD,
        [switch] $IncludeIntune,
        [switch] $IncludeJamf
    )
    Write-Color -Text "[i] ", "Applying following rules to $Type action: " -Color Yellow, Cyan, Green
    foreach ($Key in $ActionIf.Keys) {
        if ($null -eq $ActionIf[$Key] -or $ActionIf[$Key].Count -eq 0) {
            Write-Color -Text "   [>] ", $($Key), " is ", 'Not Set' -Color Yellow, Cyan, Yellow
        } else {
            if ($Key -in 'LastLogonDateMoreThan', 'LastLogonDateOlderThan') {
                Write-Color -Text "   [>] ", $($Key), " is ", $($ActionIf[$Key]), " or ", "Never logged on" -Color Yellow, Cyan, Green
            } elseif ($Key -in 'PasswordLastSetMoreThan', 'PasswordLastSetOlderThan') {
                Write-Color -Text "   [>] ", $($Key), " is ", $($ActionIf[$Key]), " or ", "Never changed" -Color Yellow, Cyan, Green
            } elseif ($Key -in 'LastSeenAzureMoreThan', 'LastSeenIntuneMoreThan', 'LastSyncAzureMoreThan', 'LastContactJamfMoreThan') {
                Write-Color -Text "   [>] ", $($Key), " is ", $($ActionIf[$Key]), " or ", "Never synced/seen" -Color Yellow, Cyan, Green
            } else {
                Write-Color -Text "   [>] ", $($Key), " is ", $($ActionIf[$Key]) -Color Yellow, Cyan, Green
            }
        }
    }
    $Count = 0
    $Today = Get-Date

    Write-Color -Text "[i] ", "Looking for computers to $Type" -Color Yellow, Cyan, Green
    :SkipComputer foreach ($Computer in $Computers) {
        if ($Type -eq 'Delete') {
            # actions to happen only if we are deleting computers
            if ($null -ne $ActionIf.ListProcessedMoreThan) {
                # if more then 0 this means computer has to be on list of disabled computers for that number of days.
                if ($ProcessedComputers.Count -gt 0) {
                    $FullComputerName = "$($Computer.SamAccountName)@$($Computer.DomainName)"
                    $FoundComputer = $ProcessedComputers[$FullComputerName]
                    if ($FoundComputer) {
                        if ($FoundComputer.ActionDate -is [DateTime]) {
                            $TimeSpan = New-TimeSpan -Start $FoundComputer.ActionDate -End $Today
                            if ($TimeSpan.Days -gt $ActionIf.ListProcessedMoreThan) {

                            } else {
                                continue SkipComputer
                            }
                        } else {
                            continue SkipComputer
                        }
                    } else {
                        continue SkipComputer
                    }
                } else {
                    # ListProcessed doesn't have members, and it's part of requirement
                    break
                }
            }
        }
        if ($Type -eq 'Disable') {
            # actions to happen only if we are disabling computers
            if ($ProcessedComputers.Count -gt 0) {
                $FullComputerName = "$($Computer.SamAccountName)@$($Computer.DomainName)"
                $FoundComputer = $ProcessedComputers[$FullComputerName]
                if ($FoundComputer) {
                    if ($Computer.Enabled -eq $true) {
                        # We checked and it seems the computer has been enabled since it was added to list, we remove it from the list and reprocess
                        Write-Color -Text "[*] Removing computer from pending list (computer is enabled) ", $FoundComputer.SamAccountName, " ($($FoundComputer.DistinguishedName))" -Color DarkYellow, Green, DarkYellow
                        $ProcessedComputers.Remove($FullComputerName)
                    } else {
                        # we skip adding to disabled because it's already on the list for removing
                        continue SkipComputer
                    }
                }
            }
        }
        # rest of actions are same for all types
        foreach ($PartialExclusion in $Exclusions) {
            if ($Computer.DistinguishedName -like "$PartialExclusion") {
                continue SkipComputer
            }
            if ($Computer.SamAccountName -like "$PartialExclusion") {
                continue SkipComputer
            }
            if ($Computer.DNSHostName -like "$PartialExclusion") {
                continue SkipComputer
            }
        }
        if ($ActionIf.ExcludeServicePrincipalName.Count -gt 0) {
            foreach ($ExcludeSPN in $ActionIf.ExcludeServicePrincipalName) {
                if ($Computer.servicePrincipalName -like "$ExcludeSPN") {
                    continue SkipComputer
                }
            }
        }
        if ($ActionIf.IncludeServicePrincipalName.Count -gt 0) {
            $FoundInclude = $false
            foreach ($IncludeSPN in $ActionIf.IncludeServicePrincipalName) {
                if ($Computer.servicePrincipalName -like "$IncludeSPN") {
                    $FoundInclude = $true
                    break
                }
            }
            # If not found in includes we need to skip the computer
            if (-not $FoundInclude) {
                continue SkipComputer
            }
        }
        if ($ActionIf.ExcludeSystems.Count -gt 0) {
            foreach ($Exclude in $ActionIf.ExcludeSystems) {
                if ($Computer.OperatingSystem -like $Exclude) {
                    continue SkipComputer
                }
            }
        }
        if ($ActionIf.IncludeSystems.Count -gt 0) {
            $FoundInclude = $false
            foreach ($Include in $ActionIf.IncludeSystems) {
                if ($Computer.OperatingSystem -like $Include) {
                    $FoundInclude = $true
                    break
                }
            }
            # If not found in includes we need to skip the computer
            if (-not $FoundInclude) {
                continue SkipComputer
            }
        }
        if ($ActionIf.IsEnabled -eq $true) {
            # action computer only if it's Enabled
            if ($Computer.Enabled -eq $false) {
                continue SkipComputer
            }
        } elseif ($ActionIf.IsEnabled -eq $false) {
            # action computer only if it's Disabled
            if ($Computer.Enabled -eq $true) {
                continue SkipComputer
            }
        }

        if ($ActionIf.NoServicePrincipalName -eq $true) {
            # action computer only if it has no service principal names defined
            if ($Computer.servicePrincipalName.Count -gt 0) {
                continue SkipComputer
            }
        } elseif ($ActionIf.NoServicePrincipalName -eq $false) {
            # action computer only if it has service principal names defined
            if ($Computer.servicePrincipalName.Count -eq 0) {
                continue SkipComputer
            }
        }

        if ($ActionIf.LastLogonDateMoreThan) {
            # This runs only if more than 0
            if ($Computer.LastLogonDate) {
                # We ignore empty

                $TimeToCompare = ($Computer.LastLogonDate).AddDays($ActionIf.LastLogonDateMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipComputer
                }
            }
        }
        if ($ActionIf.PasswordLastSetMoreThan) {
            # This runs only if more than 0
            if ($Computer.PasswordLastSet) {
                # We ignore empty

                $TimeToCompare = ($Computer.PasswordLastSet).AddDays($ActionIf.PasswordLastSetMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipComputer
                }
            }
        }

        if ($ActionIf.PasswordLastSetOlderThan) {
            # This runs only if not null
            if ($Computer.PasswordLastSet) {
                # We ignore empty

                if ($ActionIf.PasswordLastSetOlderThan -le $Computer.PasswordLastSet) {
                    continue SkipComputer
                }
            }
        }
        if ($ActionIf.LastLogonDateOlderThan) {
            # This runs only if not null
            if ($Computer.LastLogonDate) {
                # We ignore empty

                if ($ActionIf.LastLogonDateOlderThan -le $Computer.LastLogonDate) {
                    continue SkipComputer
                }
            }
        }

        if ($IncludeAzureAD) {
            if ($null -ne $ActionIf.LastSeenAzureMoreThan -and $null -ne $Computer.AzureLastSeenDays) {
                if ($Computer.AzureLastSeenDays -le $ActionIf.LastSeenAzureMoreThan) {
                    continue SkipComputer
                }

            }
            if ($null -ne $ActionIf.LastSyncAzureMoreThan -and $null -ne $Computer.AzureLastSyncDays) {
                if ($Computer.AzureLastSyncDays -le $ActionIf.LastSyncAzureMoreThan) {
                    continue SkipComputer
                }
            }
        }
        if ($IncludeIntune) {
            if ($null -ne $ActionIf.LastSeenIntuneMoreThan -and $null -ne $Computer.IntuneLastSeenDays) {
                if ($Computer.IntuneLastSeenDays -le $ActionIf.LastSeenIntuneMoreThan) {
                    continue SkipComputer
                }
            }
        }
        if ($IncludeJamf) {
            if ($null -ne $ActionIf.LastContactJamfMoreThan -and $null -ne $Computer.JamfLastContactTimeDays) {
                if ($Computer.JamfLastContactTimeDays -le $ActionIf.LastContactJamfMoreThan) {
                    continue SkipComputer
                }
            }
        }
        $Computer.'Action' = $Type
        $Count++
    }
    $Count
}