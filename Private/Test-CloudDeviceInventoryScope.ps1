function Test-CloudDeviceInventoryScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $OperatingSystem,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $IncludeOperatingSystem,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $ExcludeOperatingSystem,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $Exclusions,

        [string] $Name,
        [string] $DeviceId,
        [string] $EntraDeviceObjectId,
        [string] $ManagedDeviceId
    )

    if ($IncludeOperatingSystem.Count -gt 0) {
        $includeMatch = $false
        foreach ($includePattern in $IncludeOperatingSystem) {
            if ($OperatingSystem -like $includePattern) {
                $includeMatch = $true
                break
            }
        }

        if (-not $includeMatch) {
            return $false
        }
    }

    if ($ExcludeOperatingSystem.Count -gt 0) {
        foreach ($excludePattern in $ExcludeOperatingSystem) {
            if ($OperatingSystem -like $excludePattern) {
                return $false
            }
        }
    }

    foreach ($partialExclusion in $Exclusions) {
        if (($Name -and $Name -like $partialExclusion) -or
            ($DeviceId -and $DeviceId -like $partialExclusion) -or
            ($EntraDeviceObjectId -and $EntraDeviceObjectId -like $partialExclusion) -or
            ($ManagedDeviceId -and $ManagedDeviceId -like $partialExclusion)) {
            return $false
        }
    }

    $true
}
