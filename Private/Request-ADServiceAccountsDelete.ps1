function Request-ADServiceAccountsDelete {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $Accounts,
        [switch] $ReportOnly,
        [switch] $WhatIfDelete,
        [int] $DeleteLimit,
        [DateTime] $Today,
        [switch] $DontWriteToEventLog
    )
    $CountDelete = 0
    foreach ($Account in $Accounts) {
        if ($Account.Action -ne 'Delete') { continue }
        if ($ReportOnly) {
            $Account.ActionStatus = 'ReportOnly'
            $Account
            continue
        }
        $Server = $Account.Server
        $Success = $false
        $actionApproved = $PSCmdlet.ShouldProcess($Account.DistinguishedName, 'Delete service account')
        if ($actionApproved) {
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
        if (-not $actionApproved -and -not $WhatIfPreference) {
            $Account.ActionStatus = 'Skipped'
            $Account.ActionComment = 'Confirmation declined; no action was started.'
        } elseif ($WhatIfDelete.IsPresent -or $WhatIfPreference) {
            $Account.ActionStatus = 'WhatIf'
        } else {
            $Account.ActionStatus = $Success
        }
        $Account
        $CountDelete++
        if ($DeleteLimit) {
            if ($DeleteLimit -eq $CountDelete) {
                break
            }
        }
    }
}
