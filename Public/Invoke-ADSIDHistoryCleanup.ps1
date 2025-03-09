function Invoke-ADSIDHistoryCleanup {
    <#
    .SYNOPSIS
    Cleans up SID history entries in Active Directory based on various filtering criteria.

    .DESCRIPTION
    This function identifies and removes SID history entries from AD objects based on specified filters.
    It can target internal domains (same forest), external domains (trusted), or unknown domains.
    The function allows for detailed reporting before making any changes.

    .PARAMETER Forest
    The name of the forest to process. If not specified, uses the current forest.

    .PARAMETER IncludeDomains
    An array of domain names to include in the cleanup process.

    .PARAMETER ExcludeDomains
    An array of domain names to exclude from the cleanup process.

    .PARAMETER IncludeOrganizationalUnit
    An array of organizational units to include in the cleanup process.

    .PARAMETER ExcludeOrganizationalUnit
    An array of organizational units to exclude from the cleanup process.

    .PARAMETER IncludeSIDHistoryDomain
    An array of domain SIDs to include when cleaning up SID history.

    .PARAMETER ExcludeSIDHistoryDomain
    An array of domain SIDs to exclude when cleaning up SID history.

    .PARAMETER RemoveLimit
    Limits the total number of SID history entries to remove.

    .PARAMETER RemoveLimitObject
    Limits the total number of objects to process for SID history removal.

    .PARAMETER IncludeType
    Specifies which types of SID history to include: 'Internal', 'External', or 'Unknown'.
    Defaults to all three types if not specified.

    .PARAMETER ExcludeType
    Specifies which types of SID history to exclude: 'Internal', 'External', or 'Unknown'.

    .PARAMETER Report
    Generates a report of affected objects without making any changes.

    .PARAMETER ReportPath
    The path where the HTML report should be saved. Used with the -Report parameter.

    .PARAMETER WhatIf
    Shows what would happen if the function runs. The SID history entries aren't actually removed.

    .EXAMPLE
    Invoke-ADSIDHistoryCleanup -Forest "contoso.com" -IncludeType "External" -Report -ReportPath "C:\Temp\SIDHistoryReport.html"

    Generates a report of external SID history entries in the contoso.com forest without making any changes.

    .EXAMPLE
    Invoke-ADSIDHistoryCleanup -IncludeDomains "domain1.local" -IncludeType "Internal" -RemoveLimit 100

    Removes up to 100 internal SID history entries from objects in domain1.local.

    .EXAMPLE
    Invoke-ADSIDHistoryCleanup -ExcludeSIDHistoryDomain "S-1-5-21-1234567890-1234567890-1234567890" -WhatIf

    Shows what SID history entries would be removed while excluding entries from the specified domain SID.
    #>
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
        [ValidateSet('Internal', 'External', 'Unknown')][string[]] $ExcludeType = @(),
        [string] $ReportPath,
        [string] $DataStorePath,
        [switch] $ReportOnly,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $LogShowTime,
        [string] $LogTimeFormat,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,

        [nullable[int]] $SafetyADLimit,
        [switch] $DontWriteToEventLog
    )

    if (-not $DataStorePath) {
        $DataStorePath = $($MyInvocation.PSScriptRoot) + '\ProcessedSIDHistory.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = $($MyInvocation.PSScriptRoot) + '\ProcessedSIDHistory.html'
    }

    $ProcessedSIDs = 0
    $ProcessedObjects = 0

    # lets enable global logging
    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    $Export = [ordered] @{
        Date       = Get-Date
        Version    = Get-GitHubVersion -Cmdlet 'Invoke-ADComputersCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun = $null
        History    = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    Write-Color '[i] ', "[CleanupMonster] ", 'Version', ' [Informative] ', $Export['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta
    Write-Color -Text "[i] ", "Started process of cleaning up SID History for AD Objects" -Color Yellow, White
    Write-Color -Text "[i] ", "Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Yellow, White, Green, White

    $Export = Import-SIDHistory -DataStorePath $DataStorePath -Export $Export

    # Initialize counters for tracking changes
    $GlobalLimitSID = 0
    $GlobalLimitObject = 0

    # Determine if we're using limits
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

    # Initialize collections to store objects for processing or reporting
    $ObjectsToProcess = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Get forest details using existing function
    $ForestInformation = Get-WinADForestDetails -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains

    # Get SID history information
    $Output = Get-WinADSIDHistory -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains -All

    if ($SafetyADLimit -and $Output.All.Count -le $SafetyADLimit) {
        Write-Color -Text "[i] ", "Number of objects returned with SIDHistory in AD is less than SafetyADLimit ", $SafetyADLimit, ". Stopping processing." -Color Yellow, White, Green, White
        return
    }

    # Extract domain names from the output
    [Array] $DomainNames = foreach ($Key in $Output.Keys) {
        if ($Key -in @('Statistics', 'Trusts', 'DomainSIDs', 'DuplicateSIDs', 'All')) {
            continue
        }
        $Key
    }

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

            # Check if we need to filter by OU
            if ($IncludeOrganizationalUnit -and $IncludeOrganizationalUnit -notcontains $Object.OrganizationalUnit) {
                continue
            }

            if ($ExcludeOrganizationalUnit -and $ExcludeOrganizationalUnit -contains $Object.OrganizationalUnit) {
                continue
            }

            Write-Color -Text "[i] ", "Processing ", $Object.Name, " (", $Object.ObjectClass, " in ", $Object.Domain, ", SID History Count: ", $Object.SIDHistory.Count, ")" -Color Yellow, White, Green, White, Green, White, Green, White, Green

            # Add to our collection of objects to process
            $ObjectsToProcess.Add(
                [PSCustomObject]@{
                    Object      = $Object
                    QueryServer = $QueryServer
                    Domain      = $Domain
                    DomainInfo  = $DomainInfo
                    DomainType  = $DomainType
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

    if (-not $ReportOnly) {
        # Process the collected objects for SID removal
        foreach ($Item in $ObjectsToProcess) {
            $Object = $Item.Object
            $QueryServer = $Item.QueryServer

            if ($LimitPerSID) {
                # Process individual SIDs for this object
                foreach ($SID in $Object.SIDHistory) {
                    if ($GlobalLimitSID -ge $RemoveLimit) {
                        Write-Color -Text "[i] ", "Reached SID limit of ", $RemoveLimit, ". Stopping processing." -Color Yellow, White, Green, White
                        break
                    }

                    if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove SID History entry $SID")) {
                        Write-Color -Text "[i] ", "Removing SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                        #Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer
                        $GlobalLimitSID++
                        $ProcessedSIDs++
                    }
                }
            } else {
                # Process all SIDs for this object at once
                if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove all SID History entries")) {
                    Write-Color -Text "[i] ", "Removing all SID History entries from ", $Object.Name -Color Yellow, White, Green
                    #Set-ADObject -Identity $Object.DistinguishedName -Clear SIDHistory -Server $QueryServer
                    $ProcessedSIDs += $Object.SIDHistory.Count
                    $ProcessedObjects++
                }
            }
        }

    }

    $Export['ProcessedObjects'] = $ProcessedObjects
    $Export['ProcessedSIDs'] = $ProcessedSIDs
    $Export['TotalObjectsFound'] = $ObjectsToProcess.Count
    $Export['TotalSIDsFound'] = ($ObjectsToProcess | ForEach-Object { $_.Object.SIDHistory.Count } | Measure-Object -Sum).Sum

    if (-not $ReportOnly) {
        try {
            $Export | Export-Clixml -LiteralPath $DataStorePath -Encoding Unicode -WhatIf:$false -ErrorAction Stop
        } catch {
            Write-Color -Text "[-] Exporting Processed List failed. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    }

    $Export['CurrentRun'] = $ObjectsToProcess

    New-HTMLProcessedSIDHistory -Export $Export -FilePath $ReportPath -Output $Output -ForestInformation $ForestInformation -Online:$Online.IsPresent -HideHTML:(-not $ShowHTML.IsPresent)

    # Return summary information
    if (-not $Suppress) {
        $Export.EmailBody = New-EmailBodySIDHistory -Export $Export
        $Export
    }
}