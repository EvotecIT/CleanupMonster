function Get-CloudDevicePropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($propertyName in $Name) {
        if ($InputObject.PSObject.Properties[$propertyName]) {
            return $InputObject.$propertyName
        }
    }

    $null
}
