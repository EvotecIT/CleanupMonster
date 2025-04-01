Import-Module .\CleanupMonster.psd1 -Force

# Run the script
$Configuration = @{
    Disable                                   = $true
    DisableNoServicePrincipalName             = $null
    DisableIsEnabled                          = $true
    DisableLastLogonDateMoreThan              = 90
    DisablePasswordLastSetMoreThan            = 90
    DisableExcludeSystems                     = @(
        # 'Windows Server*'
    )
    DisableIncludeSystems                     = @()
    DisableLimit                              = 1 # 0 means unlimited, ignored for reports
    DisableModifyDescription                  = $false
    DisableModifyAdminDescription             = $true

    Delete                                    = $true
    DeleteIsEnabled                           = $false
    DeleteNoServicePrincipalName              = $null
    DeleteLastLogonDateMoreThan               = 180
    DeletePasswordLastSetMoreThan             = 180
    DeleteListProcessedMoreThan               = 90 # 90 days since computer was added to list
    DeleteExcludeSystems                      = @(
        # 'Windows Server*'
    )
    DeleteIncludeSystems                      = @(

    )
    DeleteLimit                               = 1 # 0 means unlimited, ignored for reports

    Exclusions                                = @(
        '*OU=Domain Controllers*'
        '*OU=Servers,OU=Production*'
        'EVOMONSTER$'
        'EVOMONSTER.AD.EVOTEC.XYZ'
    )

    Filter                                    = '*'
    WhatIfDisable                             = $true
    WhatIfDelete                              = $true
    LogPath                                   = "$PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                             = "$PSScriptRoot\DeleteComputers_ListProcessed.xml"
    ReportPath                                = "$PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                                  = $true

    RemoveProtectedFromAccidentalDeletionFlag = $true
}

# Run one time as admin: Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers'
$Output = Invoke-ADComputersCleanup @Configuration
$Output