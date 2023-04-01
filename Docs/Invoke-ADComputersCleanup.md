---
external help file: CleanupActiveDirectory-help.xml
Module Name: CleanupActiveDirectory
online version:
schema: 2.0.0
---

# Invoke-ADComputersCleanup

## SYNOPSIS
Active Directory Cleanup function that can disable or delete computers
that have not been logged on for a certain amount of time.

## SYNTAX

```
Invoke-ADComputersCleanup [-Disable] [-Delete] [[-DisableIsEnabled] <Boolean>]
 [[-DisableNoServicePrincipalName] <Boolean>] [[-DisableLastLogonDateMoreThan] <Int32>]
 [[-DisablePasswordLastSetMoreThan] <Int32>] [[-DisableExcludeSystems] <Array>]
 [[-DisableIncludeSystems] <Array>] [[-DeleteIsEnabled] <Boolean>] [[-DeleteNoServicePrincipalName] <Boolean>]
 [[-DeleteLastLogonDateMoreThan] <Int32>] [[-DeletePasswordLastSetMoreThan] <Int32>]
 [[-DeleteListProcessedMoreThan] <Int32>] [[-DeleteExcludeSystems] <Array>] [[-DeleteIncludeSystems] <Array>]
 [[-DeleteLimit] <Int32>] [[-DisableLimit] <Int32>] [[-Exclusions] <Array>] [-DisableModifyDescription]
 [-DisableModifyAdminDescription] [[-Filter] <String>] [[-DataStorePath] <String>] [-ReportOnly]
 [[-ReportMaximum] <Int32>] [-WhatIfDelete] [-WhatIfDisable] [[-LogPath] <String>] [[-LogMaximum] <Int32>]
 [-Suppress] [-ShowHTML] [-Online] [[-ReportPath] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Active Directory Cleanup function that can disable or delete computers
that have not been logged on for a certain amount of time.
It has many options to customize the cleanup process.

## EXAMPLES

### EXAMPLE 1
```
$Output = Invoke-ADComputersCleanup -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
```

$Output

### EXAMPLE 2
```
$Output = Invoke-ADComputersCleanup -DeleteListProcessedMoreThan 100 -Disable -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
```

$Output

### EXAMPLE 3
```
# this is a fresh run and it will provide report only according to it's defaults
```

$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
$Output

### EXAMPLE 4
```
# this is a fresh run and it will try to disable computers according to it's defaults
```

# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Disable -ShowHTML -WhatIfDisable -WhatIfDelete -Delete
$Output

### EXAMPLE 5
```
# this is a fresh run and it will try to delete computers according to it's defaults
```

# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output

### EXAMPLE 6
```
# Run the script
```

$Configuration = @{
    Disable                        = $true
    DisableNoServicePrincipalName  = $null
    DisableIsEnabled               = $true
    DisableLastLogonDateMoreThan   = 90
    DisablePasswordLastSetMoreThan = 90
    DisableExcludeSystems          = @(
        # 'Windows Server*'
    )
    DisableIncludeSystems          = @()
    DisableLimit                   = 2 # 0 means unlimited, ignored for reports
    DisableModifyDescription       = $false
    DisableAdminModifyDescription  = $true

    Delete                         = $true
    DeleteIsEnabled                = $false
    DeleteNoServicePrincipalName   = $null
    DeleteLastLogonDateMoreThan    = 180
    DeletePasswordLastSetMoreThan  = 180
    DeleteListProcessedMoreThan    = 90 # 90 days since computer was added to list
    DeleteExcludeSystems           = @(
        # 'Windows Server*'
    )
    DeleteIncludeSystems           = @(

    )
    DeleteLimit                    = 2 # 0 means unlimited, ignored for reports

    Exclusions                     = @(
        '*OU=Domain Controllers*'
        '*OU=Servers,OU=Production*'
        'EVOMONSTER$'
        'EVOMONSTER.AD.EVOTEC.XYZ'
    )

    Filter                         = '*'
    WhatIfDisable                  = $true
    WhatIfDelete                   = $true
    LogPath                        = "$PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                  = "$PSScriptRoot\DeleteComputers_ListProcessed.xml"
    ReportPath                     = "$PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                       = $true
}

# Run one time as admin: Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers'
$Output = Invoke-ADComputersCleanup @Configuration
$Output

## PARAMETERS

### -Disable
Enable the disable process, meaning the computers that meet the criteria will be disabled.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Delete
Enable the delete process, meaning the computers that meet the criteria will be deleted.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIsEnabled
Disable computer only if it's Enabled or only if it's Disabled.
By default it will try to disable all computers that are either disabled or enabled.
While counter-intuitive for already disabled computers,
this is useful if you want preproceess computers for deletion and need to get them on the list.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableNoServicePrincipalName
Disable computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
By default it doesn't care if it has a ServicePrincipalName or not.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastLogonDateMoreThan
Disable computer only if it has a LastLogonDate that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisablePasswordLastSetMoreThan
Disable computer only if it has a PasswordLastSet that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableExcludeSystems
Disable computer only if it's not on the list of excluded operating systems.
If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*' or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.
It's using OperatingSystem property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIncludeSystems
Disable computer only if it's on the list of included operating systems.
If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIsEnabled
Delete computer only if it's Enabled or only if it's Disabled.
By default it will try to delete all computers that are either disabled or enabled.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteNoServicePrincipalName
Delete computer only if it has a ServicePrincipalName or only if it doesn't have a ServicePrincipalName.
By default it doesn't care if it has a ServicePrincipalName or not.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastLogonDateMoreThan
Delete computer only if it has a LastLogonDate that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeletePasswordLastSetMoreThan
Delete computer only if it has a PasswordLastSet that is more than the specified number of days.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: 180
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteListProcessedMoreThan
Delete computer only if it has been processed by this script more than the specified number of days ago.
This is useful if you want to delete computers that have been disabled for a certain amount of time.
It uses XML file to store the list of processed computers, so please make sure to not remove it or it will start over.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteExcludeSystems
Delete computer only if it's not on the list of excluded operating systems.
If you want to exclude Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.
It's using OperatingSystem property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIncludeSystems
Delete computer only if it's on the list of included operating systems.
If you want to include Windows 10, you can specify 'Windows 10' or 'Windows 10*'
or 'Windows 10*' or '*Windows 10*' or '*Windows 10*'.
You can also specify multiple operating systems by separating them with a comma.
It's using the -like operator, so you can use wildcards.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 13
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLimit
Limit the number of computers that will be deleted.
0 = unlimited.
Default is 1.
This is to prevent accidental deletion of all computers that meet the criteria.
Adjust the limit to your needs.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLimit
Limit the number of computers that will be disabled.
0 = unlimited.
Default is 1.
This is to prevent accidental disabling of all computers that meet the criteria.
Adjust the limit to your needs.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 15
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclusions
List of computers to exclude from the process.
You can specify multiple computers by separating them with a comma.
It's using the -like operator, so you can use wildcards.
You can use SamAccoutName (remember about ending $), DistinguishedName,
or DNSHostName property of the computer object for comparison.

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 16
Default value: @(
            # default exclusions
            '*OU=Domain Controllers*'
        )
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableModifyDescription
Modify the description of the computer object to include the date and time when it was disabled.
By default it will not modify the description.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableModifyAdminDescription
Modify the admin description of the computer object to include the date and time when it was disabled.
By default it will not modify the admin description.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Filter
Filter to use when searching for computers in Get-ADComputer cmdlet.
Default is '*'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 17
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -DataStorePath
Path to the XML file that will be used to store the list of processed computers, current run, and history data.
Default is $PSScriptRoot\ProcessedComputers.xml

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 18
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportOnly
Only generate the report, don't disable or delete computers.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportMaximum
Maximum number of reports to keep.
Default is Unlimited (0).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 19
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDelete
WhatIf parameter for the Delete process.
It's not nessessary to specify this parameter if you use WhatIf parameter which applies to both processes.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDisable
WhatIf parameter for the Disable process.
It's not nessessary to specify this parameter if you use WhatIf parameter which applies to both processes.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
Path to the log file.
Default is no logging to file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 20
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogMaximum
Maximum number of log files to keep.
Default is 5.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 21
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -Suppress
Suppress output of the object and only display to console

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowHTML
Show HTML report in the browser once the function is complete

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Online
Online parameter causes HTML report to use CDN for CSS and JS files.
This can be useful to minimize the size of the HTML report.
Otherwise the report will start with at least 2MB in size.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportPath
Path to the HTML report file.
Default is $PSScriptRoot\ProcessedComputers.html

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 22
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
General notes

## RELATED LINKS
