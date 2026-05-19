function Test-CloudDeviceInventoryScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $OperatingSystem,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $OperatingSystemVersion,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $IncludeOperatingSystem,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $ExcludeOperatingSystem,

        [AllowEmptyCollection()]
        [Array] $IncludeOperatingSystemVersion = @(),

        [AllowEmptyCollection()]
        [Array] $ExcludeOperatingSystemVersion = @(),

        [switch] $IncludeUnknownOperatingSystem,

        [switch] $IncludeUnknownOperatingSystemVersion,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $Exclusions,

        [string] $Name,
        [string] $DeviceId,
        [string] $EntraDeviceObjectId,
        [string] $ManagedDeviceId
    )

    if ([string]::IsNullOrWhiteSpace($OperatingSystem) -and -not $IncludeUnknownOperatingSystem) {
        if ($IncludeOperatingSystem.Count -gt 0) {
            return $false
        }
    }

    if ($IncludeOperatingSystem.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($OperatingSystem)) {
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

    if ([string]::IsNullOrWhiteSpace($OperatingSystemVersion) -and -not $IncludeUnknownOperatingSystemVersion) {
        if ($IncludeOperatingSystemVersion.Count -gt 0) {
            return $false
        }
    }

    if ($IncludeOperatingSystemVersion.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($OperatingSystemVersion)) {
        $includeVersionMatch = $false
        foreach ($includePattern in $IncludeOperatingSystemVersion) {
            if ($OperatingSystemVersion -like $includePattern) {
                $includeVersionMatch = $true
                break
            }
        }

        if (-not $includeVersionMatch) {
            return $false
        }
    }

    if ($ExcludeOperatingSystemVersion.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($OperatingSystemVersion)) {
        foreach ($excludePattern in $ExcludeOperatingSystemVersion) {
            if ($OperatingSystemVersion -like $excludePattern) {
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
