$Computers = @(
    'de-muc-01'
)
$Test = $Computers | Sort-Object -Unique

foreach ($Computer in $Test) {
    Set-ADComputer -Identity $Computer -Server 'domain.loc' -Enabled $true
}