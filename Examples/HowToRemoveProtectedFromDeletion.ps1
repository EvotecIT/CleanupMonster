$Computers = @(
    'ComputerToRemoveProtected$'
)
$Server = 'domain.com'
foreach ($Computer in $Computers) {
    $ADComputer = Get-ADComputer -Identity $Computer -Server $Server
    Set-ADObject -Server $Server -Identity $ADComputer.DistinguishedName -ProtectedFromAccidentalDeletion $false -Verbose
}