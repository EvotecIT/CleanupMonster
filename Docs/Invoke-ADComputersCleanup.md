---
external help file: CleanupActiveDirectory-help.xml
Module Name: CleanupActiveDirectory
online version:
schema: 2.0.0
---

# Invoke-ADComputersCleanup

## SYNOPSIS
{{ Fill in the Synopsis }}

## SYNTAX

```
Invoke-ADComputersCleanup [[-DisableIsEnabled] <Boolean>] [[-DisableNoServicePrincipalName] <Boolean>]
 [[-DisableLastLogonDateMoreThan] <Int32>] [[-DisablePasswordLastSetMoreThan] <Int32>]
 [[-DisableExcludeSystems] <Array>] [[-DisableIncludeSystems] <Array>] [[-DeleteIsEnabled] <Boolean>]
 [[-DeleteNoServicePrincipalName] <Boolean>] [[-DeleteLastLogonDateMoreThan] <Int32>]
 [[-DeletePasswordLastSetMoreThan] <Int32>] [[-DeleteListProcessedMoreThan] <Int32>]
 [[-DeleteExcludeSystems] <Array>] [[-DeleteIncludeSystems] <Array>] [[-DeleteLimit] <Int32>]
 [[-DisableLimit] <Int32>] [[-Exclusions] <Array>] [-DisableModifyDescription] [[-Filter] <String>]
 [[-ListProcessed] <String>] [-ReportOnly] [-WhatIfDelete] [-WhatIfDisable] [[-LogPath] <String>]
 [[-LogMaximum] <Int32>] [-Suppress] [-ShowHTML] [-Online] [[-ReportPath] <String>] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -DeleteExcludeSystems
{{ Fill DeleteExcludeSystems Description }}

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIncludeSystems
{{ Fill DeleteIncludeSystems Description }}

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteIsEnabled
{{ Fill DeleteIsEnabled Description }}

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLastLogonDateMoreThan
{{ Fill DeleteLastLogonDateMoreThan Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteLimit
{{ Fill DeleteLimit Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteListProcessedMoreThan
{{ Fill DeleteListProcessedMoreThan Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeleteNoServicePrincipalName
{{ Fill DeleteNoServicePrincipalName Description }}

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

### -DeletePasswordLastSetMoreThan
{{ Fill DeletePasswordLastSetMoreThan Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableExcludeSystems
{{ Fill DisableExcludeSystems Description }}

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIncludeSystems
{{ Fill DisableIncludeSystems Description }}

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableIsEnabled
{{ Fill DisableIsEnabled Description }}

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLastLogonDateMoreThan
{{ Fill DisableLastLogonDateMoreThan Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableLimit
{{ Fill DisableLimit Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableModifyDescription
{{ Fill DisableModifyDescription Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisableNoServicePrincipalName
{{ Fill DisableNoServicePrincipalName Description }}

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

### -DisablePasswordLastSetMoreThan
{{ Fill DisablePasswordLastSetMoreThan Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclusions
{{ Fill Exclusions Description }}

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: False
Position: 15
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Filter
{{ Fill Filter Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 16
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ListProcessed
{{ Fill ListProcessed Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 17
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogMaximum
{{ Fill LogMaximum Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 19
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
{{ Fill LogPath Description }}

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

### -Online
{{ Fill Online Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportOnly
{{ Fill ReportOnly Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportPath
{{ Fill ReportPath Description }}

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

### -ShowHTML
{{ Fill ShowHTML Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Suppress
{{ Fill Suppress Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDelete
{{ Fill WhatIfDelete Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIfDisable
{{ Fill WhatIfDisable Description }}

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
