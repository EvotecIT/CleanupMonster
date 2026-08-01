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

    $AllComputerKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $SuccessfulDomains = [System.Collections.Generic.List[string]]::new()
    $FailedDomains = [System.Collections.Generic.List[string]]::new()

    $AzureRequired = $false
    $IntuneRequired = $false
    $JamfRequired = $false

    foreach ($ActionIf in @($DisableOnlyIf, $MoveOnlyIf, $DeleteOnlyIf)) {
        if ($null -eq $ActionIf) {
            continue
        }
        if ($null -ne $ActionIf.LastSyncAzureMoreThan -or $null -ne $ActionIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $ActionIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
        if ($null -ne $ActionIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
    }

    $CountDomains = 0
    foreach ($Domain in $ForestInformation.Domains) {
        $CountDomains++
        $DetectedServers = @($ForestInformation['QueryServers'][$Domain].HostName)
        $ServerCandidates = @(Get-ADQueryServerCandidates -Domain $Domain -TargetServers $TargetServers -DetectedServers $DetectedServers)
        $DomainInformation = $ForestInformation.DomainsExtended[$Domain]

        $Report["$Domain"] = [ordered] @{
            QueryStatus          = 'Pending'
            QueryError           = $null
            Server               = $null
            ServerCandidates     = $ServerCandidates
            AttemptedServers     = @()
            QueryAttempts        = 0
            ComputerCount        = 0
            Computers            = @()
            ComputersToBeDisabled = 0
            ComputersToBeMoved   = 0
            ComputersToBeDeleted = 0
        }

        if ($ServerCandidates.Count -eq 0) {
            $Report["$Domain"].QueryStatus = 'Failed'
            $Report["$Domain"].QueryError = "No domain controller was found for $Domain."
            $FailedDomains.Add($Domain)
            Write-Color -Text '[e] ', $Report["$Domain"].QueryError -Color Yellow, Red
            continue
        }

        Write-Color -Text '[i] ', "Getting all computers for domain $Domain [$CountDomains/$($ForestInformation.Domains.Count)]. Candidate servers: $($ServerCandidates -join ', ')" -Color Yellow, Magenta

        if ($Filter) {
            if ($Filter -is [string]) {
                $FilterToUse = $Filter
            } elseif ($Filter -is [System.Collections.IDictionary]) {
                $FilterToUse = $Filter[$Domain]
                if ([string]::IsNullOrWhiteSpace([string] $FilterToUse)) {
                    $FilterToUse = '*'
                }
            } else {
                Write-Color -Text '[e] ', 'Filter must be a string or a hashtable/ordereddictionary.' -Color Yellow, Red
                return $false
            }
        } else {
            $FilterToUse = '*'
        }

        if ($SearchBase) {
            if ($SearchBase -is [string]) {
                $SearchBaseToUse = $SearchBase
            } elseif ($SearchBase -is [System.Collections.IDictionary]) {
                $SearchBaseToUse = $SearchBase[$Domain]
            } else {
                Write-Color -Text '[e] ', 'SearchBase must be a string or a hashtable/ordereddictionary.' -Color Yellow, Red
                return $false
            }
        } else {
            $SearchBaseToUse = $DomainInformation.DistinguishedName
        }

        $QueryParameters = @{
            Filter     = $FilterToUse
            Properties = $Properties
        }
        if ($SearchBaseToUse) {
            $QueryParameters.SearchBase = $SearchBaseToUse
        }

        $QueryResult = Invoke-ADComputerInventoryQuery `
            -Domain $Domain `
            -Servers $ServerCandidates `
            -QueryParameters $QueryParameters `
            -AzureInformationCache $AzureInformationCache `
            -JamfInformationCache $JamfInformationCache `
            -IncludeAzureAD:$AzureRequired `
            -IncludeIntune:$IntuneRequired `
            -IncludeJamf:$JamfRequired `
            -MaxAttemptsPerServer $ADQueryMaxRetries `
            -RetryDelaySeconds $ADQueryRetryDelay `
            -PageSize $ADQueryPageSize

        $Report["$Domain"].Server = $QueryResult.Server
        $Report["$Domain"].AttemptedServers = @($QueryResult.Attempts | Select-Object -ExpandProperty Server -Unique)
        $Report["$Domain"].QueryAttempts = $QueryResult.Attempts.Count

        if (-not $QueryResult.Succeeded) {
            $Report["$Domain"].QueryStatus = 'Failed'
            $Report["$Domain"].QueryError = $QueryResult.Error
            $FailedDomains.Add($Domain)
            Write-Color -Text '[e] ', "Unable to inventory domain $Domain after trying $($Report["$Domain"].AttemptedServers -join ', '): $($QueryResult.Error)" -Color Yellow, Red
            continue
        }

        [Array] $Computers = $QueryResult.Computers
        $Report["$Domain"].QueryStatus = 'Succeeded'
        $Report["$Domain"].ComputerCount = $Computers.Count
        $Report["$Domain"].Computers = $Computers
        $SuccessfulDomains.Add($Domain)

        foreach ($Computer in $Computers) {
            $ComputerFullName = -join ($Computer.SamAccountName, '@', $Computer.DomainName)
            $null = $AllComputerKeys.Add($ComputerFullName)
        }

        Write-Color -Text '[i] ', "Computers found for domain $Domain through $($QueryResult.Server): ", $Computers.Count -Color Yellow, Cyan, Green

        if ($Disable) {
            Write-Color -Text '[i] ', "Processing computers to disable for domain $Domain" -Color Yellow, Cyan
            $Report["$Domain"].ComputersToBeDisabled = Get-ADComputersToProcess `
                -Computers $Computers `
                -DisableOnlyIf $DisableOnlyIf `
                -Exclusions $Exclusions `
                -DomainInformation $DomainInformation `
                -ProcessedComputers $ProcessedComputers `
                -AzureInformationCache $AzureInformationCache `
                -JamfInformationCache $JamfInformationCache `
                -IncludeAzureAD:$AzureRequired `
                -IncludeIntune:$IntuneRequired `
                -IncludeJamf:$JamfRequired `
                -Type Disable
        }
        if ($Move) {
            Write-Color -Text '[i] ', "Processing computers to move for domain $Domain" -Color Yellow, Cyan
            $Report["$Domain"].ComputersToBeMoved = Get-ADComputersToProcess `
                -Computers $Computers `
                -MoveOnlyIf $MoveOnlyIf `
                -Exclusions $Exclusions `
                -DomainInformation $DomainInformation `
                -ProcessedComputers $ProcessedComputers `
                -AzureInformationCache $AzureInformationCache `
                -JamfInformationCache $JamfInformationCache `
                -IncludeAzureAD:$AzureRequired `
                -IncludeIntune:$IntuneRequired `
                -IncludeJamf:$JamfRequired `
                -Type Move
        }
        if ($Delete) {
            Write-Color -Text '[i] ', "Processing computers to delete for domain $Domain" -Color Yellow, Cyan
            $Report["$Domain"].ComputersToBeDeleted = Get-ADComputersToProcess `
                -Computers $Computers `
                -DeleteOnlyIf $DeleteOnlyIf `
                -Exclusions $Exclusions `
                -DomainInformation $DomainInformation `
                -ProcessedComputers $ProcessedComputers `
                -AzureInformationCache $AzureInformationCache `
                -JamfInformationCache $JamfInformationCache `
                -IncludeAzureAD:$AzureRequired `
                -IncludeIntune:$IntuneRequired `
                -IncludeJamf:$JamfRequired `
                -Type Delete
        }
    }

    $SafetyLimitSatisfied = $null -eq $SafetyADLimit -or $AllComputerKeys.Count -ge $SafetyADLimit
    if (-not $SafetyLimitSatisfied) {
        Write-Color -Text '[e] ', 'Only ', $AllComputerKeys.Count, ' computers were found in AD, which is below the safety limit of ', $SafetyADLimit, '. All mutations will be suppressed.' -Color Yellow, Cyan, Red, Cyan
    }

    [PSCustomObject] [ordered] @{
        Succeeded            = $FailedDomains.Count -eq 0
        SafetyLimitSatisfied = $SafetyLimitSatisfied
        ComputerKeys         = $AllComputerKeys
        SuccessfulDomains    = $SuccessfulDomains.ToArray()
        FailedDomains        = $FailedDomains.ToArray()
    }
}
