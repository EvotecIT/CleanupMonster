function Remove-SIDHistoryPerUser {
    [CmdletBinding()]
    param(
        $Object,
        [string] $QueryServer
    )


    Write-Color -Text "[i] ", "Removing SIDHistory record (ALL) for ", $Object.Name, " (" , "Domain: ", $Object.Domain, ", ObjectClass: ", $Object.ObjectClass, ", SIDHistoryCount: ", $Object.SIDHistory.Count, ", DN: ", $Object.DistinguishedName, ")" -Color Yellow, White, Green, White, Yellow, Green, Yellow, Green, Yellow, Green, Yellow, Green, White
    Set-ADObject -Identity $Object.DistinguishedName -Clear SIDHistory -Server $QueryServer
    $GlobalLimitObject++
}