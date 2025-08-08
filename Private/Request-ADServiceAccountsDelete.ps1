function Request-ADServiceAccountsDelete {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $Accounts,
        [switch] $ReportOnly,
        [switch] $WhatIfDelete,
        [DateTime] $Today,
        [switch] $DontWriteToEventLog
    )
    foreach ($Account in $Accounts) {
        if ($Account.Action -ne 'Delete') { continue }
        if ($ReportOnly) {
            $Account
            continue
        }
        $Server = $Account.Server
        $Success = $false
        if ($PSCmdlet.ShouldProcess($Account.DistinguishedName, 'Delete service account')) {
            try {
                Remove-ADObject -Identity $Account.DistinguishedName -Server $Server -Confirm:$false -WhatIf:$WhatIfDelete -ErrorAction Stop
                $Success = $true
                Write-Color -Text "[+] ", "Deleting service account ", $Account.SamAccountName, " (WhatIf: $($WhatIfDelete.IsPresent)) successful." -Color Yellow, Green, Yellow
            } catch {
                Write-Color -Text "[-] ", "Deleting service account ", $Account.SamAccountName, " failed: ", $_.Exception.Message -Color Yellow, Red, Yellow, Red
                $Account.ActionComment = $_.Exception.Message
            }
        }
        $Account.ActionDate = $Today
        if ($WhatIfDelete.IsPresent) {
            $Account.ActionStatus = 'WhatIf'
        } else {
            $Account.ActionStatus = $Success
        }
        $Account
    }
}
