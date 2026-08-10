function Save-ADComputerPendingStateEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Rollback,
        [Parameter(Mandatory)]
        [string] $Key,
        [Parameter(Mandatory)]
        [PSObject] $Value
    )

    if (-not $Rollback.Contains($Key)) {
        $Rollback[$Key] = $Value.PSObject.Copy()
    }
}
