# CleanupMonster - PowerShell Module

<p align="center">
  <a href="https://www.powershellgallery.com/packages/CleanupMonster"><img src="https://img.shields.io/powershellgallery/v/CleanupMonster.svg?style=flat-square"></a>
  <a href="https://www.powershellgallery.com/packages/CleanupMonster"><img src="https://img.shields.io/powershellgallery/vpre/CleanupMonster.svg?label=powershell%20gallery%20preview&colorB=yellow&style=flat-square"></a>
  <a href="https://github.com/EvotecIT/CleanupMonster"><img src="https://img.shields.io/github/license/EvotecIT/CleanupMonster.svg?style=flat-square"></a>
</p>

<p align="center">
  <a href="https://www.powershellgallery.com/packages/CleanupMonster"><img src="https://img.shields.io/powershellgallery/p/CleanupMonster.svg?style=flat-square"></a>
  <a href="https://github.com/EvotecIT/CleanupMonster"><img src="https://img.shields.io/github/languages/top/evotecit/CleanupMonster.svg?style=flat-square"></a>
  <a href="https://github.com/EvotecIT/CleanupMonster"><img src="https://img.shields.io/github/languages/code-size/evotecit/CleanupMonster.svg?style=flat-square"></a>
  <a href="https://www.powershellgallery.com/packages/CleanupMonster"><img src="https://img.shields.io/powershellgallery/dt/CleanupMonster.svg?style=flat-square"></a>
</p>

<p align="center">
  <a href="https://twitter.com/PrzemyslawKlys"><img src="https://img.shields.io/twitter/follow/PrzemyslawKlys.svg?label=Twitter%20%40PrzemyslawKlys&style=flat-square&logo=twitter"></a>
  <a href="https://evotec.xyz/hub"><img src="https://img.shields.io/badge/Blog-evotec.xyz-2A6496.svg?style=flat-square"></a>
  <a href="https://www.linkedin.com/in/pklys"><img src="https://img.shields.io/badge/LinkedIn-pklys-0077B5.svg?logo=LinkedIn&style=flat-square"></a>
</p>

`CleanupMonster` is a PowerShell module to that helps you clean up **Active Directory**.
It's a complete solution that allows you to remove stale Computer (Users will be added in future) objects from **Active Directory**. It's a very advanced module with many options and you can easily customize it to your needs.
Please make sure to run this module with proper permissions or you may get wrong results.
By default Active Directory domain allows a standard user to read LastLogonDate and LastPasswordSet attributes.
If you have changed those settings you may need to run the module with elevated permissions even for reporting needs.

### Support/Sponsor

Does your company use our .NET libraries or PowerShell Modules?
Ask your manager or marketing team if your company would be interested in supporting our project.
Support will allow the maintainers to dedicate more time for maintenance and new features for everyone.
It takes a lot of time and effort to create and maintain them.
If you find them useful, please consider supporting the development.

 - [Become a sponsor via GitHub Sponsors :heart:](https://github.com/sponsors/PrzemyslawKlys)
 - [Become a sponsor via PayPal :heart:](https://paypal.me/PrzemyslawKlys)

### Installation

```powershell
Install-Module -Name CleanupMonster -Force -Verbose
```

### Using the module

#### Cleaning Active Directory

##### Report Only

The first thing you should do is to run the module in a report only mode.
It will show you how many computers are there to disable and delete.

```powershell
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
$Output
```

Keep in mind it works with default values such as 180 days for LastLogonDate and LastPasswordSet.
You can change those values by using parameters.

![ReportOnlyMode](https://raw.githubusercontent.com/EvotecIT/CleanupMonster/master/Examples/Images/ComputersReport.png)

##### Interactively

This is a sample script that you can use to run the module interactively.
It's good idea to run it interactively first to clean your AD and then run it in a scheduled task.

```powershell
# this is a fresh run and it will try to disable computers according to it's defaults
$Output = Invoke-ADComputersCleanup -Disable -WhatIfDisable -ShowHTML
$Output
```

When you run cleanup the module will deliver HTML report on every run.
It will show you:

- Devices in Current Run (Actioned)

![CurrentRun](https://raw.githubusercontent.com/EvotecIT/CleanupMonster/master/Examples/Images/CleanupDevicesCurrentRun.png)

- Devices in Previous Runs (History)

![PreviousRuns](https://raw.githubusercontent.com/EvotecIT/CleanupMonster/master/Examples/Images/CleanupDevicesHistory.png)

- Devices on Pending List (Pending deletion)

![PendingList](https://raw.githubusercontent.com/EvotecIT/CleanupMonster/master/Examples/Images/CleanupDevicesPending.png)

- All Devices (All) remaining

![AllRemaining](https://raw.githubusercontent.com/EvotecIT/CleanupMonster/master/Examples/Images/CleanupDevicesAllRemaining.png)

Another example with log settings and custom report path

```powershell
# this is a fresh run and it will try to delete computers according to it's defaults
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output
```

##### Non-interactively (scheduled task)

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