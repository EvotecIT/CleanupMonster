function Get-InitialADComputersCleanup {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [System.Collections.IDictionary] $AllComputers,
        [Microsoft.ActiveDirectory.Management.ADForest] $Forest,
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
        [System.Collections.IDictionary] $AzureInformationCache

    )
    $AllComputers = [ordered] @{}
    foreach ($Domain in $Forest.Domains) {
        $Report["$Domain"] = [ordered] @{ }
        $DC = Get-ADDomainController -Discover -DomainName $Domain
        $Server = $DC.HostName[0]
        $DomainInformation = Get-ADDomain -Identity $Domain -Server $Server
        $Report["$Domain"]['Server'] = $Server
        Write-Color "[i] Getting all computers for domain ", $Domain -Color Yellow, Magenta, Yellow
        [Array] $Computers = Get-ADComputer -Filter $Filter -Server $Server -Properties $Properties
        foreach ($Computer in $Computers) {
            $AllComputers[$($Computer.DistinguishedName)] = $Computer
        }
        Write-Color "[i] ", "Computers found for domain $Domain`: ", $($Computers.Count) -Color Yellow, Cyan, Green
        if ($Disable) {
            Write-Color "[i] ", "Processing computers to disable for domain $Domain" -Color Yellow, Cyan, Green
            Write-Color "[i] ", "Looking for computers with LastLogonDate more than ", $DisableLastLogonDateMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            Write-Color "[i] ", "Looking for computers with PasswordLastSet more than ", $DisablePasswordLastSetMoreThan, " days" -Color Yellow, Cyan, Green, Cyan
            if ($DisableNoServicePrincipalName) {
                Write-Color "[i] ", "Looking for computers with no ServicePrincipalName" -Color Yellow, Cyan, Green
            }
            $Report["$Domain"]['ComputersToBeDisabled'] = @(
                Get-ADComputersToDisable -Computers $Computers -DisableOnlyIf $DisableOnlyIf -Exclusions $Exclusions -DomainInformation $DomainInformation -ProcessedComputers $ProcessedComputers -AzureInformationCache $AzureInformationCache
            )
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
            $Report["$Domain"]['ComputersToBeDeleted'] = @(
                Get-ADComputersToDelete -Computers $Computers -DeleteOnlyIf $DeleteOnlyIf -Exclusions $Exclusions -DomainInformation $DomainInformation -ProcessedComputers $ProcessedComputers -AzureInformationCache $AzureInformationCache
            )
        }
    }
    if ($null -ne $SafetyADLimit -and $AllComputers.Count -lt $SafetyADLimit) {
        Write-Color "[e] ", "Only ", $($AllComputers.Count), " computers found in AD, this is less than the safety limit of ", $SafetyADLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
        return $false
    }
    $AllComputers
}