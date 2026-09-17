---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version: https://github.com/EvotecIT/CleanupMonster
schema: 2.0.0
---
# Invoke-ADSIDHistoryCleanup
## SYNOPSIS
Cleans up SID history entries in Active Directory based on various filtering criteria.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-ADSIDHistoryCleanup [[-Forest] <string>] [[-IncludeDomains] <string[]>] [[-ExcludeDomains] <string[]>] [[-IncludeOrganizationalUnit] <string[]>] [[-ExcludeOrganizationalUnit] <string[]>] [[-IncludeObjectType] <string[]>] [[-ExcludeObjectType] <string[]>] [[-IncludeSIDHistoryDomain] <string[]>] [[-ExcludeSIDHistoryDomain] <string[]>] [[-RemoveLimitSID] <Int32>] [[-RemoveLimitObject] <Int32>] [[-IncludeType] <string[]>] [[-ExcludeType] <string[]>] [[-ReportPath] <string>] [[-DataStorePath] <string>] [[-LogPath] <string>] [[-LogMaximum] <int>] [[-LogTimeFormat] <string>] [[-SafetyADLimit] <Int32>] [-ReportOnly] [-LogShowTime] [-Suppress] [-ShowHTML] [-Online] [-DisabledOnly] [-DontWriteToEventLog] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function identifies and removes SID history entries from AD objects based on specified filters.
It can target internal domains (same forest), external domains (trusted), or unknown domains.
The function allows for detailed reporting before making any changes.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-ADSIDHistoryCleanup -Forest "contoso.com" -IncludeType "External" -ReportOnly -ReportPath "C:\Temp\SIDHistoryReport.html" -WhatIf
```

Generates a report of external SID history entries in the contoso.com forest without making any changes.

### EXAMPLE 2
```powershell
PS > Invoke-ADSIDHistoryCleanup -IncludeDomains "domain1.local" -IncludeType "Internal" -RemoveLimitSID 2 -WhatIf
```

Removes up to 2 internal SID history entries from objects in domain1.local.

### EXAMPLE 3
```powershell
PS > Invoke-ADSIDHistoryCleanup -ExcludeSIDHistoryDomain "S-1-5-21-1234567890-1234567890-1234567890" -WhatIf -RemoveLimitObject 2
```

Shows what SID history entries would be removed while excluding entries from the specified domain SID. Limits the number of objects to process to 2.

### EXAMPLE 4
```powershell
PS > # Prepare splat
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
```

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

## PARAMETERS

### -DataStorePath
Path to the XML file used to store processed SID history entries.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 14
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisabledOnly
Only processes objects that are disabled.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DontWriteToEventLog
Prevents writing cleanup events to the Windows event log.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeDomains
An array of domain names to exclude from the cleanup process.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeObjectType
An array of object classes to exclude (for example: User, Group, Computer).

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: User, Group, Computer, msDS-ManagedServiceAccount, msDS-GroupManagedServiceAccount, ForeignSecurityPrincipal, Contact, inetOrgPerson

Required: False
Position: 6
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeOrganizationalUnit
An array of organizational units to exclude from the cleanup process.
Supports wildcards using the -like operator. For example: "*OU=Test*"

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeSIDHistoryDomain
An array of domain SIDs to exclude when cleaning up SID history.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeType
Specifies which types of SID history to exclude: 'Internal', 'External', or 'Unknown'.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Internal, External, Unknown

Required: False
Position: 12
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Forest
The name of the forest to process. If not specified, uses the current forest.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeDomains
An array of domain names to include in the cleanup process.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: Domain
Possible values:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeObjectType
An array of object classes to include (for example: User, Group, Computer).

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: User, Group, Computer, msDS-ManagedServiceAccount, msDS-GroupManagedServiceAccount, ForeignSecurityPrincipal, Contact, inetOrgPerson

Required: False
Position: 5
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeOrganizationalUnit
An array of organizational units to include in the cleanup process.
Supports wildcards using the -like operator. For example: "*OU=Accounts,OU=Production*"

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeSIDHistoryDomain
An array of domain SIDs to include when cleaning up SID history.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeType
Specifies which types of SID history to include: 'Internal', 'External', or 'Unknown'.
Defaults to all three types if not specified.

```yaml
Type: String[]
Parameter Sets: __AllParameterSets
Aliases: None
Possible values: Internal, External, Unknown

Required: False
Position: 11
Default value: @('Internal', 'External', 'Unknown')
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogMaximum
The maximum number of log files to keep.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 16
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
The path to the log file to write.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 15
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogShowTime
If specified, includes the time in the log entries.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogTimeFormat
The format to use for the time in the log entries.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 17
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Online
If specified, uses online resources in HTML report (CSS/JS is loaded from CDN). Otherwise local resources are used (bigger HTML file).

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveLimitObject
Limits the total number of objects to process for SID history removal. Defaults to 1 to prevent accidental mass deletions.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 10
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveLimitSID
Limits the total number of SID history entries to remove.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportOnly
If specified, only generates a report without making any changes.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportPath
The path where the HTML report should be saved.

```yaml
Type: String
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SafetyADLimit
Stops processing if the number of objects with SID history in AD is less than the specified limit.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 18
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowHTML
If specified, shows the HTML report in the default browser.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Suppress
Suppresses the output of the function and only returns the summary information.

```yaml
Type: SwitchParameter
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

- `None`

## OUTPUTS

- `None`

## RELATED LINKS

- None
