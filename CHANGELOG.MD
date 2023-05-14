### 2.0.0
Issues resolved:
- Fixes [#2](https://github.com/EvotecIT/CleanupMonster/issues/2)

Improvements:
- Add ability to move objects (disable, move or/and delete) as separate action
  - disable, move and delete all have their separate rules to act upon
- Add ability to move objects as part of the disable process (disable and move right after) - `DisableAndMove` switch
- Fix handling processing list (using custom search rather then DN which would not work if object was moved)
- Add `DontWriteToEventLog` switch to disable writing to event log
- Processed lists now only remove items if delete or move is successful
- Computers is removed from processed list if it's moved, and there's no delete action, otherwise it's removed only on delete. Make sure to not use `Delete` switch if you don't plan to delete objects

### 1.6.0 - 2023.05.12
Issues resolved:
- Fixes [#4](https://github.com/EvotecIT/CleanupMonster/issues/4)

Following features are added:
- Add support for Forest
- Add support for IncludeDomains
- Add support for ExcludeDomain

### 1.5.0 - 2023.05.12
- Fixes an error when using processed list when deleting computers
- Fixes an +1 in the count of objects displayed in HTML

### 1.4.0 - 2023.05.08
- Add an alias to Invoke-ADComputersCleanup
- Show AllProperties for History & Pending values in HTML report
- Fix small issues with HTML
- Fixes critical logic flaw for AzureAD, Intune, Jamf

### 1.3.0 - 2023.05.08
- Remove verbose from Jamf queries

### 1.2.0
- Renamed PowerShell module to CleanupMonster
- Invoke-ADComputersCleanup
  - Support for more AD controlled parameters
    - Added `DisablePasswordLastSetOlderThan`
    - Added `DisableLastLogonDateOlderThan`
    - Added `DeletePasswordLastSetOlderThan`
    - Added `DeleteLastLogonDateOlderThan`
  - Support for Azure AD and Intune (via Graph API, requires GraphEssentials module, not installed by default)
    - Added `DisableLastSeenAzureMoreThan`
    - Added `DisableLastSyncAzureMoreThan`
    - Added `DisableLastSeenIntuneMoreThan`
    - Added `DeleteLastSeenAzureMoreThan`
    - Added `DeleteLastSyncAzureMoreThan`
    - Added `DeleteLastSeenIntuneMoreThan`
  - Support for Jamf Pro (via Jamf Pro API, requires PowerJamf module, not installed by default)
    - Added `DisableLastContactJamfMoreThan`
    - Added `DeleteLastContactJamfMoreThan`
  - Support for Safety Limits (cleanup will cancel if conditions are not matched, by default disabled)
    - Added `SafetyADLimit` - minimum X number of computers to be returned from the AD
    - Added `SafetyAzureADLimit` - minimum X number of computers to be returned from the Azure AD
    - Added `SafetyIntuneLimit` - minimum X number of computers to be returned from the Intune
    - Added `SafetyJamfLimit` - minimum X number of computers to be returned from the Jamf Pro
  - Reworked HTML reports to be more readable and some logic changes

Showing new options

```powershell
$DateTime = Get-Date -Year 2021 -Month 8 -Day 19 -Hour 0 -Minute 0 -Second 0
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -ShowHTML -DisablePasswordLastSetOlderThan $DateTime -DisableLastLogonDateOlderThan $DateTime -DeletePasswordLastSetOlderThan $DateTime -DeleteLastLogonDateOlderThan $DateTime
$Output
```

With support for Jamf and Azure AD

```powershell
Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.ReadWrite.All, DeviceManagementConfiguration.Read.All
Connect-Jamf -Organization 'aaa' -UserName 'aaaa' -Suppress -Force -Password '01000000d08c9ddf0115d1118c7a0'

# this is a fresh run and it will provide report only according to it's defaults
$Output = Invoke-ADComputersCleanup -ReportOnly -SafetyJamfLimit 99 -WhatIf -Disable -ShowHTML -DisableLastSeenAzureMoreThan 80 -DisableLastSyncAzureMoreThan 80 -DisableLastSeenIntuneMoreThan 80 -DisableLastContactJamfMoreThan 80 #-Delete -DeleteListProcessedMoreThan 80
$Output
```

### 1.1.4 - 2023.04.03
- Clarify HTML information when it comes to PasswordLastSet and LastLogonDays

### 1.1.3 - 2023.04.01
- Improved reporting when using `ReportOnly` switch
- Improved logging and error handling
- Added some statistics to the report
- Added ability to delete older reports

### 1.1.2 - 2023.03.31
- Improved reporting when using `ReportOnly` switch
- Added some more logging and error handling

### 1.1.1 - 2023.03.21
- Improved reporting
- Fixes [#1](https://github.com/EvotecIT/CleanupMonster/issues/1) where it would not add computers to IsProcessedList

### 1.0.0
- Initial release