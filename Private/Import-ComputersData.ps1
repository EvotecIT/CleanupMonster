function Import-ComputersData {
    [CmdletBinding()]
    param(
        [string] $DataStorePath,
        [System.Collections.IDictionary] $Export
    )

    $ProcessedComputers = [ordered] @{ }
    $Today = Get-Date
    try {
        if ($DataStorePath -and (Test-Path -LiteralPath $DataStorePath -ErrorAction Stop)) {
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
            foreach ($ComputerFullName in $ProcessedComputers.Keys) {
                $Computer = $ProcessedComputers[$ComputerFullName]
                if ($Computer.PSObject.Properties.Name -notcontains 'TimeOnPendingList') {
                    $TimeOnPendingList = if ($Computer.ActionDate) {
                        - $($Computer.ActionDate - $Today).Days
                    } else {
                        $null
                    }
                    # We need to add this property to the object, as it may not exist on the old exports
                    Add-Member -MemberType NoteProperty -Name 'TimeOnPendingList' -Value $TimeOnPendingList -Force -InputObject $Computer
                    Add-Member -MemberType NoteProperty -Name 'TimeToLeavePendingList' -Value $null -Force -InputObject $Computer
                } else {
                    $TimeOnPendingList = if ($Computer.ActionDate) {
                        - $($Computer.ActionDate - $Today).Days
                    } else {
                        $null
                    }
                    $Computer.TimeOnPendingList = $TimeOnPendingList
                }
            }
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