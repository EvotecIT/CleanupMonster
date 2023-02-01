﻿function Get-ADComputersToDelete {
    [cmdletBinding()]
    param(
        [Array] $Computers,
        [System.Collections.IDictionary] $DeleteOnlyIf = @{
            IsEnabled               = $null
            NoServicePrincipalName  = $null
            LastLogonDateMoreThan   = 60
            PasswordLastSetMoreThan = 60
            ListProcessedMoreThan   = 60
            ExcludeSystems          = @()
            IncludeSystems          = @()
        },
        [Array] $Exclusions = @('OU=Domain Controllers'),
        [Microsoft.ActiveDirectory.Management.ADDomain] $DomainInformation,
        [System.Collections.IDictionary] $ProcessedComputers
    )
    $Today = Get-Date
    :SkipComputer foreach ($Computer in $Computers) {

        if ($DeleteOnlyIf.ListProcessedMoreThan) {
            # if more then 0 this means computer has to be on list of disabled computers for that number of days.

            if ($ProcessedComputers.Count -gt 0) {
                $FoundComputer = $ProcessedComputers["$($Computer.DistinguishedName)"]
                if ($FoundComputer) {
                    if ($FoundComputer.DateDisabled -is [DateTime]) {
                        $TimeSpan = New-TimeSpan -Start $FoundComputer.DateDisabled -End $Today
                        if ($TimeSpan.Days -gt $DeleteOnlyIf.ListProcessedMoreThan) {

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
        if ($DeleteOnlyIf.ExcludeSystems.Count -gt 0) {
            foreach ($Exclude in $DeleteOnlyIf.ExcludeSystems) {
                if ($Computer.OperatingSystem -like $Exclude) {
                    continue SkipComputer
                }
            }
        }
        if ($DeleteOnlyIf.IncludeSystems.Count -gt 0) {
            $FoundInclude = $false
            foreach ($Include in $DeleteOnlyIf.IncludeSystems) {
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
        if ($DeleteOnlyIf.IsEnabled -eq $true) {
            # Delete computer only if it's Enabled
            if ($Computer.Enabled -eq $false) {
                continue SkipComputer
            }
        } elseif ($DeleteOnlyIf.IsEnabled -eq $false) {
            # Delete computer only if it's Disabled
            if ($Computer.Enabled -eq $true) {
                continue SkipComputer
            }
        } else {
            # If null it should ignore confition
        }
        if ($DeleteOnlyIf.NoServicePrincipalName -eq $true) {
            # Delete computer only if it has no service principal names defined
            if ($Computer.servicePrincipalName.Count -gt 0) {
                continue SkipComputer
            }
        } elseif ($DeleteOnlyIf.NoServicePrincipalName -eq $false) {
            # Delete computer only if it has service principal names defined
            if ($Computer.servicePrincipalName.Count -eq 0) {
                continue SkipComputer
            }
        } else {
            # If null it should ignore confition
        }

        if ($DeleteOnlyIf.LastLogonDateMoreThan) {
            # This runs only if more than 0
            if ($Computer.LastLogonDate) {
                # We ignore empty

                $TimeToCompare = ($Computer.LastLogonDate).AddDays($DeleteOnlyIf.LastLogonDateMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipComputer
                }
            }
        }
        if ($DeleteOnlyIf.PasswordLastSetMoreThan) {
            # This runs only if more than 0
            if ($Computer.PasswordLastSet) {
                # We ignore empty

                $TimeToCompare = ($Computer.PasswordLastSet).AddDays($DeleteOnlyIf.PasswordLastSetMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipComputer
                }
            }
        }
        [PSCustomObject] @{
            'DNSHostName'             = $Computer.DNSHostName
            'SamAccountName'          = $Computer.SamAccountName
            'Enabled'                 = $Computer.Enabled
            'OperatingSystem'         = $Computer.OperatingSystem
            'OperatingSystemVersion'  = $Computer.OperatingSystemVersion
            'OperatingSystemLong'     = ConvertTo-OperatingSystem -OperatingSystem $Computer.OperatingSystem -OperatingSystemVersion $Computer.OperatingSystemVersion
            'LastLogonDate'           = $Computer.LastLogonDate
            'LastLogonDays'           = ([int] $(if ($null -ne $Computer.LastLogonDate) { "$(-$($Computer.LastLogonDate - $Today).Days)" } else { }))
            'PasswordLastSet'         = $Computer.PasswordLastSet
            'PasswordLastChangedDays' = ([int] $(if ($null -ne $Computer.PasswordLastSet) { "$(-$($Computer.PasswordLastSet - $Today).Days)" } else { }))
            'PasswordExpired'         = $Computer.PasswordExpired
            'logonCount'              = $Computer.logonCount
            'ManagedBy'               = $Computer.ManagedBy
            'DistinguishedName'       = $Computer.DistinguishedName
            'OrganizationalUnit'      = ConvertFrom-DistinguishedName -DistinguishedName $Computer.DistinguishedName -ToOrganizationalUnit
            'Description'             = $Computer.Description
            'WhenCreated'             = $Computer.WhenCreated
            'WhenChanged'             = $Computer.WhenChanged
            'ServicePrincipalName'    = $Computer.servicePrincipalName -join [System.Environment]::NewLine
            'DateDisabled'            = $null
        }
    }
}