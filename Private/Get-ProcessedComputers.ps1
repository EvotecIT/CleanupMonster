function Get-ProcessedComputers {
    [cmdletBinding()]
    param(
        [string] $FilePath
    )
    if ($FilePath -and (Test-Path -LiteralPath $FilePath)) {
        $ComputersList = Import-Clixml -LiteralPath $FilePath
        $ComputersList
    }
}