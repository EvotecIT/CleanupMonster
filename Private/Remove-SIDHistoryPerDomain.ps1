function Remove-SIDHistoryPerDomain {
    [CmdletBinding()]
    param(
        $Object,
        [string] $QueryServer
    )


    return

    :TopLoop foreach ($Domain in $DomainNames) {
        [Array] $Objects = $Output[$Domain]
        if ($Domain -notlike "S-1*") {
            $TranslatedSID = foreach ($D in $Output.DomainSIDs.Keys) {
                $SID = $Output['DomainSIDs'][$D]
                if ($SID.Domain -eq $Domain) {
                    $Output.DomainSIDs[$D]
                    break
                }
            }
            if ($TranslatedSID) {
                $DomainSID = $TranslatedSID.SID
            } else {
                $DomainSID = $Domain
            }
        } else {
            $DomainSID = $Domain
        }
        # We need to filter global domains, on a global level
        if ($IncludeInternalOnly) {
            if ($Domain -like "S-1*") {
                Write-Color -Text "[s] ", "Skipping ", $Domain, " with ", $DomainSID, " as it's not internal." -Color Yellow, White, Red, White, Red
                continue
            }
        }
        if ($IncludeExternalOnly) {
            if ($Domain -notlike "S-1*") {
                Write-Color -Text "[s] ", "Skipping ", $Domain, " with ", $DomainSID, " as it's not external." -Color Yellow, White, Red, White, Red
                continue
            }
        }
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
        # We now scan each object directly
        foreach ($Object in $Objects) {
            <#
                Name               : Brian Williams
                UserPrincipalName  : PUID@ad.evotec.xyz
                Domain             : ad.evotec.pl
                SamAccountName     : PUID
                ObjectClass        : user
                Enabled            : True
                PasswordDays       : 430
                LogonDays          :
                Count              : 5
                SIDHistory         : {S-1-5-21-853615985-2870445339-3163598659-4088, S-1-5-21-3661168273-3802070955-2987026695-4104, S-1-5-21-853615985-2870445339-3163598659-7843, S-1-5-21-3661168273-3802070955-2987026695-4106…}
                Domains            : {S-1-5-21-853615985-2870445339-3163598659, S-1-5-21-3661168273-3802070955-2987026695}
                DomainsExpanded    : {ad.evotec.xyz, ad.evotec.pl}
                External           : {}
                ExternalCount      : 0
                Internal           : {S-1-5-21-853615985-2870445339-3163598659-4088, S-1-5-21-3661168273-3802070955-2987026695-4104, S-1-5-21-853615985-2870445339-3163598659-7843, S-1-5-21-3661168273-3802070955-2987026695-4106…}
                InternalCount      : 5
                WhenCreated        : 2023-12-22 16:31:45
                WhenChanged        : 2023-12-22 16:31:45
                LastLogon          :
                PasswordLastSet    : 2023-12-22 16:31:45
                OrganizationalUnit : OU=Users,OU=Accounts,OU=Production,DC=ad,DC=evotec,DC=pl
                DistinguishedName  : CN=Brian Williams,OU=Users,OU=Accounts,OU=Production,DC=ad,DC=evotec,DC=pl
            #>


            $QueryServer = $ForestInformation['QueryServers'][$Object.Domain].HostName[0]

            Write-Color -Text "[i] ", "Processing ", $Object.Name, " (" , "Domain: ", $Object.Domain, ", ObjectClass: ", $Object.ObjectClass, ", SIDHistoryCount: ", $Object.SIDHistory.Count, ", DN: ", $Object.DistinguishedName, ")" -Color Yellow, White, Green, White, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, White
            # if ($SkipPerObject -or (-not $SkipPerObject -and -not $SkipPerSID)) {
            #     if ($null -ne $RemoveLimitObject -and $GlobalLimitObject -ge $RemoveLimitObject) {
            #         break TopLoop
            #     }
            #     Write-Color -Text "[i] ", "Removing SIDHistory record (ALL) for ", $Object.Name, " (" , "Domain: ", $Object.Domain, ", ObjectClass: ", $Object.ObjectClass, ", SIDHistoryCount: ", $Object.SIDHistory.Count, ", DN: ", $Object.DistinguishedName, ")" -Color Yellow, White, Green, White, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, White
            #     Set-ADObject -Identity $Object.DistinguishedName -Clear SIDHistory -Server $QueryServer
            #     $GlobalLimitObject++
            # } elseif ($SkipPerSID) {
            #     foreach ($SID in $Object.SIDHistory) {
            #         if ($null -ne $RemoveLimit -and $GlobalLimit -ge $RemoveLimit) {
            #             break TopLoop
            #         }
            #         Write-Color -Text "[i] ", "Removing SIDHistory record $SID for ", $Object.Name, " (" , "Domain: ", $Object.Domain, ", ObjectClass: ", $Object.ObjectClass, ", SIDHistoryCount: ", $Object.SIDHistory.Count, ", DN: ", $Object.DistinguishedName, ") - SID: ", $SID -Color Yellow, White, Green, White, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, White
            #         Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer
            #         $GlobalLimit++
            #     }
            # }

            if ($IncludeSIDHistoryDomain -or $ExcludeSIDHistoryDomain -or $IncludeInternalOnly -or $IncludeExternalOnly) {


                foreach ($SID in $Object.SIDHistory) {
                    if ($null -ne $RemoveLimit -and $GlobalLimitSID -ge $RemoveLimit) {
                        break TopLoop
                    }
                    Write-Color -Text "[i] ", "Removing SIDHistory record $SID for ", $Object.Name, " (" , "Domain: ", $Object.Domain, ", ObjectClass: ", $Object.ObjectClass, ", SIDHistoryCount: ", $Object.SIDHistory.Count, ", DN: ", $Object.DistinguishedName, ") - SID: ", $SID -Color Yellow, White, Green, White, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, White
                    Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer
                    $GlobalLimit++
                }
            }

        }
    }
}