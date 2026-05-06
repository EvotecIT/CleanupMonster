function Get-ServiceAccountPrincipalCount {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)][object] $Account
    )

    $Property = $Account.PSObject.Properties['PrincipalsAllowedToRetrieveManagedPassword']
    if ($null -eq $Property) {
        return $null
    }
    if ($null -eq $Property.Value) {
        return 0
    }
    if ($Property.Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Property.Value)) {
            return 0
        }
        return 1
    }
    if ($Property.Value -is [System.Collections.IEnumerable]) {
        return @($Property.Value).Count
    }
    1
}

function Get-InitialADServiceAccounts {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $ForestInformation,
        [string[]] $IncludeAccounts,
        [string[]] $ExcludeAccounts
    )
    $Report = [ordered]@{}
    foreach ($Domain in $ForestInformation.Domains) {
        $Server = $ForestInformation['QueryServers'][$Domain].HostName[0]
        Write-Color -Text "[i] ", "Getting service accounts for domain ", $Domain, " from ", $Server -Color Yellow, Magenta, Yellow, Magenta
        $Accounts = Get-ADServiceAccount -Filter * -Server $Server -Properties SamAccountName,Enabled,LastLogonDate,PasswordLastSet,WhenCreated,DistinguishedName,ObjectClass,PrincipalsAllowedToRetrieveManagedPassword |
            Select-Object *, @{Name='PrincipalsAllowedToRetrieveManagedPasswordCount';Expression={ Get-ServiceAccountPrincipalCount -Account $_ }}, @{Name='DomainName';Expression={$Domain}}, @{Name='Server';Expression={$Server}}
        if ($IncludeAccounts) {
            $IncludePattern = [string]::Join('|', ($IncludeAccounts | ForEach-Object { [regex]::Escape($_).Replace('\*','.*') }))
            $Accounts = $Accounts | Where-Object { $_.SamAccountName -match "^($IncludePattern)$" }
        }
        if ($ExcludeAccounts) {
            $ExcludePattern = [string]::Join('|', ($ExcludeAccounts | ForEach-Object { [regex]::Escape($_).Replace('\*','.*') }))
            $Accounts = $Accounts | Where-Object { $_.SamAccountName -notmatch "^($ExcludePattern)$" }
        }
        $Report[$Domain] = [ordered]@{ Server = $Server; Accounts = @($Accounts) }
    }
    $Report
}
