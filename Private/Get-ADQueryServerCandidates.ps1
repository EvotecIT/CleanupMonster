function Get-ADQueryServerCandidates {
    <#
    .SYNOPSIS
    Resolves the ordered domain controller candidates for an AD inventory query.

    .DESCRIPTION
    Returns manually configured domain controllers first and appends auto-detected
    controllers as fallbacks. Duplicate names are removed case-insensitively while
    preserving the configured order.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Domain,
        [object] $TargetServers,
        [object[]] $DetectedServers
    )

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $ConfiguredServers = @()
    if ($TargetServers -is [string]) {
        $ConfiguredServers = @($TargetServers)
    } elseif ($TargetServers -is [System.Collections.IDictionary]) {
        $MatchedKey = foreach ($Key in $TargetServers.Keys) {
            if ([string] $Key -ieq $Domain) {
                $Key
                break
            }
        }
        if ($null -ne $MatchedKey) {
            $ConfiguredServers = @($TargetServers[$MatchedKey])
        }
    } elseif ($TargetServers -is [System.Collections.IEnumerable]) {
        $ConfiguredServers = @($TargetServers)
    }

    foreach ($Server in @($ConfiguredServers) + @($DetectedServers)) {
        $ServerName = [string] $Server
        if (-not [string]::IsNullOrWhiteSpace($ServerName) -and $Seen.Add($ServerName.Trim())) {
            $Candidates.Add($ServerName.Trim())
        }
    }

    $Candidates.ToArray()
}
