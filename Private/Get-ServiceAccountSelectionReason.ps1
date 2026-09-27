function Get-ServiceAccountSelectionReason {
    [CmdletBinding()]
    param([psobject] $Account, [System.Collections.IDictionary] $ActionIf)

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($rule in @(
        @{ Threshold='LastLogonDateMoreThan'; Age='LastLogonDays'; Missing='TreatMissingLastLogonDateAsStale' }
        @{ Threshold='PasswordLastSetMoreThan'; Age='PasswordLastChangedDays'; Missing='TreatMissingPasswordLastSetAsStale' }
        @{ Threshold='WhenCreatedMoreThan'; Age='WhenCreatedDays'; Missing='TreatMissingWhenCreatedAsStale' }
    )) {
        if ($ActionIf[$rule.Threshold]) {
            $age = $Account.($rule.Age)
            if ($null -ne $age) { $parts.Add("$($rule.Age)=$age ($($rule.Threshold)=$($ActionIf[$rule.Threshold]))") }
            else { $parts.Add("$($rule.Age)=unknown ($($rule.Missing)=$($ActionIf[$rule.Missing]))") }
        }
    }
    if ($ActionIf.NoPrincipalsAllowedToRetrieveManagedPassword) { $parts.Add('gMSA password retrieval principals=0 (required)') }
    if (-not $parts.Count) { $parts.Add('Selected by account scope; no age criterion configured') }
    $parts -join '; '
}
