function Get-CloudDeviceRecordKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Device
    )

    @(Get-CloudDeviceRecordKeys -Device $Device)[0]
}
