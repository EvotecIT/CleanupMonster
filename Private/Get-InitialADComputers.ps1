function Get-InitialADComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [System.Collections.IDictionary] $ForestInformation,
        [string] $Filter,
        [string[]] $Properties,
        [bool] $Disable,
        [bool] $Delete,
        [nullable[int]] $DisableLastLogonDateMoreThan,
        [nullable[int]] $DeleteLastLogonDateMoreThan,
        [nullable[bool]] $DeleteNoServicePrincipalName,
        [nullable[bool]] $DisableNoServicePrincipalName,
        [nullable[bool]] $DeleteIsEnabled,
        [nullable[bool]] $DisableIsEnabled,
        [nullable[int]] $DisablePasswordLastSetMoreThan,
        [nullable[int]] $DeletePasswordLastSetMoreThan,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
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
            $AllComputers[$($Computer.DistinguishedName)] = $Computer
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
            Write-Color "[i] ", "Looking for computers with LastLogonDate more than ", $DisableLastLogonDateMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            Write-Color "[i] ", "Looking for computers with PasswordLastSet more than ", $DisablePasswordLastSetMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            if ($DisableNoServicePrincipalName) {
                Write-Color "[i] ", "Looking for computers with no ServicePrincipalName" -Color Yellow, Cyan, Green
            }
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
            }
            $Report["$Domain"]['ComputersToBeDisabled'] = Get-ADComputersToDisable @getADComputersToDisableSplat
        }
        if ($Delete) {
            Write-Color "[i] ", "Processing computers to delete for domain $Domain" -Color Yellow, Cyan, Green
            Write-Color "[i] ", "Looking for computers with LastLogonDate more than ", $DeleteLastLogonDateMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            Write-Color "[i] ", "Looking for computers with PasswordLastSet more than ", $DeletePasswordLastSetMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            if ($DeleteNoServicePrincipalName) {
                Write-Color "[i] ", "Looking for computers with no ServicePrincipalName" -Color Yellow, Cyan, Green
            }
            if ($null -ne $DeleteIsEnabled) {
                if ($DeleteIsEnabled) {
                    Write-Color "[i] ", "Looking for computers that are enabled" -Color Yellow, Cyan, Green
                } else {
                    Write-Color "[i] ", "Looking for computers that are disabled" -Color Yellow, Cyan, Green
                }
            }
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
            }
            $Report["$Domain"]['ComputersToBeDeleted'] = Get-ADComputersToDelete @getADComputersToDeleteSplat
        }
    }
    if ($null -ne $SafetyADLimit -and $AllComputers.Count -lt $SafetyADLimit) {
        Write-Color "[e] ", "Only ", $($AllComputers.Count), " computers found in AD, this is less than the safety limit of ", $SafetyADLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
        return $false
    }
    $AllComputers
}