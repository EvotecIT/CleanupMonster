function Import-SIDHistory {
    [CmdletBinding()]
    param(
        [string] $DataStorePath,
        [System.Collections.IDictionary] $Export
    )
    try {
        if ($DataStorePath -and (Test-Path -LiteralPath $DataStorePath -ErrorAction Stop)) {
            $FileImport = Import-Clixml -LiteralPath $DataStorePath -ErrorAction Stop
            if ($FileImport.History) {
                $Export.History = $FileImport.History
            }
        }
    } catch {
        Write-Color -Text "[e] ", "Couldn't read the list or wrong format. Error: $($_.Exception.Message)" -Color Yellow, Red
        return $false
    }

    $Export
}