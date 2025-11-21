function Get-InitialADServiceAccounts {
    <#
    .SYNOPSIS
    Gets initial list of service accounts from Active Directory.

    .DESCRIPTION
    This function retrieves MSA and GMSA service accounts from Active Directory
    and processes them for cleanup operations.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [System.Collections.IDictionary] $ForestInformation,
        [object] $Filter,
        [object] $SearchBase,
        [string[]] $Properties,
        [bool] $Disable,
        [bool] $Delete,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [Array] $Exclusions,
        [System.Collections.IDictionary] $ProcessedServiceAccounts,
        [nullable[int]] $SafetyADLimit,
        [object] $TargetServers,
        [string[]] $IncludeOrganizationalUnit,
        [string[]] $ExcludeOrganizationalUnit
    )
    $AllServiceAccounts = [ordered] @{}

    if ($TargetServers) {
        if ($TargetServers -is [string]) {
            $TargetServer = $TargetServers
            Write-Color -Text "[i] Target server configured for all domains: ", $TargetServer -Color Yellow, Cyan
        } elseif ($TargetServers -is [System.Collections.IDictionary]) {
            $TargetServerDictionary = $TargetServers
            if ($TargetServerDictionary.Count -eq 0) {
                Write-Color -Text "[w] Target servers dictionary is empty. Using auto-detected servers." -Color Yellow, DarkYellow
            } else {
                Write-Color -Text "[i] Target servers configured per domain:" -Color Yellow, Cyan
                foreach ($Entry in $TargetServerDictionary.GetEnumerator()) {
                    $DomainKey = if ($Entry.Key) { $Entry.Key } else { "<null>" }
                    $ServerValue = if ($Entry.Value) { $Entry.Value } else { "<null>" }
                    Write-Color -Text "    ", $DomainKey, " -> ", $ServerValue -Color Yellow, Cyan, Yellow, Green
                }
            }
        } else {
            Write-Color -Text "[w] TargetServers parameter is not a string or hashtable/dictionary. Ignoring and using auto-detected servers." -Color Yellow, DarkYellow
        }
    }

    $CountDomains = 0
    foreach ($Domain in $ForestInformation.Domains) {
        $CountDomains++
        $Report["$Domain"] = [ordered] @{ }
        $Server = $ForestInformation['QueryServers'][$Domain].HostName[0]
        if (-not $Server) {
            Write-Color "[e] ", "No server found for domain $Domain" -Color Yellow, Red
            continue
        }

        # Override server if specified in TargetServers
        if ($TargetServers) {
            if ($TargetServers -is [string]) {
                $Server = $TargetServers
                Write-Color -Text "[i] Using configured target server for domain ", $Domain, ": ", $Server -Color Yellow, Cyan
            } elseif ($TargetServers -is [System.Collections.IDictionary]) {
                if ($TargetServers[$Domain]) {
                    $Server = $TargetServers[$Domain]
                    Write-Color -Text "[i] Using configured target server for domain ", $Domain, ": ", $Server -Color Yellow, Cyan
                } else {
                    Write-Color -Text "[i] No target server specified for domain ", $Domain, ", using auto-detected server: ", $Server -Color Yellow, Cyan
                }
            }
        }

        $DomainInformation = $ForestInformation.DomainsExtended[$Domain]
        $Report["$Domain"]['Server'] = $Server
        Write-Color "[i] Getting all service accounts for domain ", $Domain, " [", $CountDomains, "/", $ForestInformation.Domains.Count, "]", " from ", $Server -Color Yellow, Magenta, Yellow, Magenta, Yellow, Magenta, Yellow, Yellow, Magenta

        if ($Filter) {
            if ($Filter -is [string]) {
                $FilterToUse = $Filter
            } elseif ($Filter -is [System.Collections.IDictionary]) {
                $FilterToUse = $Filter[$Domain]
            } else {
                Write-Color "[e] ", "Filter must be a string or a hashtable/ordereddictionary" -Color Yellow, Red
                return $false
            }
        } else {
            $FilterToUse = "*"
        }

        if ($SearchBase) {
            if ($SearchBase -is [string]) {
                $SearchBaseToUse = $SearchBase
            } elseif ($SearchBase -is [System.Collections.IDictionary]) {
                $SearchBaseToUse = $SearchBase[$Domain]
            } else {
                Write-Color "[e] ", "SearchBase must be a string or a hashtable/ordereddictionary" -Color Yellow, Red
                return $false
            }
        } else {
            $SearchBaseToUse = $DomainInformation.DistinguishedName
        }

        # Get MSA accounts (Managed Service Accounts)
        $getMSASplat = @{
            Filter      = $FilterToUse
            Server      = $Server
            Properties  = $Properties
            ErrorAction = 'Stop'
        }
        if ($SearchBaseToUse) {
            $getMSASplat.SearchBase = $SearchBaseToUse
        }

        # Get GMSA accounts (Group Managed Service Accounts)
        $getGMSASplat = @{
            Filter      = $FilterToUse
            Server      = $Server
            Properties  = $Properties
            ErrorAction = 'Stop'
        }
        if ($SearchBaseToUse) {
            $getGMSASplat.SearchBase = $SearchBaseToUse
        }

        $ServiceAccounts = @()
        try {
            Write-Color -Text "[i] ", "Attempting to get MSA service accounts..." -Color Yellow, Cyan
            [Array] $MSAAccounts = @()
            try {
                $MSAAccounts = Get-ADServiceAccount @getMSASplat | Where-Object { $_.ObjectClass -eq 'msDS-ManagedServiceAccount' }
                Write-Color -Text "[+] ", "Found ", $MSAAccounts.Count, " MSA accounts" -Color Yellow, Green, Green, Green
            } catch {
                Write-Color -Text "[w] ", "MSA query failed: ", $_.Exception.Message -Color Yellow, Yellow, DarkYellow
            }

            Write-Color -Text "[i] ", "Attempting to get GMSA service accounts..." -Color Yellow, Cyan
            [Array] $GMSAAccounts = @()
            try {
                $GMSAAccounts = Get-ADServiceAccount @getGMSASplat | Where-Object { $_.ObjectClass -eq 'msDS-GroupManagedServiceAccount' }
                Write-Color -Text "[+] ", "Found ", $GMSAAccounts.Count, " GMSA accounts" -Color Yellow, Green, Green, Green
            } catch {
                Write-Color -Text "[w] ", "GMSA query failed: ", $_.Exception.Message -Color Yellow, Yellow, DarkYellow
            }

            # Combine both types
            $ServiceAccounts = @($MSAAccounts) + @($GMSAAccounts)
            Write-Color -Text "[+] ", "Total service accounts found: ", $ServiceAccounts.Count -Color Yellow, Green, Green

        } catch {
            Write-Color "[e] ", "Failed to retrieve service accounts for domain $($Domain): ", $_.Exception.Message -Color Yellow, Red
            return $false
        }

        if ($SafetyADLimit -and $ServiceAccounts.Count -le $SafetyADLimit) {
            Write-Color "[e] ", "Number of service accounts found in domain $Domain is $($ServiceAccounts.Count), which is less than or equal to SafetyADLimit ($SafetyADLimit). Stopping for safety." -Color Yellow, Red
            return $false
        }

        # Add domain and server info to each service account
        foreach ($ServiceAccount in $ServiceAccounts) {
            if (-not $ServiceAccount) {
                continue
            }
            # Add domain and type information
            $DomainName = ConvertFrom-DistinguishedName -DistinguishedName $ServiceAccount.DistinguishedName -ToDomainCN
            $ServiceAccountFullName = -join ($ServiceAccount.SamAccountName, "@", $DomainName)
            $AllServiceAccounts[$ServiceAccountFullName] = $ServiceAccount

            # Determine service account type
            if ($ServiceAccount.ObjectClass -eq 'msDS-ManagedServiceAccount') {
                $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'ServiceAccountType' -Value 'MSA' -Force
            } elseif ($ServiceAccount.ObjectClass -eq 'msDS-GroupManagedServiceAccount') {
                $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'ServiceAccountType' -Value 'GMSA' -Force
            } else {
                $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'ServiceAccountType' -Value 'Unknown' -Force
            }
        }

        # Filter out null objects
        $Report["$Domain"]['ServiceAccounts'] = @($ServiceAccounts | Where-Object { $_ -ne $null })
        Write-Color "[i] ", "Service accounts found for domain $Domain`: ", $($ServiceAccounts.Count) -Color Yellow, Cyan, Green

        if ($Disable) {
            Write-Color "[i] ", "Processing service accounts to disable for domain $Domain" -Color Yellow, Cyan, Green
            $getADServiceAccountsToDisableSplat = @{
                ServiceAccounts              = $Report["$Domain"]['ServiceAccounts']
                DisableOnlyIf                = $DisableOnlyIf
                Exclusions                   = $Exclusions
                DomainInformation            = $DomainInformation
                ProcessedServiceAccounts     = $ProcessedServiceAccounts
                Type                         = 'Disable'
                IncludeOrganizationalUnit    = $IncludeOrganizationalUnit
                ExcludeOrganizationalUnit    = $ExcludeOrganizationalUnit
            }
            $Report["$Domain"]['ServiceAccountsToBeDisabled'] = Get-ADServiceAccountsToProcess @getADServiceAccountsToDisableSplat
        }

        if ($Delete) {
            Write-Color "[i] ", "Processing service accounts to delete for domain $Domain" -Color Yellow, Cyan, Green
            $getADServiceAccountsToDeleteSplat = @{
                ServiceAccounts              = $Report["$Domain"]['ServiceAccounts']
                DeleteOnlyIf                 = $DeleteOnlyIf
                Exclusions                   = $Exclusions
                DomainInformation            = $DomainInformation
                ProcessedServiceAccounts     = $ProcessedServiceAccounts
                Type                         = 'Delete'
                IncludeOrganizationalUnit    = $IncludeOrganizationalUnit
                ExcludeOrganizationalUnit    = $ExcludeOrganizationalUnit
            }
            $Report["$Domain"]['ServiceAccountsToBeDeleted'] = Get-ADServiceAccountsToProcess @getADServiceAccountsToDeleteSplat
        }
    }
    $AllServiceAccounts
}
