$script:RepositoryRoot = Split-Path -Parent $PSScriptRoot

function Get-CleanupMonsterPath {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    Join-Path $script:RepositoryRoot $RelativePath
}
