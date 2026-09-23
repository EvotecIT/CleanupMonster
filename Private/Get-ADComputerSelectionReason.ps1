function Get-ADComputerSelectionReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Computer,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ActionIf,
        [PSObject] $ProcessedComputer,
        [switch] $IncludeAzureAD,
        [switch] $IncludeIntune,
        [switch] $IncludeJamf,
        [datetime] $Today = (Get-Date)
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    foreach ($rule in @(
            @{ Name = 'LastLogonDateMoreThan'; Days = 'LastLogonDays'; Source = 'AD' },
            @{ Name = 'PasswordLastSetMoreThan'; Days = 'PasswordLastChangedDays'; Source = 'AD' },
            @{ Name = 'LastSeenAzureMoreThan'; Days = 'AzureLastSeenDays'; Source = 'Azure' },
            @{ Name = 'LastSyncAzureMoreThan'; Days = 'AzureLastSyncDays'; Source = 'Azure' },
            @{ Name = 'LastSeenIntuneMoreThan'; Days = 'IntuneLastSeenDays'; Source = 'Intune' },
            @{ Name = 'LastContactJamfMoreThan'; Days = 'JamfLastContactTimeDays'; Source = 'Jamf' }
        )) {
        $threshold = $ActionIf[$rule.Name]
        if ($null -eq $threshold -or
            ($rule.Source -eq 'AD' -and -not $threshold) -or
            ($rule.Source -eq 'Azure' -and -not $IncludeAzureAD) -or
            ($rule.Source -eq 'Intune' -and -not $IncludeIntune) -or
            ($rule.Source -eq 'Jamf' -and -not $IncludeJamf)) {
            continue
        }

        $days = $Computer.($rule.Days)
        if ($null -eq $days) {
            $reasons.Add("$($rule.Days)=Unknown allowed ($($rule.Name)=$threshold)")
        } else {
            $reasons.Add("$($rule.Days)=$days ($($rule.Name)=$threshold)")
        }
    }

    if ($ActionIf.RequireWhenCreatedMoreThan) {
        $createdDays = if ($Computer.WhenCreated) { (New-TimeSpan -Start $Computer.WhenCreated -End $Today).Days } else { $null }
        $reasons.Add("CreatedDays=$(if ($null -eq $createdDays) { 'Unknown allowed' } else { $createdDays }) (RequireWhenCreatedMoreThan=$($ActionIf.RequireWhenCreatedMoreThan))")
    }

    foreach ($rule in @(
            @{ Name = 'LastLogonDateOlderThan'; Date = 'LastLogonDate' },
            @{ Name = 'PasswordLastSetOlderThan'; Date = 'PasswordLastSet' }
        )) {
        $cutoff = $ActionIf[$rule.Name]
        if ($null -eq $cutoff) { continue }
        $value = if ($Computer.($rule.Date)) { ([datetime] $Computer.($rule.Date)).ToString('yyyy-MM-dd') } else { 'Unknown allowed' }
        $reasons.Add("$($rule.Date)=$value ($($rule.Name)=$cutoff)")
    }

    if ($null -ne $ActionIf.ListProcessedMoreThan -and $ProcessedComputer -and $ProcessedComputer.ActionDate) {
        $pendingDays = (New-TimeSpan -Start $ProcessedComputer.ActionDate -End $Today).Days
        $reasons.Add("PendingDays=$pendingDays (ListProcessedMoreThan=$($ActionIf.ListProcessedMoreThan))")
    }
    if ($null -ne $ActionIf.IsEnabled) {
        $reasons.Add("Enabled=$($Computer.Enabled) (IsEnabled=$($ActionIf.IsEnabled))")
    }
    if ($null -ne $ActionIf.NoServicePrincipalName) {
        $spnCount = if ($null -eq $Computer.ServicePrincipalName) { 0 } else { @($Computer.ServicePrincipalName).Count }
        $reasons.Add("ServicePrincipalNameCount=$spnCount (NoServicePrincipalName=$($ActionIf.NoServicePrincipalName))")
    }
    if ($ActionIf.IncludeSystems -and $ActionIf.IncludeSystems.Count -gt 0) {
        $reasons.Add("OperatingSystem=$($Computer.OperatingSystem) (IncludeSystems=$($ActionIf.IncludeSystems -join ','))")
    }
    if ($ActionIf.IncludeServicePrincipalName -and $ActionIf.IncludeServicePrincipalName.Count -gt 0) {
        foreach ($pattern in $ActionIf.IncludeServicePrincipalName) {
            $matchingSpn = @($Computer.ServicePrincipalName | Where-Object { $_ -like $pattern } | Select-Object -First 1)
            if ($matchingSpn.Count -gt 0) {
                $reasons.Add("ServicePrincipalName=$($matchingSpn[0]) (IncludeServicePrincipalName=$pattern)")
                break
            }
        }
    }

    if ($reasons.Count -eq 0) { return 'Matched configured AD cleanup rules' }
    $reasons -join '; '
}
