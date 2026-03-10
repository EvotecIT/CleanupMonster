<#
.SYNOPSIS
Re-enables specific computers after review.

.DESCRIPTION
Use this as a simple rollback helper when a computer was disabled during
cleanup and needs to be restored manually.

Before running, confirm:
- the computer names
- the target domain controller
- whether the computer also needs to be moved back to its original OU
#>

$Computers = @(
    'de-muc-01'
)
$Test = $Computers | Sort-Object -Unique

foreach ($Computer in $Test) {
    Set-ADComputer -Identity $Computer -Server 'domain.loc' -Enabled $true
}
