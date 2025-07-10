function Get-InitialADComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [System.Collections.IDictionary] $ForestInformation,
        [object] $Filter,
        [object] $SearchBase,
        [string[]] $Properties,
        [bool] $Disable,
        [bool] $Delete,
        [bool] $Move,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [System.Collections.IDictionary] $MoveOnlyIf,
        [Array] $Exclusions,
        [System.Collections.IDictionary] $ProcessedComputers,
        [nullable[int]] $SafetyADLimit,
        [System.Collections.IDictionary] $AzureInformationCache,
        [System.Collections.IDictionary] $JamfInformationCache,
        [object] $TargetServers,
        [int] $ADQueryMaxRetries = 3,
        [int] $ADQueryRetryDelay = 5,
        [int] $ADQueryPageSize = 1000
    )
    $AllComputers = [ordered] @{}

    $AzureRequired = $false
    $IntuneRequired = $false
    $JamfRequired = $false

    if ($DisableOnlyIf) {
        if ($null -ne $DisableOnlyIf.LastSyncAzureMoreThan -or $null -ne $DisableOnlyIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $DisableOnlyIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
        if ($null -ne $DisableOnlyIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
    }
    if ($MoveOnlyIf) {
        if ($null -ne $MoveOnlyIf.LastSyncAzureMoreThan -or $null -ne $MoveOnlyIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $MoveOnlyIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
        if ($null -ne $MoveOnlyIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
    }
    if ($DeleteOnlyIf) {
        if ($null -ne $DeleteOnlyIf.LastSyncAzureMoreThan -or $null -ne $DeleteOnlyIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $DeleteOnlyIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
        if ($null -ne $DeleteOnlyIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
    }

    if ($TargetServers) {
        # User provided target servers/server. If there is only one we assume user wants to use it for all domains (hopefully just one domain)
        # If there are multiple we assume user wants to use different servers for different domains using hashtable/dictionary
        # If there is no server for a domain we will use the default server, as detected
        if ($TargetServers -is [string]) {
            $TargetServer = $TargetServers
        }
        if ($TargetServers -is [System.Collections.IDictionary]) {
            $TargetServerDictionary = $TargetServers
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
        if ($TargetServer) {
            Write-Color -Text "Overwritting target server for domain ", $Domain, ": ", $TargetServer -Color Yellow, Magenta
            $Server = $TargetServer
        } elseif ($TargetServerDictionary) {
            if ($TargetServerDictionary[$Domain]) {
                Write-Color -Text "Overwritting target server for domain ", $Domain, ": ", $TargetServerDictionary[$Domain] -Color Yellow, Magenta
                $Server = $TargetServerDictionary[$Domain]
            }
        }
        $DomainInformation = $ForestInformation.DomainsExtended[$Domain]
        $Report["$Domain"]['Server'] = $Server
        Write-Color "[i] Getting all computers for domain ", $Domain, " [", $CountDomains, "/", $ForestInformation.Domains.Count, "]", " from ", $Server -Color Yellow, Magenta, Yellow, Magenta, Yellow, Magenta, Yellow, Yellow, Magenta

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

        $getADComputerSplat = @{
            Filter         = $FilterToUse
            Server         = $Server
            Properties     = $Properties
            ErrorAction    = 'Stop'
            # Use ADQueryPageSize for consistent paging behavior
            ResultPageSize = $ADQueryPageSize
            ResultSetSize  = $null
        }
        if ($SearchBaseToUse) {
            $getADComputerSplat.SearchBase = $SearchBaseToUse
        }

        # Implement retry logic for handling enumeration context errors
        $MaxRetries = $ADQueryMaxRetries
        $RetryDelay = $ADQueryRetryDelay
        $Computers = @()
        $Success = $false

        for ($RetryCount = 1; $RetryCount -le $MaxRetries; $RetryCount++) {
            try {
                Write-Color "[i] ", "Attempting to get computers (attempt $RetryCount of $MaxRetries)..." -Color Yellow, Cyan
                [Array] $Computers = Get-ADComputer @getADComputerSplat
                $Success = $true
                break
            } catch {
                $ErrorMessage = $_.Exception.Message
                if ($ErrorMessage -like "*invalid enumeration context*" -or $ErrorMessage -like "*timeout*" -or $ErrorMessage -like "*server is not operational*") {
                    Write-Color "[w] ", "Enumeration error on attempt $RetryCount`: $ErrorMessage" -Color Yellow, DarkYellow
                    if ($RetryCount -lt $MaxRetries) {
                        Write-Color "[i] ", "Waiting $RetryDelay seconds before retry..." -Color Yellow, Cyan
                        Start-Sleep -Seconds $RetryDelay
                        # Increase delay for next retry
                        $RetryDelay = $RetryDelay * 2
                    }
                } elseif ($ErrorMessage -like "*distinguishedName must belong to one of the following partition*") {
                    Write-Color "[e] ", "Error getting computers for domain $($Domain): ", $ErrorMessage -Color Yellow, Red
                    Write-Color "[e] ", "Please check if the distinguishedName for SearchBase is correct for the domain. If you have multiple domains please use Hashtable/Dictionary to provide relevant data or using IncludeDomains/ExcludeDomains functionality" -Color Yellow, Red
                    return $false
                } else {
                    Write-Color "[e] ", "Error getting computers for domain $($Domain): ", $ErrorMessage -Color Yellow, Red
                    # For non-retry-able errors, break the loop
                    break
                }
            }
        }

        # If all retries failed, try alternative approach with smaller page size
        if (-not $Success) {
            Write-Color "[w] ", "Standard query failed after $MaxRetries attempts. Trying alternative approach with smaller page size..." -Color Yellow, DarkYellow
            try {
                # Use a smaller page size to handle large result sets
                $getADComputerSplat.ResultPageSize = [math]::Min($ADQueryPageSize, 500)
                $getADComputerSplat.ResultSetSize = $null
                [Array] $Computers = Get-ADComputer @getADComputerSplat
                $Success = $true
                Write-Color "[+] ", "Alternative query with smaller page size succeeded!" -Color Yellow, Green
            } catch {
                Write-Color "[e] ", "All query attempts failed for domain $($Domain): ", $_.Exception.Message -Color Yellow, Red
                return $false
            }
        }

        if (-not $Success) {
            Write-Color "[e] ", "Failed to retrieve computers for domain $($Domain) after all attempts." -Color Yellow, Red
            return $false
        }

        foreach ($Computer in $Computers) {
            # we will be using it later to just check if computer exists in AD
            $DomainName = ConvertFrom-DistinguishedName -DistinguishedName $Computer.DistinguishedName -ToDomainCN
            $ComputerFullName = -join ($Computer.SamAccountName, "@", $DomainName)
            # initially we used DN, but DN changes when moving so it wouldn't work
            $AllComputers[$ComputerFullName] = $Computer
        }
        $Report["$Domain"]['Computers'] = @(
            $convertToPreparedComputerSplat = @{
                Computers             = $Computers
                AzureInformationCache = $AzureInformationCache
                JamfInformationCache  = $JamfInformationCache
                IncludeAzureAD        = $AzureRequired
                IncludeJamf           = $JamfRequired
                IncludeIntune         = $IntuneRequired
            }

            ConvertTo-PreparedComputer @convertToPreparedComputerSplat
        )
        Write-Color "[i] ", "Computers found for domain $Domain`: ", $($Computers.Count) -Color Yellow, Cyan, Green
        if ($Disable) {
            Write-Color "[i] ", "Processing computers to disable for domain $Domain" -Color Yellow, Cyan, Green
            $getADComputersToDisableSplat = @{
                Computers             = $Report["$Domain"]['Computers']
                DisableOnlyIf         = $DisableOnlyIf
                Exclusions            = $Exclusions
                DomainInformation     = $DomainInformation
                ProcessedComputers    = $ProcessedComputers
                AzureInformationCache = $AzureInformationCache
                JamfInformationCache  = $JamfInformationCache
                IncludeAzureAD        = $AzureRequired
                IncludeJamf           = $JamfRequired
                IncludeIntune         = $IntuneRequired
                Type                  = 'Disable'
            }
            $Report["$Domain"]['ComputersToBeDisabled'] = Get-ADComputersToProcess @getADComputersToDisableSplat
            #Write-Color "[i] ", "Computers to be disabled for domain $Domain`: ", $($Report["$Domain"]['ComputersToBeDisabled'].Count) -Color Yellow, Cyan, Green
        }
        if ($Move) {
            Write-Color "[i] ", "Processing computers to move for domain $Domain" -Color Yellow, Cyan, Green
            $getADComputersToDeleteSplat = @{
                Computers             = $Report["$Domain"]['Computers']
                MoveOnlyIf            = $MoveOnlyIf
                Exclusions            = $Exclusions
                DomainInformation     = $DomainInformation
                ProcessedComputers    = $ProcessedComputers
                AzureInformationCache = $AzureInformationCache
                JamfInformationCache  = $JamfInformationCache
                IncludeAzureAD        = $AzureRequired
                IncludeJamf           = $JamfRequired
                IncludeIntune         = $IntuneRequired
                Type                  = 'Move'
            }
            $Report["$Domain"]['ComputersToBeMoved'] = Get-ADComputersToProcess @getADComputersToDeleteSplat
            #Write-Color "[i] ", "Computers to be moved for domain $Domain`: ", $($Report["$Domain"]['ComputersToBeMoved'].Count) -Color Yellow, Cyan, Green
        }
        if ($Delete) {
            Write-Color "[i] ", "Processing computers to delete for domain $Domain" -Color Yellow, Cyan, Green
            $getADComputersToDeleteSplat = @{
                Computers             = $Report["$Domain"]['Computers']
                DeleteOnlyIf          = $DeleteOnlyIf
                Exclusions            = $Exclusions
                DomainInformation     = $DomainInformation
                ProcessedComputers    = $ProcessedComputers
                AzureInformationCache = $AzureInformationCache
                JamfInformationCache  = $JamfInformationCache
                IncludeAzureAD        = $AzureRequired
                IncludeJamf           = $JamfRequired
                IncludeIntune         = $IntuneRequired
                Type                  = 'Delete'
            }
            $Report["$Domain"]['ComputersToBeDeleted'] = Get-ADComputersToProcess @getADComputersToDeleteSplat
            #Write-Color "[i] ", "Computers to be deleted for domain $Domain`: ", $($Report["$Domain"]['ComputersToBeDeleted'].Count) -Color Yellow, Cyan, Green
        }
    }
    if ($null -ne $SafetyADLimit -and $AllComputers.Count -lt $SafetyADLimit) {
        Write-Color "[e] ", "Only ", $($AllComputers.Count), " computers found in AD, this is less than the safety limit of ", $SafetyADLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
        return $false
    }
    $AllComputers
}