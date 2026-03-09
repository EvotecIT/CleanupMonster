function Get-ComputerLookupCandidates {
    [CmdletBinding()]
    param(
        [string] $Name,
        [string] $DNSHostName,
        [string] $SamAccountName
    )

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $AddCandidate = {
        param(
            [string] $Value
        )

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return
        }

        $TrimmedValue = $Value.Trim()
        if ($Seen.Add($TrimmedValue)) {
            $Candidates.Add($TrimmedValue) | Out-Null
        }
    }

    & $AddCandidate $Name
    & $AddCandidate $DNSHostName
    if ($DNSHostName -like '*.*') {
        & $AddCandidate (($DNSHostName -split '\.')[0])
    }
    & $AddCandidate $SamAccountName
    if ($SamAccountName) {
        & $AddCandidate ($SamAccountName.TrimEnd('$'))
    }

    $Candidates.ToArray()
}
