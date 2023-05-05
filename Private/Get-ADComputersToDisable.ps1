function Get-ADComputersToDisable {
    [cmdletBinding()]
    param(
        [Array] $Computers,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [Array] $Exclusions = @('OU=Domain Controllers'),
        [string] $Filter = '*',
        [Microsoft.ActiveDirectory.Management.ADDomain] $DomainInformation,
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
            # $AzureADComputer = $AzureInformationCache['AzureAD']["$($Computer.Name)"]
            # if ($AzureADComputer) {
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
            # }
            # $DataAzureAD = [ordered] @{
            #     'AzureLastSeen'     = $AzureADComputer.LastSeen
            #     'AzureLastSeenDays' = $AzureADComputer.LastSeenDays
            #     'AzureLastSync'     = $AzureADComputer.LastSynchronized
            #     'AzureLastSyncDays' = $AzureADComputer.LastSynchronizedDays
            #     'AzureOwner'        = $AzureADComputer.OwnerDisplayName
            #     'AzureOwnerStatus'  = $AzureADComputer.OwnerEnabled
            #     'AzureOwnerUPN'     = $AzureADComputer.OwnerUserPrincipalName
            # }
        }
        if ($IncludeIntune) {
            # data was requested from Intune
            # $IntuneComputer = $AzureInformationCache['Intune']["$($Computer.Name)"]
            # if ($IntuneComputer) {
            if ($null -ne $DisableOnlyIf.LastSeenIntuneMoreThan -and $null -ne $Computer.IntuneLastSeenDays) {
                if ($DisableOnlyIf.LastSeenIntuneMoreThan -le $Computer.IntuneLastSeenDays) {
                    continue SkipComputer
                }
            }
            # } else {
            #     $IntuneComputer = $null
            # }
            # $DataIntune = [ordered] @{
            #     'IntuneLastSeen'     = $IntuneComputer.LastSeen
            #     'IntuneLastSeenDays' = $IntuneComputer.LastSeenDays
            #     'IntuneUser'         = $IntuneComputer.UserDisplayName
            #     'IntuneUserUPN'      = $IntuneComputer.UserPrincipalName
            #     'IntuneUserEmail'    = $IntuneComputer.EmailAddress
            # }
        }
        if ($IncludeJamf) {
            #$JamfComputer = $JamfInformationCache["$($Computer.Name)"]
            #if ($JamfComputer) {
            if ($null -ne $DisableOnlyIf.LastContactJamfMoreThan -and $null -ne $Computer.JamfLastContactTimeDays) {
                if ($DisableOnlyIf.LastContactJamfMoreThan -le $Computer.JamfLastContactTimeDays) {
                    continue SkipComputer
                }
            }
            #}
            # $DataJamf = [ordered] @{
            #     JamfLastContactTime     = $JamfComputer.lastContactTime
            #     JamfLastContactTImeDays = $JamfComputer.lastContactTimeDays
            #     JamfCapableUsers        = $JamfComputer.mdmCapableCapableUsers
            # }
        }

        $Computer.'Action' = 'Disable'
        $Count++
        # $DataStart = [ordered] @{
        #     'DNSHostName'             = $Computer.DNSHostName
        #     'SamAccountName'          = $Computer.SamAccountName
        #     'Enabled'                 = $Computer.Enabled
        #     'Action'                  = 'Disable'
        #     'ActionStatus'            = $null
        #     'ActionDate'              = $null
        #     'ActionComment'           = $null
        #     'OperatingSystem'         = $Computer.OperatingSystem
        #     'OperatingSystemVersion'  = $Computer.OperatingSystemVersion
        #     'OperatingSystemLong'     = ConvertTo-OperatingSystem -OperatingSystem $Computer.OperatingSystem -OperatingSystemVersion $Computer.OperatingSystemVersion
        #     'LastLogonDate'           = $Computer.LastLogonDate
        #     'LastLogonDays'           = ([int] $(if ($null -ne $Computer.LastLogonDate) { "$(-$($Computer.LastLogonDate - $Today).Days)" } else { }))
        #     'PasswordLastSet'         = $Computer.PasswordLastSet
        #     'PasswordLastChangedDays' = ([int] $(if ($null -ne $Computer.PasswordLastSet) { "$(-$($Computer.PasswordLastSet - $Today).Days)" } else { }))
        # }
        # $DataEnd = [ordered] @{
        #     'PasswordExpired'      = $Computer.PasswordExpired
        #     'LogonCount'           = $Computer.logonCount
        #     'ManagedBy'            = $Computer.ManagedBy
        #     'DistinguishedName'    = $Computer.DistinguishedName
        #     'OrganizationalUnit'   = ConvertFrom-DistinguishedName -DistinguishedName $Computer.DistinguishedName -ToOrganizationalUnit
        #     'Description'          = $Computer.Description
        #     'WhenCreated'          = $Computer.WhenCreated
        #     'WhenChanged'          = $Computer.WhenChanged
        #     'ServicePrincipalName' = $Computer.servicePrincipalName -join [System.Environment]::NewLine
        # }
        # if ($Script:CleanupOptions.AzureAD -and $Script:CleanupOptions.Intune -and $Script:CleanupOptions.Jamf) {
        #     $Data = $DataStart + $DataAzureAD + $DataIntune + $DataJamf + $DataEnd
        # } elseif ($Script:CleanupOptions.AzureAD -and $Script:CleanupOptions.Intune) {
        #     $Data = $DataStart + $DataAzureAD + $DataIntune + $DataEnd
        # } elseif ($Script:CleanupOptions.AzureAD -and $Script:CleanupOptions.Jamf) {
        #     $Data = $DataStart + $DataAzureAD + $DataJamf + $DataEnd
        # } elseif ($Script:CleanupOptions.Intune -and $Script:CleanupOptions.Jamf) {
        #     $Data = $DataStart + $DataIntune + $DataJamf + $DataEnd
        # } elseif ($Script:CleanupOptions.AzureAD) {
        #     $Data = $DataStart + $DataAzureAD + $DataEnd
        # } elseif ($Script:CleanupOptions.Intune) {
        #     $Data = $DataStart + $DataIntune + $DataEnd
        # } elseif ($Script:CleanupOptions.Jamf) {
        #     $Data = $DataStart + $DataJamf + $DataEnd
        # } else {
        #     $Data = $DataStart + $DataEnd
        # }
        # [PSCustomObject] $Data
    }
    $Count
}