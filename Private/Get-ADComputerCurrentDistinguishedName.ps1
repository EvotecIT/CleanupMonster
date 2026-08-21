function Get-ADComputerCurrentDistinguishedName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Computer
    )

    if ($Computer.DistinguishedNameAfterMove) {
        $Computer.DistinguishedNameAfterMove
    } else {
        $Computer.DistinguishedName
    }
}
