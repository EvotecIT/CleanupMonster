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

    .PARAMETER RemoveLimitSID
    Limits the total number of SID history entries to remove.

    .PARAMETER RemoveLimitObject
    Limits the total number of objects to process for SID history removal.

    .PARAMETER IncludeType
    Specifies which types of SID history to include: 'Internal', 'External', or 'Unknown'.
    Defaults to all three types if not specified.

    .PARAMETER ExcludeType
    Specifies which types of SID history to exclude: 'Internal', 'External', or 'Unknown'.

    .PARAMETER DisabledOnly
    Only processes objects that are disabled.

    .PARAMETER DataStorePath
    Path to the XML file used to store processed SID history entries.

    .PARAMETER ReportOnly
    If specified, only generates a report without making any changes.

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
    Invoke-ADSIDHistoryCleanup -IncludeDomains "domain1.local" -IncludeType "Internal" -RemoveLimitSID 100

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
        [nullable[int]] $RemoveLimitSID,
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
        [switch] $DisabledOnly,
        [nullable[int]] $SafetyADLimit,
        [switch] $DontWriteToEventLog
    )

    if (-not $DataStorePath) {
        $DataStorePath = $($MyInvocation.PSScriptRoot) + '\ProcessedSIDHistory.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = $($MyInvocation.PSScriptRoot) + '\ProcessedSIDHistory.html'
    }

    # lets enable global logging
    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    $Export = [ordered] @{
        Date             = Get-Date
        Version          = Get-GitHubVersion -Cmdlet 'Invoke-ADComputersCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        ObjectsToProcess = $null
        CurrentRun       = $null
        History          = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    Write-Color '[i] ', "[CleanupMonster] ", 'Version', ' [Informative] ', $Export['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta
    Write-Color -Text "[i] ", "Started process of cleaning up SID History for AD Objects" -Color Yellow, White
    Write-Color -Text "[i] ", "Executed by: ", $Env:USERNAME, ' from domain ', $Env:USERDNSDOMAIN -Color Yellow, White, Green, White

    $Export = Import-SIDHistory -DataStorePath $DataStorePath -Export $Export

    # Determine if we're using limits
    if ($Null -eq $RemoveLimitSID -and $null -eq $RemoveLimitObject) {
        $LimitPerObject = $false
        $LimitPerSID = $false
    } elseif ($Null -eq $RemoveLimitSID) {
        $LimitPerObject = $true
        $LimitPerSID = $false
    } elseif ($Null -eq $RemoveLimitObject) {
        $LimitPerObject = $false
        $LimitPerSID = $true
    } else {
        $LimitPerObject = $true
        $LimitPerSID = $true
    }

    $Configuration = [ordered] @{
        Forest                    = $Forest
        IncludeDomains            = $IncludeDomains
        ExcludeDomains            = $ExcludeDomains
        IncludeOrganizationalUnit = $IncludeOrganizationalUnit
        ExcludeOrganizationalUnit = $ExcludeOrganizationalUnit
        IncludeSIDHistoryDomain   = $IncludeSIDHistoryDomain
        ExcludeSIDHistoryDomain   = $ExcludeSIDHistoryDomain
        RemoveLimitSID            = $RemoveLimitSID
        RemoveLimitObject         = $RemoveLimitObject
        IncludeType               = $IncludeType
        ExcludeType               = $ExcludeType
        LimitPerObject            = $LimitPerObject
        LimitPerSID               = $LimitPerSID
        SafetyADLimit             = $SafetyADLimit
        DisabledOnly              = $DisabledOnly
        LogPath                   = $LogPath
        LogMaximum                = $LogMaximum
        LogShowTime               = $LogShowTime
        LogTimeFormat             = $LogTimeFormat
        DontWriteToEventLog       = $DontWriteToEventLog
    }


    # Initialize collections to store objects for processing or reporting
    $ObjectsToProcess = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Get forest details using existing function
    $ForestInformation = Get-WinADForestDetails -Forest $Forest -IncludeDomains $IncludeDomains -ExcludeDomains $ExcludeDomains -PreferWritable

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

    $requestADSIDHistorySplat = @{
        DomainNames             = $DomainNames
        Output                  = $Output
        Export                  = $Export
        IncludeSIDHistoryDomain = $IncludeSIDHistoryDomain
        ExcludeSIDHistoryDomain = $ExcludeSIDHistoryDomain
        IncludeType             = $IncludeType
        ExcludeType             = $ExcludeType
        RemoveLimitObject       = $RemoveLimitObject
        LimitPerObject          = $LimitPerObject
        LimitPerSID             = $LimitPerSID
        ObjectsToProcess        = $ObjectsToProcess
        DisabledOnly            = $DisabledOnly
        ForestInformation       = $ForestInformation
    }

    Request-ADSIDHistory @requestADSIDHistorySplat

    if (-not $ReportOnly) {
        # Process the collected objects for SID removal
        Remove-ADSIDHistory -ObjectsToProcess $ObjectsToProcess -Export $Export -RemoveLimitSID $RemoveLimitSID
    }

    $Export['TotalObjectsFound'] = $ObjectsToProcess.Count
    $Export['TotalSIDsFound'] = ($ObjectsToProcess | ForEach-Object { $_.Object.SIDHistory.Count } | Measure-Object -Sum).Sum

    if (-not $ReportOnly) {
        try {
            $Export | Export-Clixml -LiteralPath $DataStorePath -Encoding Unicode -WhatIf:$false -ErrorAction Stop
        } catch {
            Write-Color -Text "[-] Exporting Processed List failed. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    }
    $Export['ObjectsToProcess'] = $ObjectsToProcess

    New-HTMLProcessedSIDHistory -Export $Export -FilePath $ReportPath -Output $Output -ForestInformation $ForestInformation -Online:$Online.IsPresent -HideHTML:(-not $ShowHTML.IsPresent) -LogPath $LogPath -Configuration $Configuration

    # Return summary information
    if (-not $Suppress) {
        $Export.EmailBody = New-EmailBodySIDHistory -Export $Export
        $Export
    }
}