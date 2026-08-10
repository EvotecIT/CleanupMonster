function ConvertFrom-ADComputerInventoryRow {
    <#
    .SYNOPSIS
    Restores AD computer property types from the bounded child-process transport.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $InputObject
    )

    process {
        $ServicePrincipalNames = if ([string]::IsNullOrWhiteSpace($InputObject.ServicePrincipalNameJson) -or $InputObject.ServicePrincipalNameJson -eq 'null') {
            @()
        } else {
            @(ConvertFrom-Json -InputObject $InputObject.ServicePrincipalNameJson)
        }

        [PSCustomObject] @{
            Name                            = $InputObject.Name
            DNSHostName                     = $InputObject.DNSHostName
            SamAccountName                  = $InputObject.SamAccountName
            DistinguishedName               = $InputObject.DistinguishedName
            Enabled                         = if ($InputObject.Enabled) { [bool]::Parse($InputObject.Enabled) } else { $null }
            OperatingSystem                 = $InputObject.OperatingSystem
            OperatingSystemVersion          = $InputObject.OperatingSystemVersion
            LastLogonDate                   = if ($InputObject.LastLogonDateBinary) { [DateTime]::FromBinary([long] $InputObject.LastLogonDateBinary) } else { $null }
            PasswordLastSet                 = if ($InputObject.PasswordLastSetBinary) { [DateTime]::FromBinary([long] $InputObject.PasswordLastSetBinary) } else { $null }
            PasswordExpired                 = if ($InputObject.PasswordExpired) { [bool]::Parse($InputObject.PasswordExpired) } else { $null }
            servicePrincipalName            = $ServicePrincipalNames
            logonCount                      = if ($InputObject.LogonCount) { [int] $InputObject.LogonCount } else { $null }
            ManagedBy                       = $InputObject.ManagedBy
            Description                     = $InputObject.Description
            WhenCreated                     = if ($InputObject.WhenCreatedBinary) { [DateTime]::FromBinary([long] $InputObject.WhenCreatedBinary) } else { $null }
            WhenChanged                     = if ($InputObject.WhenChangedBinary) { [DateTime]::FromBinary([long] $InputObject.WhenChangedBinary) } else { $null }
            ProtectedFromAccidentalDeletion = if ($InputObject.ProtectedFromAccidentalDeletion) { [bool]::Parse($InputObject.ProtectedFromAccidentalDeletion) } else { $null }
        }
    }
}
