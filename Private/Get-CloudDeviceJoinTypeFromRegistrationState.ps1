function Get-CloudDeviceJoinTypeFromRegistrationState {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $DeviceRegistrationState
    )

    if ([string]::IsNullOrWhiteSpace($DeviceRegistrationState)) {
        return $null
    }

    switch ($DeviceRegistrationState.ToLowerInvariant()) {
        'registered' { 'AzureAD registered'; break }
        'joined' { 'AzureAD joined'; break }
        default { 'Not available' }
    }
}
