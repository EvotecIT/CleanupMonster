$Domain = 'ad.evotec.xyz'
$ADComputers = Get-ADComputer -Filter * -Properties ProtectedFromAccidentalDeletion -Server $Domain
foreach ($ADComputer in $ADComputers) {
    if ($ADComputer.ProtectedFromAccidentalDeletion) {
        Write-Host "Removing ProtectedFromAccidentalDeletion from $($ADComputer.Name)"
        Set-ADObject -Server $Domain -Identity $ADComputer.DistinguishedName -ProtectedFromAccidentalDeletion $false -Verbose -WhatIf
    }
}