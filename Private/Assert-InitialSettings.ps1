function Assert-InitialSettings {
    [cmdletbinding()]
    param(
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $MoveOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf
    )

    $AzureRequired = $false
    $IntuneRequired = $false
    $JamfRequired = $false

    if ($DisableOnlyIf) {
        if ($null -ne $DisableOnlyIf.LastSyncAzureMoreThan -or $null -ne $DisableOnlyIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $DisableOnlyIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
        if ($null -ne $DisableOnlyIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
    }
    if ($MoveOnlyIf) {
        if ($null -ne $MoveOnlyIf.LastSyncAzureMoreThan -or $null -ne $MoveOnlyIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $MoveOnlyIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
        if ($null -ne $MoveOnlyIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
    }
    if ($DeleteOnlyIf) {
        if ($null -ne $DeleteOnlyIf.LastSyncAzureMoreThan -or $null -ne $DeleteOnlyIf.LastSeenAzureMoreThan) {
            $AzureRequired = $true
        }
        if ($null -ne $DeleteOnlyIf.LastContactJamfMoreThan) {
            $JamfRequired = $true
        }
        if ($null -ne $DeleteOnlyIf.LastSeenIntuneMoreThan) {
            $IntuneRequired = $true
        }
    }

    if ($AzureRequired -or $IntuneRequired) {
        $ModuleAvailable = Get-Module -Name GraphEssentials -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $ModuleAvailable) {
            Write-Color -Text "[e] ", "'GraphEssentials' module is required but not available. Terminating." -Color Yellow, Red
            return $false
        }
        $ModuleVersion = [version]'0.0.44'
        if ($ModuleAvailable.Version -lt $ModuleVersion) {
            Write-Color -Text "[e] ", "'GraphEssentials' module is outdated. Please update to the latest version minimum '$ModuleVersion'. Terminating." -Color Yellow, Red
            return $false
        }
    }
    if ($JamfRequired) {
        $ModuleAvailable = Get-Module -Name PowerJamf -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $ModuleAvailable) {
            Write-Color -Text "[e] ", "'PowerJamf' module is required but not available. Terminating." -Color Yellow, Red
            return $false
        }
        $ModuleVersion = [version]'0.3.1'
        if ($ModuleAvailable.Version -lt $ModuleVersion) {
            Write-Color -Text "[e] ", "'PowerJamf' module is outdated. Please update to the latest version minimum '$ModuleVersion'. Terminating." -Color Yellow, Red
            return $false
        }
    }
}