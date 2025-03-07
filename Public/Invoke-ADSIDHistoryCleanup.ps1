function Invoke-ADSIDHistoryCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string] $Forest,
        [alias('Domain')][string[]] $IncludeDomains,
        [string[]] $ExcludeDomains,
        [string[]] $IncludeOrganizationalUnit,
        [string[]] $ExcludeOrganizationalUnit,
        [string[]] $IncludeSIDHistoryDomain,
        [string[]] $ExcludeSIDHistoryDomain,
        [nullable[int]] $RemoveLimit,
        [nullable[int]] $RemoveLimitObject,
        [ValidateSet('Internal', 'External', 'Unknown')][string[]] $IncludeType = @('Internal', 'External', 'Unknown'),
        [ValidateSet('Internal', 'External', 'Unknown')][string[]] $ExcludeType = @()
    )

    $ProcessedSIDs = 0
    $ProcessedObjects = 0
    if ($Null -eq $RemoveLimit -and $null -eq $RemoveLimitObject) {
        $LimitPerObject = $false
        $LimitPerSID = $false
    } elseif ($Null -eq $RemoveLimit) {
        $LimitPerObject = $true
        $LimitPerSID = $false
    } elseif ($Null -eq $RemoveLimitObject) {
        $LimitPerObject = $false
        $LimitPerSID = $true
    } else {
        $LimitPerObject = $true
        $LimitPerSID = $true
    }

    $RemoveFromUsers = [System.Collections.Generic.List[PSCustomObject]]::new()

    $ForestInformation = Get-WinADForestDetails -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains
    $Output = Get-WinADSIDHistory -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains -All

    [Array] $DomainNames = foreach ($Key in $Output.Keys) {
        if ($Key -in @('Statistics', 'Trusts', 'DomainSIDs', 'DuplicateSIDs', 'All')) {
            continue
        }
        $Key
    }

    :TopLoop foreach ($Domain in $DomainNames) {
        [Array] $Objects = $Output[$Domain]
        # we need to get SID domain for the "internal domains" which were translated to their names
        # if ($Domain -notlike "S-1*") {
        #     $TranslatedSID = foreach ($D in $Output.DomainSIDs.Keys) {
        #         $SID = $Output['DomainSIDs'][$D]
        #         if ($SID.Domain -eq $Domain) {
        #             $Output.DomainSIDs[$D]
        #             break
        #         }
        #     }
        #     if ($TranslatedSID) {
        #         $DomainSID = $TranslatedSID.SID
        #     } else {
        #         $DomainSID = $Domain
        #     }
        # } else {
        #     $DomainSID = $Domain
        # }

        if ($null -ne $RemoveLimitObject -and $GlobalLimitObject -ge $RemoveLimitObject) {
            break TopLoop
        }

        if ($ExcludeType.Count -gt 0) {
            if ($ExcludeType -contains 'Internal') {
                if ($Output.DomainSIDs[$Domain] -and $Output.DomainSIDs[$Domain].Type -eq 'Domain') {
                    Write-Color -Text "[s] ", "Skipping ", $Domain, " for domain ", $Output.DomainSIDs[$Domain].Domain, " as it's internal." -Color Yellow, White, Red, White, Red
                    continue
                }
            }
            if ($ExcludeType -contains 'External') {
                if ($Output.DomainSIDs[$Domain] -and $Output.DomainSIDs[$Domain].Type -eq 'Trust') {
                    Write-Color -Text "[s] ", "Skipping ", $Domain, " for domain ", $Output.DomainSIDs[$Domain].Domain, " as it's external (trusted)." -Color Yellow, White, Red, White, Red
                    continue
                }
            }
            if ($ExcludeType -contains 'Unknown') {
                if (-not $Output.DomainSIDs[$Domain]) {
                    Write-Color -Text "[s] ", "Skipping ", $Domain, " as it's unknown type." -Color Yellow, White, Red, White, Red
                    continue
                }
            }
        }

        if ($IncludeType.Count -gt 0) {
            # if ($IncludeType -contains 'Internal') {
            #     if ($Output.DomainSIDs[$Domain] -and $Output.DomainSIDs[$Domain].Type -ne 'Domain') {
            #         Write-Color -Text "[s] ", "Skipping ", $Domain, " for domain ", $Output.DomainSIDs[$Domain].Domain, " as it's not internal." -Color Yellow, White, Red, White, Red
            #         continue
            #     }
            # }
            # if ($IncludeType -contains 'External') {
            #     if ($Output.DomainSIDs[$Domain] -and $Output.DomainSIDs[$Domain].Type -ne 'Trust') {
            #         Write-Color -Text "[s] ", "Skipping ", $Domain, " for domain ", $Output.DomainSIDs[$Domain].Domain, " as it's not external." -Color Yellow, White, Red, White, Red
            #         continue
            #     }
            # }
            # if ($IncludeType -contains 'Unknown') {
            #     if ($Output.DomainSIDs[$Domain] -and $Output.DomainSIDs[$Domain].Type -ne 'Unknown') {
            #         Write-Color -Text "[s] ", "Skipping ", $Domain, " for domain ", $Output.DomainSIDs[$Domain].Domain, " as it's not unknown." -Color Yellow, White, Red, White, Red
            #         continue
            #     }
            # }
        }


        # We need to filter global domains, on a global level
        # if ($IncludeInternalOnly) {
        #     if ($Domain -like "S-1*") {
        #         Write-Color -Text "[s] ", "Skipping ", $Domain, " with ", $DomainSID, " as it's not internal." -Color Yellow, White, Red, White, Red
        #         continue
        #     }
        # }
        # if ($IncludeExternalOnly) {
        #     if ($Domain -notlike "S-1*") {
        #         Write-Color -Text "[s] ", "Skipping ", $Domain, " with ", $DomainSID, " as it's not external." -Color Yellow, White, Red, White, Red
        #         continue
        #     }
        # }
        if ($IncludeSIDHistoryDomain -and $IncludeSIDHistoryDomain -notcontains $DomainSID) {
            if ($Domain -notlike "S-1*") {
                Write-Color -Text "[s] ", "Skipping ", $Domain, " with ", $DomainSID, " not included." -Color Yellow, White, Red, White, Red
            } else {
                Write-Color -Text "[s] ", "Skipping ", $Domain, " not included." -Color Yellow, White, Red
            }
            continue
        }
        if ($ExcludeSIDHistoryDomain -and $ExcludeSIDHistoryDomain -contains $DomainSID) {
            if ($Domain -notlike "S-1*") {
                Write-Color -Text "[s] ", "Skipping ", $Domain, " with ", $DomainSID, " excluded." -Color Yellow, White, Red, White, Red
            } else {
                Write-Color -Text "[s] ", "Skipping ", $Domain, " excluded." -Color Yellow, White, Red
            }
            continue
        }
        if ($Domain -notlike "S-1*") {
            Write-Color -Text "[i] ", "Processing ", $Domain, " with ", $DomainSID -Color Yellow, White, Green, White, Green
        } else {
            Write-Color -Text "[i] ", "Processing ", $Domain -Color Yellow, White, Green
        }

        foreach ($Object in $Objects) {
            $QueryServer = $ForestInformation['QueryServers'][$Object.Domain].HostName[0]

            Write-Color -Text "[i] ", "Processing ", $Object.Name, " (" , "Domain: ", $Object.Domain, ", ObjectClass: ", $Object.ObjectClass, ", SIDHistoryCount: ", $Object.SIDHistory.Count, ", DN: ", $Object.DistinguishedName, ")" -Color Yellow, White, Green, White, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, White

            if ($IncludeSIDHistoryDomain -or $ExcludeSIDHistoryDomain -or $IncludeInternalOnly -or $IncludeExternalOnly) {
                # Remove-SIDHistoryPerDomain -Object $Object -QueryServer $QueryServer
            } else {
                #Remove-SIDHistoryPerUser -Object $Object -QueryServer $QueryServer
            }
        }
    }
}