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
        $LastLogonDays = $null
        $PasswordDays = $null
        $CreatedDays = $null
        foreach ($Exclude in $Exclusions) {
            if ($Account.DistinguishedName -like $Exclude -or $Account.Name -like $Exclude) {
                continue 2
            }
        }
        $Include = $true
        if ($ActionIf.LastLogonDateMoreThan) {
            if ($Account.LastLogonDate) {
                $LastLogonDays = (New-TimeSpan -Start $Account.LastLogonDate -End $Today).Days
                if ($LastLogonDays -le $ActionIf.LastLogonDateMoreThan) { $Include = $false }
            }
        }
        if ($ActionIf.PasswordLastSetMoreThan) {
            if ($Account.PasswordLastSet) {
                $PasswordDays = (New-TimeSpan -Start $Account.PasswordLastSet -End $Today).Days
                if ($PasswordDays -le $ActionIf.PasswordLastSetMoreThan) { $Include = $false }
            }
        }
        if ($ActionIf.WhenCreatedMoreThan) {
            if ($Account.WhenCreated) {
                $CreatedDays = (New-TimeSpan -Start $Account.WhenCreated -End $Today).Days
                if ($CreatedDays -le $ActionIf.WhenCreatedMoreThan) { $Include = $false }
            }
        }
        if ($Include) {
            $AccountData = [ordered] @{}
            foreach ($Property in $Account.PSObject.Properties) {
                $AccountData[$Property.Name] = $Property.Value
            }
            if ($null -ne $LastLogonDays) {
                $AccountData['LastLogonDays'] = $LastLogonDays
            }
            if ($null -ne $PasswordDays) {
                $AccountData['PasswordLastChangedDays'] = $PasswordDays
            }
            if ($null -ne $CreatedDays) {
                $AccountData['WhenCreatedDays'] = $CreatedDays
            }
            $AccountData['Action'] = $Type
            $AccountData['ActionStatus'] = $null
            $AccountData['ActionDate'] = $null
            $AccountData['ActionComment'] = $null
            [PSCustomObject] $AccountData
        }
    }
    $Output
}
