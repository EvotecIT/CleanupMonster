function Get-CloudDeviceAuditContext {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [psobject] $Device)

    $value = {
        param([string] $Name, [string] $MissingRecord)

        $recordProperty = switch ($MissingRecord) {
            'No Entra record' { 'HasEntraRecord' }
            'No Intune record' { 'HasIntuneRecord' }
        }
        if ($MissingRecord -eq 'No Entra record' -and $Device.PSObject.Properties['RecordState'] -and $Device.RecordState -eq 'IntuneOnly') {
            if ($Device.PSObject.Properties['HasEntraRecord'] -and $Device.HasEntraRecord -eq $true) {
                return 'Entra details not captured'
            }
            return $MissingRecord
        }
        if ($recordProperty -and $Device.PSObject.Properties[$recordProperty] -and $Device.$recordProperty -eq $false) {
            return $MissingRecord
        }
        $property = $Device.PSObject.Properties[$Name]
        if (-not $property) { return 'Not captured' }
        $items = @($property.Value) | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string] $_) }
        if ($items.Count -eq 0) { return 'None' }
        ((@($items) | ForEach-Object { ([string] $_) -replace '[\r\n\t]+', ' ' }) -join ', ')
    }

    [pscustomobject] @{
        RegisteredOwner = & $value 'OwnerDisplayName' 'No Entra record'
        RegisteredOwnerUPN = & $value 'OwnerUserPrincipalName' 'No Entra record'
        IntuneUserUPN = & $value 'IntuneUserPrincipalName' 'No Intune record'
        EntraCompliant = & $value 'IsCompliant' 'No Entra record'
        IntuneCompliance = & $value 'ComplianceState' 'No Intune record'
        EntraManaged = & $value 'IsManaged' 'No Entra record'
        EntraManagementType = & $value 'ManagementType' 'No Entra record'
        MdmAppId = & $value 'MdmAppId' 'No Entra record'
        IntuneManagementAgent = & $value 'ManagementAgent' 'No Intune record'
    }
}
