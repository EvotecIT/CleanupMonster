function Request-ADServiceAccountsDisable {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $Accounts,
        [switch] $ReportOnly,
        [switch] $WhatIfDisable,
        [DateTime] $Today,
        [switch] $DontWriteToEventLog
    )
    foreach ($Account in $Accounts) {
        if ($Account.Action -ne 'Disable') { continue }
        if ($ReportOnly) {
            $Account
            continue
        }
        $Server = $Account.Server
        $Success = $false
        if ($PSCmdlet.ShouldProcess($Account.DistinguishedName, 'Disable service account')) {
            try {
                Disable-ADAccount -Identity $Account.DistinguishedName -Server $Server -WhatIf:$WhatIfDisable -ErrorAction Stop
                $Success = $true
                Write-Color -Text "[+] ", "Disabling service account ", $Account.SamAccountName, " (WhatIf: $($WhatIfDisable.IsPresent)) successful." -Color Yellow, Green, Yellow
            } catch {
                Write-Color -Text "[-] ", "Disabling service account ", $Account.SamAccountName, " failed: ", $_.Exception.Message -Color Yellow, Red, Yellow, Red
                $Account.ActionComment = $_.Exception.Message
            }
        }
        $Account.ActionDate = $Today
        if ($WhatIfDisable.IsPresent) {
            $Account.ActionStatus = 'WhatIf'
        } else {
            $Account.ActionStatus = $Success
        }
        $Account
    }
}
