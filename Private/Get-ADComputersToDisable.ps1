function Get-ADComputersToDisable {
    [cmdletBinding()]
    param(
        [Array] $Computers,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [Array] $Exclusions = @('OU=Domain Controllers'),
        [string] $Filter = '*',
        [Microsoft.ActiveDirectory.Management.ADDomain] $DomainInformation,
        [System.Collections.IDictionary] $ProcessedComputers
    )
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
        # we skip disabled computers from disabling, always
        # if ($Computer.Enabled -eq $false) {
        #     continue
        # }

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
            if ($PartialExclusion -like '*DC=*') {
                $Exclusion = $PartialExclusion
            } else {
                $Exclusion = -join ($PartialExclusion, ',', $DomainInformation.DistinguishedName)
            }
            if ($Computer.DistinguishedName -like "*$Exclusion") {
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

        [PSCustomObject] @{
            'DNSHostName'             = $Computer.DNSHostName
            'SamAccountName'          = $Computer.SamAccountName
            'Enabled'                 = $Computer.Enabled
            'Action'                  = 'Disable'
            'ActionStatus'            = $null
            'ActionDate'              = $null
            'OperatingSystem'         = $Computer.OperatingSystem
            'OperatingSystemVersion'  = $Computer.OperatingSystemVersion
            'OperatingSystemLong'     = ConvertTo-OperatingSystem -OperatingSystem $Computer.OperatingSystem -OperatingSystemVersion $Computer.OperatingSystemVersion
            'LastLogonDate'           = $Computer.LastLogonDate
            'LastLogonDays'           = ([int] $(if ($null -ne $Computer.LastLogonDate) { "$(-$($Computer.LastLogonDate - $Today).Days)" } else { }))
            'PasswordLastSet'         = $Computer.PasswordLastSet
            'PasswordLastChangedDays' = ([int] $(if ($null -ne $Computer.PasswordLastSet) { "$(-$($Computer.PasswordLastSet - $Today).Days)" } else { }))
            'PasswordExpired'         = $Computer.PasswordExpired
            'LogonCount'              = $Computer.logonCount
            'ManagedBy'               = $Computer.ManagedBy
            'DistinguishedName'       = $Computer.DistinguishedName
            'OrganizationalUnit'      = ConvertFrom-DistinguishedName -DistinguishedName $Computer.DistinguishedName -ToOrganizationalUnit
            'Description'             = $Computer.Description
            'WhenCreated'             = $Computer.WhenCreated
            'WhenChanged'             = $Computer.WhenChanged
            'ServicePrincipalName'    = $Computer.servicePrincipalName -join [System.Environment]::NewLine
        }
    }
}