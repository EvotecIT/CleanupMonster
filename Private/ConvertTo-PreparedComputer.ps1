function ConvertTo-PreparedComputer {
    [CmdletBinding()]
    param(
        [Microsoft.ActiveDirectory.Management.ADComputer[]] $Computers,
        [System.Collections.IDictionary] $AzureInformationCache,
        [System.Collections.IDictionary] $JamfInformationCache,
        [switch] $IncludeAzureAD,
        [switch] $IncludeIntune,
        [switch] $IncludeJamf
    )

    foreach ($Computer in $Computers) {
        if ($IncludeAzureAD) {
            $AzureADComputer = $AzureInformationCache['AzureAD']["$($Computer.Name)"]
            $DataAzureAD = [ordered] @{
                'AzureLastSeen'     = $AzureADComputer.LastSeen
                'AzureLastSeenDays' = $AzureADComputer.LastSeenDays
                'AzureLastSync'     = $AzureADComputer.LastSynchronized
                'AzureLastSyncDays' = $AzureADComputer.LastSynchronizedDays
                'AzureOwner'        = $AzureADComputer.OwnerDisplayName
                'AzureOwnerStatus'  = $AzureADComputer.OwnerEnabled
                'AzureOwnerUPN'     = $AzureADComputer.OwnerUserPrincipalName
            }
        }
        if ($IncludeIntune) {
            # data was requested from Intune
            $IntuneComputer = $AzureInformationCache['Intune']["$($Computer.Name)"]
            $DataIntune = [ordered] @{
                'IntuneLastSeen'     = $IntuneComputer.LastSeen
                'IntuneLastSeenDays' = $IntuneComputer.LastSeenDays
                'IntuneUser'         = $IntuneComputer.UserDisplayName
                'IntuneUserUPN'      = $IntuneComputer.UserPrincipalName
                'IntuneUserEmail'    = $IntuneComputer.EmailAddress
            }
        }
        if ($IncludeJamf) {
            $JamfComputer = $JamfInformationCache["$($Computer.Name)"]
            $DataJamf = [ordered] @{
                JamfLastContactTime     = $JamfComputer.lastContactTime
                JamfLastContactTimeDays = $JamfComputer.lastContactTimeDays
                JamfCapableUsers        = $JamfComputer.mdmCapableCapableUsers
            }
        }

        $DataStart = [ordered] @{
            'DNSHostName'             = $Computer.DNSHostName
            'SamAccountName'          = $Computer.SamAccountName
            'Enabled'                 = $Computer.Enabled
            'Action'                  = 'Not required'
            'ActionStatus'            = $null
            'ActionDate'              = $null
            'ActionComment'           = $null
            'OperatingSystem'         = $Computer.OperatingSystem
            'OperatingSystemVersion'  = $Computer.OperatingSystemVersion
            'OperatingSystemLong'     = ConvertTo-OperatingSystem -OperatingSystem $Computer.OperatingSystem -OperatingSystemVersion $Computer.OperatingSystemVersion
            'LastLogonDate'           = $Computer.LastLogonDate
            'LastLogonDays'           = ([int] $(if ($null -ne $Computer.LastLogonDate) { "$(-$($Computer.LastLogonDate - $Today).Days)" } else { }))
            'PasswordLastSet'         = $Computer.PasswordLastSet
            'PasswordLastChangedDays' = ([int] $(if ($null -ne $Computer.PasswordLastSet) { "$(-$($Computer.PasswordLastSet - $Today).Days)" } else { }))
        }
        $DataEnd = [ordered] @{
            'PasswordExpired'      = $Computer.PasswordExpired
            'LogonCount'           = $Computer.logonCount
            'ManagedBy'            = $Computer.ManagedBy
            'DistinguishedName'    = $Computer.DistinguishedName
            'OrganizationalUnit'   = ConvertFrom-DistinguishedName -DistinguishedName $Computer.DistinguishedName -ToOrganizationalUnit
            'Description'          = $Computer.Description
            'WhenCreated'          = $Computer.WhenCreated
            'WhenChanged'          = $Computer.WhenChanged
            'ServicePrincipalName' = $Computer.servicePrincipalName #-join [System.Environment]::NewLine
        }
        if ($IncludeAzureAD -and $IncludeIntune -and $IncludeJamf) {
            $Data = $DataStart + $DataAzureAD + $DataIntune + $DataJamf + $DataEnd
        } elseif ($IncludeAzureAD -and $IncludeIntune) {
            $Data = $DataStart + $DataAzureAD + $DataIntune + $DataEnd
        } elseif ($IncludeAzureAD -and $IncludeJamf) {
            $Data = $DataStart + $DataAzureAD + $DataJamf + $DataEnd
        } elseif ($IncludeIntune -and $IncludeJamf) {
            $Data = $DataStart + $DataIntune + $DataJamf + $DataEnd
        } elseif ($IncludeAzureAD) {
            $Data = $DataStart + $DataAzureAD + $DataEnd
        } elseif ($IncludeIntune) {
            $Data = $DataStart + $DataIntune + $DataEnd
        } elseif ($IncludeJamf) {
            $Data = $DataStart + $DataJamf + $DataEnd
        } else {
            $Data = $DataStart + $DataEnd
        }
        [PSCustomObject] $Data
    }
}