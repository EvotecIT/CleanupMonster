﻿function Invoke-ADSIDHistoryCleanup {
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
    Limits the total number of objects to process for SID history removal. Defaults to 1 to prevent accidental mass deletions.

    .PARAMETER IncludeType
    Specifies which types of SID history to include: 'Internal', 'External', or 'Unknown'.
    Defaults to all three types if not specified.

    .PARAMETER ExcludeType
    Specifies which types of SID history to exclude: 'Internal', 'External', or 'Unknown'.

    .PARAMETER DisabledOnly
    Only processes objects that are disabled.

    .PARAMETER SafetyADLimit
    Stops processing if the number of objects with SID history in AD is less than the specified limit.

    .PARAMETER LogPath
    The path to the log file to write.

    .PARAMETER LogMaximum
    The maximum number of log files to keep.

    .PARAMETER LogShowTime
    If specified, includes the time in the log entries.

    .PARAMETER LogTimeFormat
    The format to use for the time in the log entries.

    .PARAMETER Suppress
    Suppresses the output of the function and only returns the summary information.

    .PARAMETER ShowHTML
    If specified, shows the HTML report in the default browser.

    .PARAMETER Online
    If specified, uses online resources in HTML report (CSS/JS is loaded from CDN). Otherwise local resources are used (bigger HTML file).

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
    Invoke-ADSIDHistoryCleanup -Forest "contoso.com" -IncludeType "External" -ReportOnly -ReportPath "C:\Temp\SIDHistoryReport.html" -WhatIf

    Generates a report of external SID history entries in the contoso.com forest without making any changes.

    .EXAMPLE
    Invoke-ADSIDHistoryCleanup -IncludeDomains "domain1.local" -IncludeType "Internal" -RemoveLimitSID 2 -WhatIf

    Removes up to 2 internal SID history entries from objects in domain1.local.

    .EXAMPLE
    Invoke-ADSIDHistoryCleanup -ExcludeSIDHistoryDomain "S-1-5-21-1234567890-1234567890-1234567890" -WhatIf -RemoveLimitObject 2

    Shows what SID history entries would be removed while excluding entries from the specified domain SID. Limits the number of objects to process to 2.

    .EXAMPLE
    # Prepare splat
    $invokeADSIDHistoryCleanupSplat = @{
        Verbose                 = $true
        WhatIf                  = $true
        IncludeSIDHistoryDomain = @(
            'S-1-5-21-3661168273-3802070955-2987026695'
            'S-1-5-21-853615985-2870445339-3163598659'
        )
        IncludeType             = 'External'
        RemoveLimitSID          = 1
        RemoveLimitObject       = 2

        SafetyADLimit           = 1
        ShowHTML                = $true
        Online                  = $true
        DisabledOnly            = $true
        #ReportOnly              = $true
        LogPath                 = "C:\Temp\ProcessedSIDHistory.log"
        ReportPath              = "$PSScriptRoot\ProcessedSIDHistory.html"
        DataStorePath           = "$PSScriptRoot\ProcessedSIDHistory.xml"
    }

    # Run the script
    $Output = Invoke-ADSIDHistoryCleanup @invokeADSIDHistoryCleanupSplat
    $Output | Format-Table -AutoSize

    # Lets send an email
    $EmailBody = $Output.EmailBody

    Connect-MgGraph -Scopes 'Mail.Send' -NoWelcome
    Send-EmailMessage -To 'przemyslaw.klys@test.pl' -From 'przemyslaw.klys@test.pl' -MgGraphRequest -Subject "Automated SID Cleanup Report" -Body $EmailBody -Priority Low -Verbose
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
        [nullable[int]] $RemoveLimitObject = 1,
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