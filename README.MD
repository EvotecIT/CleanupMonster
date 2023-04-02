# CleanupActiveDirectory - PowerShell Module

<p align="center">
  <a href="https://www.powershellgallery.com/packages/CleanupActiveDirectory"><img src="https://img.shields.io/powershellgallery/v/CleanupActiveDirectory.svg?style=flat-square"></a>
  <a href="https://www.powershellgallery.com/packages/CleanupActiveDirectory"><img src="https://img.shields.io/powershellgallery/vpre/CleanupActiveDirectory.svg?label=powershell%20gallery%20preview&colorB=yellow&style=flat-square"></a>
  <a href="https://github.com/EvotecIT/CleanupActiveDirectory"><img src="https://img.shields.io/github/license/EvotecIT/CleanupActiveDirectory.svg?style=flat-square"></a>
</p>

<p align="center">
  <a href="https://www.powershellgallery.com/packages/CleanupActiveDirectory"><img src="https://img.shields.io/powershellgallery/p/CleanupActiveDirectory.svg?style=flat-square"></a>
  <a href="https://github.com/EvotecIT/CleanupActiveDirectory"><img src="https://img.shields.io/github/languages/top/evotecit/CleanupActiveDirectory.svg?style=flat-square"></a>
  <a href="https://github.com/EvotecIT/CleanupActiveDirectory"><img src="https://img.shields.io/github/languages/code-size/evotecit/CleanupActiveDirectory.svg?style=flat-square"></a>
  <a href="https://www.powershellgallery.com/packages/CleanupActiveDirectory"><img src="https://img.shields.io/powershellgallery/dt/CleanupActiveDirectory.svg?style=flat-square"></a>
</p>

<p align="center">
  <a href="https://twitter.com/PrzemyslawKlys"><img src="https://img.shields.io/twitter/follow/PrzemyslawKlys.svg?label=Twitter%20%40PrzemyslawKlys&style=flat-square&logo=twitter"></a>
  <a href="https://evotec.xyz/hub"><img src="https://img.shields.io/badge/Blog-evotec.xyz-2A6496.svg?style=flat-square"></a>
  <a href="https://www.linkedin.com/in/pklys"><img src="https://img.shields.io/badge/LinkedIn-pklys-0077B5.svg?logo=LinkedIn&style=flat-square"></a>
</p>

`CleanupActiveDirectory` is a PowerShell module to that helps you clean up **Active Directory**.
It's a complete solution that allows you to remove stale Computer (Users will be added in future) objects from **Active Directory**.

### Support Evotec

Support the efforts of the development of the Evotec projects.
It takes a lot of time and effort to create and maintain them.
If you find them useful, please consider supporting the development.

 - [Become a sponsor via GitHub Sponsors :heart:](https://github.com/sponsors/PrzemyslawKlys)
 - [Become a sponsor via PayPal :heart:](https://paypal.me/PrzemyslawKlys)

### Installation

```powershell
Install-Module -Name CleanupActiveDirectory -Force -Verbose
```

### Using the module

#### Report Only

The first thing you should do is to run the module in a report only mode.
It will show you how many computers are there to disable and delete.

```powershell
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
$Output
```

Keep in mind it works with default values such as 180 days for LastLogonDate and LastPasswordSet.
You can change those values by using parameters.

![Report](https://raw.githubusercontent.com/EvotecIT/CleanupActiveDirectory/blob/master/Examples/Images/ComputersReport.png)



#### Interactively

This is a sample script that you can use to run the module interactively.
It's good idea to run it interactively first to clean your AD and then run it in a scheduled task.

```powershell
# this is a fresh run and it will try to disable computers according to it's defaults
$Output = Invoke-ADComputersCleanup -Disable -WhatIfDisable -ShowHTML
$Output
```

```powershell
# this is a fresh run and it will try to delete computers according to it's defaults
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output
```

#### Non-interactively (scheduled task)

This is a sample script that you can use to run the module in a scheduled task. It's a good idea to run it as a scheduled task as it will log all the actions and you can easily review them. It's very advanced with many options and you can easily customize it to your needs.

```powershell
# Run the script
$Configuration = @{
    Disable                        = $true
    DisableNoServicePrincipalName  = $null
    DisableIsEnabled               = $true
    DisableLastLogonDateMoreThan   = 90
    DisablePasswordLastSetMoreThan = 90
    DisableExcludeSystems          = @(
        # 'Windows Server*'
    )
    DisableIncludeSystems          = @()
    DisableLimit                   = 2 # 0 means unlimited, ignored for reports
    DisableModifyDescription       = $false
    DisableAdminModifyDescription  = $true

    Delete                         = $true
    DeleteIsEnabled                = $false
    DeleteNoServicePrincipalName   = $null
    DeleteLastLogonDateMoreThan    = 180
    DeletePasswordLastSetMoreThan  = 180
    DeleteListProcessedMoreThan    = 90 # 90 days since computer was added to list
    DeleteExcludeSystems           = @(
        # 'Windows Server*'
    )
    DeleteIncludeSystems           = @(

    )
    DeleteLimit                    = 2 # 0 means unlimited, ignored for reports

    Exclusions                     = @(
        '*OU=Domain Controllers*'
        '*OU=Servers,OU=Production*'
        'EVOMONSTER$'
        'EVOMONSTER.AD.EVOTEC.XYZ'
    )

    Filter                         = '*'
    WhatIfDisable                  = $true
    WhatIfDelete                   = $true
    LogPath                        = "$PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log"
    DataStorePath                  = "$PSScriptRoot\DeleteComputers_ListProcessed.xml"
    ReportPath                     = "$PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html"
    ShowHTML                       = $true
}

# Run one time as admin: Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers'
$Output = Invoke-ADComputersCleanup @Configuration
$Output
```