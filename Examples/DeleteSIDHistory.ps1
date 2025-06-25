Import-Module .\CleanupMonster.psd1 -Force

# Prepare splat
$invokeADSIDHistoryCleanupSplat = @{
    Verbose                 = $true
    WhatIf                  = $true
    IncludeSIDHistoryDomain = @(
        'S-1-5-21-3661168273-3802070955-2987026695'
        'S-1-5-21-853615985-2870445339-3163598659'
    )
    IncludeOrganizationalUnit = @(
        "OU=ITR01,DC=ad,DC=evotec,DC=xyz"
    )
    #IncludeType             = 'External'
    RemoveLimitSID          = 1
    RemoveLimitObject       = 1
    SafetyADLimit           = 1
    ShowHTML                = $true
    Online                  = $true
    DisabledOnly            = $false
    ReportOnly              = $false
    LogPath                 = "C:\Temp\ProcessedSIDHistory.log"
    ReportPath              = "$PSScriptRoot\ProcessedSIDHistory.html"
    DataStorePath           = "$PSScriptRoot\ProcessedSIDHistory.xml"
}

# Run the script
$Output = Invoke-ADSIDHistoryCleanup @invokeADSIDHistoryCleanupSplat
$Output | Format-Table -AutoSize

# Lets send an email
#$EmailBody = $Output.EmailBody

#Connect-MgGraph -Scopes 'Mail.Send' -NoWelcome
#Send-EmailMessage -To 'przemyslaw.klys@test.pl' -From 'przemyslaw.klys@test.pl' -MgGraphRequest -Subject "Automated SID Cleanup Report" -Body $EmailBody -Priority Low -Verbose