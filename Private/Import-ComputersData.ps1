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
            #$ProcessedComputers = Import-Clixml -LiteralPath $FilePath -ErrorAction Stop
            if ($FileImport.PendingDeletion) {
                if ($FileImport.PendingDeletion.GetType().Name -ne 'Hashtable') {
                    Write-Color -Text "[e] ", "Incorrecting XML format. PendingDeletion is not a hashtable. Terminating." -Color Yellow, Red
                    return
                }
            }
            if ($FileImport.History) {
                if ($FileImport.History.GetType().Name -ne 'ArrayList') {
                    Write-Color -Text "[e] ", "Incorrecting XML format. History is not a ArrayList. Terminating." -Color Yellow, Red
                    return
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
        return
    }

    $ProcessedComputers
}