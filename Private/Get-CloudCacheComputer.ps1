function Get-CloudCacheComputer {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Cache,
        [string[]] $Candidates
    )

    if ($null -eq $Cache) {
        return $null
    }

    foreach ($Candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            continue
        }

        $Device = $Cache[$Candidate]
        if ($null -ne $Device) {
            return $Device
        }
    }

    $null
}
