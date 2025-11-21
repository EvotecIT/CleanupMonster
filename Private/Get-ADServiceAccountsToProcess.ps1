function Get-ADServiceAccountsToProcess {
    <#
    .SYNOPSIS
    Processes service accounts to determine which ones meet the criteria for action.

    .DESCRIPTION
    This function evaluates service accounts against specified criteria to determine
    which ones should be disabled or deleted.
    #>
    [CmdletBinding()]
    param(
        [Array] $ServiceAccounts,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [Array] $Exclusions,
        [System.Collections.IDictionary] $DomainInformation,
        [System.Collections.IDictionary] $ProcessedServiceAccounts,
        [string] $Type,
        [string[]] $IncludeOrganizationalUnit,
        [string[]] $ExcludeOrganizationalUnit
    )

    $Today = Get-Date
    $ActionIf = if ($Type -eq 'Disable') { $DisableOnlyIf } else { $DeleteOnlyIf }
    $ServiceAccountsToProcess = [System.Collections.Generic.List[PSCustomObject]]::new()

    :SkipServiceAccount foreach ($ServiceAccount in $ServiceAccounts) {
        if (-not $ServiceAccount) {
            continue SkipServiceAccount
        }

        # Add default action
        $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'Action' -Value $Type -Force
        $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'ActionComment' -Value '' -Force

        # Check exclusions first
        foreach ($Exclusion in $Exclusions) {
            if ($ServiceAccount.SamAccountName -like $Exclusion -or
                $ServiceAccount.DistinguishedName -like $Exclusion -or
                $ServiceAccount.Name -like $Exclusion) {
                $ServiceAccount.'Action' = 'ExcludedByFilter'
                continue SkipServiceAccount
            }
        }

        # Check OU inclusions/exclusions
        if ($IncludeOrganizationalUnit.Count -gt 0) {
            $FoundInclude = $false
            foreach ($Include in $IncludeOrganizationalUnit) {
                if ($ServiceAccount.DistinguishedName -like $Include) {
                    $FoundInclude = $true
                    break
                }
            }
            if (-not $FoundInclude) {
                $ServiceAccount.'Action' = 'ExcludedByFilter'
                continue SkipServiceAccount
            }
        }

        if ($ExcludeOrganizationalUnit.Count -gt 0) {
            foreach ($Exclude in $ExcludeOrganizationalUnit) {
                if ($ServiceAccount.DistinguishedName -like $Exclude) {
                    $ServiceAccount.'Action' = 'ExcludedByFilter'
                    continue SkipServiceAccount
                }
            }
        }

        # Check service account type filters
        if ($ActionIf.IncludeType.Count -gt 0) {
            if ($ServiceAccount.ServiceAccountType -notin $ActionIf.IncludeType) {
                $ServiceAccount.'Action' = 'ExcludedBySetting'
                continue SkipServiceAccount
            }
        }

        if ($ActionIf.ExcludeType.Count -gt 0) {
            if ($ServiceAccount.ServiceAccountType -in $ActionIf.ExcludeType) {
                $ServiceAccount.'Action' = 'ExcludedBySetting'
                continue SkipServiceAccount
            }
        }

        # Check name filters
        if ($ActionIf.ExcludeNames.Count -gt 0) {
            foreach ($ExcludeName in $ActionIf.ExcludeNames) {
                if ($ServiceAccount.Name -like $ExcludeName -or $ServiceAccount.SamAccountName -like $ExcludeName) {
                    $ServiceAccount.'Action' = 'ExcludedBySetting'
                    continue SkipServiceAccount
                }
            }
        }

        if ($ActionIf.IncludeNames.Count -gt 0) {
            $FoundInclude = $false
            foreach ($IncludeName in $ActionIf.IncludeNames) {
                if ($ServiceAccount.Name -like $IncludeName -or $ServiceAccount.SamAccountName -like $IncludeName) {
                    $FoundInclude = $true
                    break
                }
            }
            if (-not $FoundInclude) {
                $ServiceAccount.'Action' = 'ExcludedBySetting'
                continue SkipServiceAccount
            }
        }

        # Check creation date requirement
        if ($ActionIf.RequireWhenCreatedMoreThan) {
            if ($ServiceAccount.WhenCreated) {
                $TimeToCompare = ($ServiceAccount.WhenCreated).AddDays($ActionIf.RequireWhenCreatedMoreThan)
                if ($TimeToCompare -gt $Today) {
                    continue SkipServiceAccount
                }
            }
        }

        # Check enabled/disabled state
        if ($ActionIf.IsEnabled -eq $true) {
            if ($ServiceAccount.Enabled -eq $false) {
                continue SkipServiceAccount
            }
        } elseif ($ActionIf.IsEnabled -eq $false) {
            if ($ServiceAccount.Enabled -eq $true) {
                continue SkipServiceAccount
            }
        }

        # Check password last set criteria
        if ($ActionIf.PasswordLastSetMoreThan) {
            if ($ServiceAccount.PasswordLastSet) {
                $PasswordLastSetDays = - $($ServiceAccount.PasswordLastSet - $Today).Days
                $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'PasswordLastSetDays' -Value $PasswordLastSetDays -Force
                if ($PasswordLastSetDays -le $ActionIf.PasswordLastSetMoreThan) {
                    continue SkipServiceAccount
                }
            }
        }

        if ($ActionIf.PasswordLastSetOlderThan) {
            if ($ServiceAccount.PasswordLastSet) {
                if ($ActionIf.PasswordLastSetOlderThan -le $ServiceAccount.PasswordLastSet) {
                    continue SkipServiceAccount
                }
            }
        }

        # Check if service account is in processed list (for delete operations)
        if ($ActionIf.ListProcessedMoreThan -and $ProcessedServiceAccounts) {
            $DomainName = ConvertFrom-DistinguishedName -DistinguishedName $ServiceAccount.DistinguishedName -ToDomainCN
            $ServiceAccountFullName = -join ($ServiceAccount.SamAccountName, "@", $DomainName)

            if ($ProcessedServiceAccounts[$ServiceAccountFullName]) {
                $ProcessedServiceAccount = $ProcessedServiceAccounts[$ServiceAccountFullName]
                if ($ProcessedServiceAccount.ActionDate) {
                    $DaysOnList = - $($ProcessedServiceAccount.ActionDate - $Today).Days
                    $ServiceAccount | Add-Member -MemberType NoteProperty -Name 'TimeOnPendingList' -Value $DaysOnList -Force
                    if ($DaysOnList -le $ActionIf.ListProcessedMoreThan) {
                        $ServiceAccount.'Action' = 'Not required'
                        continue SkipServiceAccount
                    }
                } else {
                    $ServiceAccount.'Action' = 'Not required'
                    continue SkipServiceAccount
                }
            } else {
                $ServiceAccount.'Action' = 'Not required'
                continue SkipServiceAccount
            }
        }

        # If we get here, the service account meets all criteria
        $ServiceAccountsToProcess.Add($ServiceAccount)
    }

    $ServiceAccountsToProcess
}
