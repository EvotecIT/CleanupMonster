function Import-ComputersData {
    [CmdletBinding()]
    param(
        [string] $DataStorePath,
        [System.Collections.IDictionary] $Export
    )

    $ProcessedComputers = [ordered] @{ }

    try {
        if ($DataStorePath -and (Test-Path -LiteralPath $DataStorePath)) {
            $FileImport = Import-Clixml -LiteralPath $DataStorePath -ErrorAction Stop
            # convert old format to new format
            $FileImport = Convert-ListProcessed -FileImport $FileImport

            if ($FileImport.PendingDeletion) {
                if ($FileImport.PendingDeletion.GetType().Name -notin 'Hashtable', 'OrderedDictionary') {
                    Write-Color -Text "[e] ", "Incorrect XML format. PendingDeletion is not a hashtable/ordereddictionary. Terminating." -Color Yellow, Red
                    return $false
                }
            }
            if ($FileImport.History) {
                if ($FileImport.History.GetType().Name -ne 'ArrayList') {
                    Write-Color -Text "[e] ", "Incorrect XML format. History is not a ArrayList. Terminating." -Color Yellow, Red
                    return $False
                }
            }
            $ProcessedComputers = $FileImport.PendingDeletion
            $Export['History'] = $FileImport.History
        }
        if (-not $ProcessedComputers) {
            $ProcessedComputers = [ordered] @{ }
        }
    } catch {
        Write-Color -Text "[e] ", "Couldn't read the list or wrong format. Error: $($_.Exception.Message)" -Color Yellow, Red
        return $false
    }

    $ProcessedComputers
}