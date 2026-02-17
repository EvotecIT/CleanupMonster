function Get-ADServiceAccountsToProcess {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)][ValidateSet('Disable','Delete')][string] $Type,
        [Array] $Accounts,
        [alias('DeleteOnlyIf','DisableOnlyIf')][System.Collections.IDictionary] $ActionIf,
        [Array] $Exclusions
    )
    Write-Color -Text "[i] ", "Applying following rules to $Type action: " -Color Yellow, Cyan, Green
    foreach ($Key in $ActionIf.Keys) {
        if ($null -eq $ActionIf[$Key]) {
            Write-Color -Text "   [>] ", $Key, " is ", 'Not Set' -Color Yellow, Cyan, Yellow
        } else {
            Write-Color -Text "   [>] ", $Key, " is ", $ActionIf[$Key] -Color Yellow, Cyan, Green
        }
    }
    Write-Color -Text "[i] ", "Looking for service accounts to $Type" -Color Yellow, Cyan, Green
    $Today = Get-Date
    [Array] $Output = foreach ($Account in $Accounts) {
        foreach ($Exclude in $Exclusions) {
            if ($Account.DistinguishedName -like $Exclude -or $Account.Name -like $Exclude) {
                continue 2
            }
        }
        $Include = $true
        if ($ActionIf.LastLogonDateMoreThan) {
            if ($Account.LastLogonDate) {
                $LastLogonDays = (New-TimeSpan -Start $Account.LastLogonDate -End $Today).Days
                $Account | Add-Member -NotePropertyName LastLogonDays -NotePropertyValue $LastLogonDays -Force
                if ($LastLogonDays -le $ActionIf.LastLogonDateMoreThan) { $Include = $false }
            }
        }
        if ($ActionIf.PasswordLastSetMoreThan) {
            if ($Account.PasswordLastSet) {
                $PasswordDays = (New-TimeSpan -Start $Account.PasswordLastSet -End $Today).Days
                $Account | Add-Member -NotePropertyName PasswordLastChangedDays -NotePropertyValue $PasswordDays -Force
                if ($PasswordDays -le $ActionIf.PasswordLastSetMoreThan) { $Include = $false }
            }
        }
        if ($ActionIf.WhenCreatedMoreThan) {
            if ($Account.WhenCreated) {
                $CreatedDays = (New-TimeSpan -Start $Account.WhenCreated -End $Today).Days
                $Account | Add-Member -NotePropertyName WhenCreatedDays -NotePropertyValue $CreatedDays -Force
                if ($CreatedDays -le $ActionIf.WhenCreatedMoreThan) { $Include = $false }
            }
        }
        if ($Include) {
            $Account | Add-Member -NotePropertyName Action -NotePropertyValue $Type -Force
            $Account
        }
    }
    $Output
}
