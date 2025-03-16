Import-Module .\CleanupMonster.psd1 -Force

# Run the script
$invokeADSIDHistoryCleanupSplat = @{
    Verbose                 = $true
    WhatIf                  = $true
    IncludeSIDHistoryDomain = @(
        'S-1-5-21-3661168273-3802070955-2987026695'
    )
    IncludeType             = 'External'
    RemoveLimit             = 2
}

$Output = Invoke-ADSIDHistoryCleanup @invokeADSIDHistoryCleanupSplat
$Output

<#
S-1-5-21-3661168273-3802070955-2987026695
S-1-5-21-853615985-2870445339-3163598659
S-1-5-21-1928204107-2710010574-1926425344
#>