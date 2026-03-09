function Request-ADSIDHistory {
    [CmdletBinding()]
    param(
        [Array] $DomainNames,
        [System.Collections.IDictionary] $Output,
        [System.Collections.IDictionary] $Export,
        [System.Collections.IDictionary] $ForestInformation,
        [string[]] $IncludeOrganizationalUnit,
        [string[]] $ExcludeOrganizationalUnit,
        [ValidateSet('User', 'Group', 'Computer', 'msDS-ManagedServiceAccount', 'msDS-GroupManagedServiceAccount', 'ForeignSecurityPrincipal', 'Contact', 'inetOrgPerson')][string[]] $IncludeObjectType = @(),
        [ValidateSet('User', 'Group', 'Computer', 'msDS-ManagedServiceAccount', 'msDS-GroupManagedServiceAccount', 'ForeignSecurityPrincipal', 'Contact', 'inetOrgPerson')][string[]] $ExcludeObjectType = @(),
        [string[]] $IncludeSIDHistoryDomain,
        [string[]] $ExcludeSIDHistoryDomain,
        [nullable[int]] $RemoveLimitObject,
        [ValidateSet('Internal', 'External', 'Unknown')][string[]] $IncludeType,
        [ValidateSet('Internal', 'External', 'Unknown')][string[]] $ExcludeType,
        [switch] $DisabledOnly,
        [switch] $DontWriteToEventLog,
        [bool] $LimitPerObject,
        [bool] $LimitPerSID,
        [System.Collections.Generic.List[PSCustomObject]] $ObjectsToProcess
    )
    $GlobalLimitObject = 0

    # Process each domain SID
    :TopLoop foreach ($Domain in $DomainNames) {
        [Array] $Objects = $Output[$Domain]

        # Skip if we've already hit our object limit
        if ($LimitPerObject -and $GlobalLimitObject -ge $RemoveLimitObject) {
            Write-Color -Text "[i] ", "Reached object limit of ", $RemoveLimitObject, ". Stopping processing." -Color Yellow, White, Green, White
            break TopLoop
        }

        # Check if this domain SID matches our type filters
        $DomainInfo = $Output.DomainSIDs[$Domain]

        if (-not $DomainInfo) {
            $DomainType = "Unknown"
        } else {
            $DomainType = $DomainInfo.Type
            if ($DomainType -eq 'Domain') {
                $DomainType = "Internal"
            } elseif ($DomainType -eq 'Trust') {
                $DomainType = "External"
            }
        }

        # Apply type filters
        if ($ExcludeType.Count -gt 0 -and $ExcludeType -contains $DomainType) {
            Write-Color -Text "[s] ", "Skipping ", $Domain, " as it's type ", $DomainType, " is excluded." -Color Yellow, White, Red, White, Red, White
            continue
        }

        if ($IncludeType.Count -gt 0 -and $IncludeType -notcontains $DomainType) {
            Write-Color -Text "[s] ", "Skipping ", $Domain, " as it's type ", $DomainType, " is not included." -Color Yellow, White, Red, White, Red, White
            continue
        }

        # Apply SID domain filters
        if ($IncludeSIDHistoryDomain -and $IncludeSIDHistoryDomain -notcontains $Domain) {
            Write-Color -Text "[s] ", "Skipping ", $Domain, " as it's not in the included SID history domains." -Color Yellow, White, Red, White
            continue
        }

        if ($ExcludeSIDHistoryDomain -and $ExcludeSIDHistoryDomain -contains $Domain) {
            Write-Color -Text "[s] ", "Skipping ", $Domain, " as it's in the excluded SID history domains." -Color Yellow, White, Red, White
            continue
        }

        # Display which domain we're processing
        $DomainDisplayName = if ($DomainInfo) { $DomainInfo.Domain } else { "Unknown" }
        Write-Color -Text "[i] ", "Processing domain SID ", $Domain, " (", $DomainDisplayName, " - ", $DomainType, ")" -Color Yellow, White, Green, White, Green, White, Green

        # Process each object in this domain
        foreach ($Object in $Objects) {
            $QueryServer = $ForestInformation['QueryServers'][$Object.Domain].HostName[0]

            if ($DisabledOnly) {
                if ($Object.Enabled) {
                    Write-Color -Text "[s] ", "Skipping ", $Object.Name, " as it is enabled and DisabledOnly filter is set." -Color Yellow, White, Red, White
                    continue
                }
            }

            # Apply object type filters
            if ($IncludeObjectType.Count -gt 0 -and $IncludeObjectType -notcontains $Object.ObjectClass) {
                Write-Color -Text "[s] ", "Skipping ", $Object.Name, " as its type ", $Object.ObjectClass, " is not in the included object types." -Color Yellow, White, Red, White, Red, White
                continue
            }

            if ($ExcludeObjectType.Count -gt 0 -and $ExcludeObjectType -contains $Object.ObjectClass) {
                Write-Color -Text "[s] ", "Skipping ", $Object.Name, " as its type ", $Object.ObjectClass, " is in the excluded object types." -Color Yellow, White, Red, White, Red, White
                continue
            }

            # Check if we need to filter by OU
            if ($IncludeOrganizationalUnit) {
                $IncludeMatch = $false
                foreach ($IncludePattern in $IncludeOrganizationalUnit) {
                    if ($Object.OrganizationalUnit -like $IncludePattern) {
                        $IncludeMatch = $true
                        break
                    }
                }
                if (-not $IncludeMatch) {
                    continue
                }
            }

            if ($ExcludeOrganizationalUnit) {
                $ExcludeMatch = $false
                foreach ($ExcludePattern in $ExcludeOrganizationalUnit) {
                    if ($Object.OrganizationalUnit -like $ExcludePattern) {
                        $ExcludeMatch = $true
                        break
                    }
                }
                if ($ExcludeMatch) {
                    continue
                }
            }

            Write-Color -Text "[i] ", "Processing ", $Object.Name, " (", $Object.ObjectClass, " in ", $Object.Domain, ", SID History Count: ", $Object.SIDHistory.Count, ")" -Color Yellow, White, Green, White, Green, White, Green, White, Green

            # Filter SIDHistory values so we only remove entries belonging to the currently processed SID history domain.
            # This prevents removing SIDHistory entries from other domains on the same object.
            [Array] $SIDHistoryToRemove = foreach ($SID in $Object.SIDHistory) {
                if ($SID -eq $Domain -or $SID -like "$Domain-*") {
                    $SID
                }
            }

            if (-not $SIDHistoryToRemove -or $SIDHistoryToRemove.Count -eq 0) {
                Write-Color -Text "[s] ", "Skipping ", $Object.Name, " as it has no SID history entries matching domain SID ", $Domain -Color Yellow, White, Red, White, Red
                continue
            }

            # Add to our collection of objects to process
            $ObjectsToProcess.Add(
                [PSCustomObject]@{
                    Object      = $Object
                    QueryServer = $QueryServer
                    Domain      = $Domain
                    DomainInfo  = $DomainInfo
                    DomainType  = $DomainType
                    SIDHistoryToRemove = $SIDHistoryToRemove
                }
            )

            # Increment counter and check limits
            $GlobalLimitObject++
            if ($LimitPerObject -and $GlobalLimitObject -ge $RemoveLimitObject) {
                Write-Color -Text "[i] ", "Reached object limit of ", $RemoveLimitObject, ". Stopping object collection." -Color Yellow, White, Green, White
                break TopLoop
            }
        }
    }
}
