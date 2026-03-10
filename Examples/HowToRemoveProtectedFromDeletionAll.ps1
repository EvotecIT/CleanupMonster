<#
.SYNOPSIS
Preview removing accidental-deletion protection from all computers in a domain.

.DESCRIPTION
This helper iterates every computer and removes the
ProtectedFromAccidentalDeletion flag for objects that have it set.

Use this only for deliberate bulk preparation work. Keep `-WhatIf` until you
have confirmed the scope is correct.
#>

$Domain = 'ad.evotec.xyz'
$ADComputers = Get-ADComputer -Filter * -Properties ProtectedFromAccidentalDeletion -Server $Domain
foreach ($ADComputer in $ADComputers) {
    if ($ADComputer.ProtectedFromAccidentalDeletion) {
        Write-Host "Removing ProtectedFromAccidentalDeletion from $($ADComputer.Name)"
        Set-ADObject -Server $Domain -Identity $ADComputer.DistinguishedName -ProtectedFromAccidentalDeletion $false -Verbose -WhatIf
    }
}
