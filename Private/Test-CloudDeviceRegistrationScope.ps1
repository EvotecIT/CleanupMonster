function Test-CloudDeviceRegistrationScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Device
    )

    if ($Device.PSObject.Properties['TrustType'] -and $Device.TrustType) {
        return $Device.TrustType -eq 'AzureAD registered'
    }

    if ($Device.PSObject.Properties['IsSynchronized'] -and $Device.IsSynchronized -eq $true) {
        return $false
    }

    if ($Device.PSObject.Properties['AzureAdRegistered'] -and $Device.AzureAdRegistered -eq $false) {
        return $false
    }

    $true
}
