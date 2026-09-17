---
external help file: CleanupMonster-help.xml
Module Name: CleanupMonster
online version: https://github.com/EvotecIT/CleanupMonster
schema: 2.0.0
---
# Invoke-ADServiceAccountsCleanup
## SYNOPSIS
Cleans up stale Active Directory service accounts.

## SYNTAX
### __AllParameterSets
```powershell
Invoke-ADServiceAccountsCleanup [[-Forest] <string>] [[-IncludeDomains] <string[]>] [[-ExcludeDomains] <string[]>] [[-IncludeAccounts] <string[]>] [[-ExcludeAccounts] <string[]>] [[-DisableLastLogonDateMoreThan] <int>] [[-DisablePasswordLastSetMoreThan] <int>] [[-DisableWhenCreatedMoreThan] <int>] [[-DisableLimit] <int>] [[-DeleteLastLogonDateMoreThan] <int>] [[-DeletePasswordLastSetMoreThan] <int>] [[-DeleteWhenCreatedMoreThan] <int>] [[-DeleteLimit] <int>] [[-SafetyADLimit] <Int32>] [[-ReportPath] <string>] [[-LogPath] <string>] [[-LogMaximum] <int>] [[-LogTimeFormat] <string>] [-Disable] [-Delete] [-DisableTreatMissingLastLogonDateAsStale] [-DisableTreatMissingPasswordLastSetAsStale] [-DisableTreatMissingWhenCreatedAsStale] [-DisableNoPrincipalsAllowedToRetrieveManagedPassword] [-DeleteTreatMissingLastLogonDateAsStale] [-DeleteTreatMissingPasswordLastSetAsStale] [-DeleteTreatMissingWhenCreatedAsStale] [-DeleteNoPrincipalsAllowedToRetrieveManagedPassword] [-ReportOnly] [-ShowHTML] [-Online] [-WhatIfDisable] [-WhatIfDelete] [-DontWriteToEventLog] [-Suppress] [-LogShowTime] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Enumerates managed service accounts in Active Directory and disables or deletes
accounts based on inactivity or age criteria.
Disable and delete selections are staged so the same account is not actioned twice in one run.
The cmdlet also defaults to single-object safety limits unless you explicitly raise or remove them.

## EXAMPLES

### EXAMPLE 1
```powershell
PS > Invoke-ADServiceAccountsCleanup -Disable -DisableLastLogonDateMoreThan 90 -ReportOnly
```

Reports service accounts that would be disabled because they have not logged on for more than 90 days.

### EXAMPLE 2
```powershell
PS > Invoke-ADServiceAccountsCleanup -Delete -DeleteLastLogonDateMoreThan 180 -WhatIfDelete
```

Previews deletion of service accounts that have not logged on for more than 180 days.

### EXAMPLE 3
```powershell
PS > Invoke-ADServiceAccountsCleanup -Disable -Delete -DisableLastLogonDateMoreThan 90 -DeleteLastLogonDateMoreThan 180 -DisableLimit 2 -DeleteLimit 1 -SafetyADLimit 10 -WhatIfDisable -WhatIfDelete
```

Previews a staged disable/delete cleanup while limiting the number of accounts per action and requiring a minimum AD inventory count.

### EXAMPLE 4
```powershell
PS > $serviceAccounts = Invoke-ADServiceAccountsCleanup -Forest contoso.com -IncludeAccounts 'svc-*' -Disable -DisablePasswordLastSetMoreThan 120 -DisableLimit 5 -ReportPath C:\Reports\ServiceAccounts.html -ShowHTML
$serviceAccounts.CurrentRun | Format-Table SamAccountName, Action, ActionStatus
```

Disables up to five matching service accounts with old passwords, writes an HTML report, and returns the current run for review.

## PARAMETERS

### -Delete
Enable deletion of matching service accounts.

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

### -DeleteLastLogonDateMoreThan
Delete accounts that have not logged on for the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 9
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLimit
Limit the number of service accounts that will be deleted. 0 = unlimited. Default is 1.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 12
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteNoPrincipalsAllowedToRetrieveManagedPassword
Delete only gMSA accounts with no principals allowed to retrieve the managed password.

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

### -DeletePasswordLastSetMoreThan
Delete accounts where password has not been changed for the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 10
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteTreatMissingLastLogonDateAsStale
Treat accounts with missing LastLogonDate as matching DeleteLastLogonDateMoreThan.

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

### -DeleteTreatMissingPasswordLastSetAsStale
Treat accounts with missing PasswordLastSet as matching DeletePasswordLastSetMoreThan.

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

### -DeleteTreatMissingWhenCreatedAsStale
Treat accounts with missing WhenCreated as matching DeleteWhenCreatedMoreThan.

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

### -DeleteWhenCreatedMoreThan
Delete accounts created more than the specified number of days ago.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 11
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Disable
Enable disabling of matching service accounts.

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

### -DisableLastLogonDateMoreThan
Disable accounts that have not logged on for the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 5
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLimit
Limit the number of service accounts that will be disabled. 0 = unlimited. Default is 1.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 8
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableNoPrincipalsAllowedToRetrieveManagedPassword
Disable only gMSA accounts with no principals allowed to retrieve the managed password.

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

### -DisablePasswordLastSetMoreThan
Disable accounts where password has not been changed for the specified number of days.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 6
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableTreatMissingLastLogonDateAsStale
Treat accounts with missing LastLogonDate as matching DisableLastLogonDateMoreThan.

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

### -DisableTreatMissingPasswordLastSetAsStale
Treat accounts with missing PasswordLastSet as matching DisablePasswordLastSetMoreThan.

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

### -DisableTreatMissingWhenCreatedAsStale
Treat accounts with missing WhenCreated as matching DisableWhenCreatedMoreThan.

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

### -DisableWhenCreatedMoreThan
Disable accounts created more than the specified number of days ago.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 7
Default value: 0
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

### -ExcludeAccounts
Exclude service accounts that match these names (supports wildcards).

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

### -ExcludeDomains
List of domains to exclude from the process.

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

### -Forest
Forest to use when connecting to Active Directory.

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

### -IncludeAccounts
Include only service accounts that match these names (supports wildcards).

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

### -IncludeDomains
List of domains to include in the process.

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

### -LogMaximum
Maximum number of rotated log files to keep. Default is 5.

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
Path to a log file. When omitted, file logging is not enabled.

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
Includes timestamps in log output.

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
Date/time format used when LogShowTime is enabled.

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
Use online resources (CDN) for HTML report.

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

### -ReportOnly
Only report accounts that would be processed.

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
Path to save optional HTML report.

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

### -SafetyADLimit
Stops processing if the number of discovered service accounts is less than the specified limit.

```yaml
Type: Int32
Parameter Sets: __AllParameterSets
Aliases: None
Possible values:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowHTML
Show HTML report in a browser.

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
Suppresses returning the export object to the pipeline.

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

### -WhatIfDelete
Shows what would happen if accounts were deleted.

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

### -WhatIfDisable
Shows what would happen if accounts were disabled.

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
