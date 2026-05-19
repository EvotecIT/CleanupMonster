function Test-CloudDeviceRegistrationScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Device,

        [ValidateSet('Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', 'Not available')]
        [string[]] $IncludeJoinType = @('AzureAD registered')
    )

    if (-not $IncludeJoinType -or $IncludeJoinType.Count -eq 0) {
        return $false
    }

    if ($Device.PSObject.Properties['TrustType'] -and $Device.TrustType) {
        return $IncludeJoinType -contains $Device.TrustType
    }

    if ($Device.PSObject.Properties['DeviceRegistrationState']) {
        $joinType = Get-CloudDeviceJoinTypeFromRegistrationState -DeviceRegistrationState $Device.DeviceRegistrationState
        return $joinType -and $IncludeJoinType -contains $joinType
    }

    if ($Device.PSObject.Properties['IsSynchronized'] -and $Device.IsSynchronized -eq $true) {
        return $false
    }

    if ($Device.PSObject.Properties['AzureAdRegistered'] -and $Device.AzureAdRegistered -eq $false) {
        return $false
    }

    $false
}
