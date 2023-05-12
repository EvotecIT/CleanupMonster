function Get-ADComputersToDisable {
    [cmdletBinding()]
    param(
        [Array] $Computers,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [Array] $Exclusions = @('OU=Domain Controllers'),
        [string] $Filter = '*',
        [System.Collections.IDictionary] $DomainInformation,
        [System.Collections.IDictionary] $ProcessedComputers,
        [System.Collections.IDictionary] $AzureInformationCache,
        [System.Collections.IDictionary] $JamfInformationCache,
        [switch] $IncludeAzureAD,
        [switch] $IncludeIntune,
        [switch] $IncludeJamf
    )
    $Count = 0
    $Today = Get-Date
    :SkipComputer foreach ($Computer in $Computers) {
        if ($ProcessedComputers.Count -gt 0) {
            $FoundComputer = $ProcessedComputers["$($Computer.DistinguishedName)"]
            if ($FoundComputer) {
                if ($Computer.Enabled -eq $true) {
                    # We checked and it seems the computer has been enabled since it was added to list, we remove it from the list and reprocess
                    Write-Color -Text "[*] Removing computer from pending list (computer is enabled) ", $FoundComputer.SamAccountName, " ($($FoundComputer.DistinguishedName))" -Color DarkMagenta, Green, DarkMagenta
                    $ProcessedComputers.Remove("$($Computer.DistinguishedName)")
                } else {
                    # we skip adding to disabled because it's already on the list for removing
                    continue SkipComputer
                }
            }
        }
        if ($DisableOnlyIf.IsEnabled -eq $true) {
            # Disable computer only if it's Enabled
            if ($Computer.Enabled -eq $false) {
                continue SkipComputer
            }
        } elseif ($DisableOnlyIf.IsEnabled -eq $false) {
            # Disable computer only if it's Disabled
            # a bit useless as it's already disable right...
            # so we skip computer both times as it's  already done
            if ($Computer.Enabled -eq $true) {
                continue SkipComputer
            } else {
                continue SkipComputer
            }
        } else {
            # If null it should ignore condition
        }

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
        if ($DisableOnlyIf.ExcludeSystems.Count -gt 0) {
            foreach ($Exclude in $DisableOnlyIf.ExcludeSystems) {
                if ($Computer.OperatingSystem -like $Exclude) {
                    continue SkipComputer
                }
            }
        }
        if ($DisableOnlyIf.IncludeSystems.Count -gt 0) {
            $FoundInclude = $false
            foreach ($Include in $DisableOnlyIf.IncludeSystems) {
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
        if ($DisableOnlyIf.NoServicePrincipalName -eq $true) {
            # Disable computer only if it has no service principal names defined
            if ($Computer.servicePrincipalName.Count -gt 0) {
                continue SkipComputer
            }
        } elseif ($DisableOnlyIf.NoServicePrincipalName -eq $false) {
            # Disable computer only if it has service principal names defined
            if ($Computer.servicePrincipalName.Count -eq 0) {
                continue SkipComputer
            }
        } else {
            # If null it should ignore confition
        }

        if ($DisableOnlyIf.LastLogonDateMoreThan) {
            # This runs only if more than 0
            if ($Computer.LastLogonDate) {
                # We ignore empty

                $TimeToCompare = ($Computer.LastLogonDate).AddDays($DisableOnlyIf.LastLogonDateMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipComputer
                }
            }
        }
        if ($DisableOnlyIf.PasswordLastSetMoreThan) {
            # This runs only if more than 0
            if ($Computer.PasswordLastSet) {
                # We ignore empty

                $TimeToCompare = ($Computer.PasswordLastSet).AddDays($DisableOnlyIf.PasswordLastSetMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipComputer
                }
            }
        }

        if ($DisableOnlyIf.PasswordLastSetOlderThan) {
            # This runs only if not null
            if ($Computer.PasswordLastSet) {
                # We ignore empty

                if ($DisableOnlyIf.PasswordLastSetOlderThan -le $Computer.PasswordLastSet) {
                    continue SkipComputer
                }
            }
        }
        if ($DisableOnlyIf.LastLogonDateOlderThan) {
            # This runs only if not null
            if ($Computer.LastLogonDate) {
                # We ignore empty

                if ($DisableOnlyIf.LastLogonDateOlderThan -le $Computer.LastLogonDate) {
                    continue SkipComputer
                }
            }
        }
        if ($IncludeAzureAD) {
            if ($null -ne $DisableOnlyIf.LastSeenAzureMoreThan -and $null -ne $Computer.AzureLastSeenDays) {
                if ($DisableOnlyIf.LastSeenAzureMoreThan -le $Computer.AzureLastSeenDays) {
                    continue SkipComputer
                }
            }
            if ($null -ne $DisableOnlyIf.LastSyncAzureMoreThan -and $null -ne $Computer.AzureLastSyncDays) {
                if ($DisableOnlyIf.LastSyncAzureMoreThan -le $Computer.AzureLastSyncDays) {
                    continue SkipComputer
                }
            }
        }
        if ($IncludeIntune) {
            if ($null -ne $DisableOnlyIf.LastSeenIntuneMoreThan -and $null -ne $Computer.IntuneLastSeenDays) {
                if ($DisableOnlyIf.LastSeenIntuneMoreThan -le $Computer.IntuneLastSeenDays) {
                    continue SkipComputer
                }
            }
        }
        if ($IncludeJamf) {
            if ($null -ne $DisableOnlyIf.LastContactJamfMoreThan -and $null -ne $Computer.JamfLastContactTimeDays) {
                if ($DisableOnlyIf.LastContactJamfMoreThan -le $Computer.JamfLastContactTimeDays) {
                    continue SkipComputer
                }
            }
        }

        $Computer.'Action' = 'Disable'
        $Count++
    }
    $Count
}