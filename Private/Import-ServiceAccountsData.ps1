function Import-ServiceAccountsData {
    <#
    .SYNOPSIS
    Imports service accounts data from XML file for processing.

    .DESCRIPTION
    This function imports previously processed service accounts data from an XML file.
    It converts old format to new format if needed and validates the data structure.
    #>
    [CmdletBinding()]
    param(
        [string] $DataStorePath,
        [System.Collections.IDictionary] $Export
    )

    $ProcessedServiceAccounts = [ordered] @{ }
    $Today = Get-Date
    try {
        if ($DataStorePath -and (Test-Path -LiteralPath $DataStorePath -ErrorAction Stop)) {
            $FileImport = Import-Clixml -LiteralPath $DataStorePath -ErrorAction Stop
            # convert old format to new format if needed
            $FileImport = Convert-ListProcessed -FileImport $FileImport

            if ($FileImport.PendingDeletion) {
                if ($FileImport.PendingDeletion.GetType().Name -notin 'Hashtable', 'OrderedDictionary') {
                    Write-Color -Text "[e] ", "Incorrect XML format. PendingDeletion is not a hashtable/ordereddictionary. Terminating." -Color Yellow, Red
                    return $false
                }
            }
            if ($FileImport.History) {
                if ($FileImport.History.GetType().Name -ne 'ArrayList') {
                    Write-Color -Text "[e] ", "Incorrect XML format. History is not an arraylist. Terminating." -Color Yellow, Red
                    return $false
                }
            }
            $ProcessedServiceAccounts = $FileImport.PendingDeletion
            if ($ProcessedServiceAccounts) {
                # Update TimeOnPendingList for each service account
                foreach ($ServiceAccount in $ProcessedServiceAccounts.Values) {
                    $TimeOnPendingList = if ($ServiceAccount.ActionDate) {
                        - $($ServiceAccount.ActionDate - $Today).Days
                    } else {
                        $null
                    }
                    $ServiceAccount.TimeOnPendingList = $TimeOnPendingList
                }
            }
            $Export['History'] = $FileImport.History
        }
        if (-not $ProcessedServiceAccounts) {
            $ProcessedServiceAccounts = [ordered] @{ }
        }
    } catch {
        Write-Color -Text "[e] ", "Couldn't read the list or wrong format. Error: $($_.Exception.Message)" -Color Yellow, Red
        return $false
    }
    $ProcessedServiceAccounts
}
