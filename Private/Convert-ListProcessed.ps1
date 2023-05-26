function Convert-ListProcessed {
    <#
    .SYNOPSIS
    This function converts old format of writting down pending list with DN to new format with SamAccountName with domain.

    .DESCRIPTION
    This function converts old format of writting down pending list with DN to new format with SamAccountName with domain.
    The old way would probably break if someone would move computer after disabling which would cause the computer to be removed from the list.

    .PARAMETER FileImport
    Hashtable with PendingDeletion and History keys.

    .EXAMPLE
    $FileImport = Import-Clixml -LiteralPath $DataStorePath -ErrorAction Stop
    # convert old format to new format
    $FileImport = Convert-ListProcessed -FileImport $FileImport

    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $FileImport
    )
    if (-not $FileImport.PendingDeletion -or $FileImport.PendingDeletion.Keys.Count -gt 0) {
        return $FileImport
    }
    if ($FileImport.PendingDeletion.Keys[0] -like "*@*") {
        # Write-Color -Text "[i] ", "List is already converted. Terminating." -Color Yellow, Green
        return $FileImport
    }
    Write-Color -Text "[i] ", "Converting list to new format." -Color Yellow, Green
    foreach ($Key in [string[]] $FileImport.PendingDeletion.Keys) {
        $DomainName = ConvertFrom-DistinguishedName -DistinguishedName $FileImport.PendingDeletion[$Key].DistinguishedName -ToDomainCN
        $NewKey = -join ($FileImport.PendingDeletion[$Key].SamAccountName, "@", $DomainName)
        $FileImport.PendingDeletion[$NewKey] = $FileImport.PendingDeletion[$Key]
        $null = $FileImport.PendingDeletion.Remove($Key)
    }
    Write-Color -Text "[i] ", "List converted." -Color Yellow, Green
    $FileImport
}