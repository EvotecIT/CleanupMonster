function Get-CloudDeviceJoinTypeFromRegistrationState {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $DeviceRegistrationState
    )

    if ([string]::IsNullOrWhiteSpace($DeviceRegistrationState)) {
        return 'Not available'
    }

    switch ($DeviceRegistrationState.ToLowerInvariant()) {
        'registered' { 'AzureAD registered'; break }
        'joined' { 'AzureAD joined'; break }
        default { 'Not available' }
    }
}
