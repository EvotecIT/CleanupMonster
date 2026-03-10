<#
.SYNOPSIS
Preview removing accidental-deletion protection from a small set of computers.

.DESCRIPTION
Use this when you want a narrowly scoped alternative to the bulk example and
you already know which computer objects need to be prepared for move or delete
operations.
#>

$Computers = @(
    'ComputerToRemoveProtected$'
)
$Server = 'domain.com'
foreach ($Computer in $Computers) {
    $ADComputer = Get-ADComputer -Identity $Computer -Server $Server
    Set-ADObject -Server $Server -Identity $ADComputer.DistinguishedName -ProtectedFromAccidentalDeletion $false -Verbose -WhatIf
}
