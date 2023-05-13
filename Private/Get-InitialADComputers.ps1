function Get-InitialADComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [System.Collections.IDictionary] $ForestInformation,
        [string] $Filter,
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
        [System.Collections.IDictionary] $JamfInformationCache
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

    foreach ($Domain in $ForestInformation.Domains) {
        $Report["$Domain"] = [ordered] @{ }
        $Server = $ForestInformation['QueryServers'][$Domain].HostName[0]
        if (-not $Server) {
            Write-Color "[e] ", "No server found for domain $Domain" -Color Yellow, Red
            continue
        }
        $DomainInformation = $ForestInformation.DomainsExtended[$Domain]
        $Report["$Domain"]['Server'] = $Server
        Write-Color "[i] Getting all computers for domain ", $Domain -Color Yellow, Magenta, Yellow
        [Array] $Computers = Get-ADComputer -Filter $Filter -Server $Server -Properties $Properties #| Where-Object { $_.SamAccountName -like 'Windows2012*' }
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
        }
    }
    if ($null -ne $SafetyADLimit -and $AllComputers.Count -lt $SafetyADLimit) {
        Write-Color "[e] ", "Only ", $($AllComputers.Count), " computers found in AD, this is less than the safety limit of ", $SafetyADLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
        return $false
    }
    $AllComputers
}