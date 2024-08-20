### 2.8.1 - 2024.08.20
- Add `ProtectedFromAccidentalDeletion` to the report

### 2.8.0 - 2024.08.19
Added 3 new parameters:
- `DisableRequireWhenCreatedMoreThan` - disable computers only if they were created more than X days ago
- `MoveRequireWhenCreatedMoreThan` - move computers only if they were created more than X days ago
- `DeleteRequireWhenCreatedMoreThan` - delete computers only if they were created more than X days ago
This is to prevent completly new computers being disabled, moved or deleted. By default Disable/Delete are set to old than 90 days old, and Move is not set at all.

### 2.7.2 - 2024.08.12
- Fixes for processing computer over and over again when moving computers

### 2.7.1 - 2024.08.07
- Fixes bad export of aliases in module

### 2.7.0 - 2024.07.31
- Added `DisableAndMoveOrder` to allow for moving computers before disabling them when DisableAndMove is enabled. Options are: `DisableAndMove`, `MoveAndDisable`. Default is `DisableAndMove` (current setting)
- Improve handling of processed list when moving computers
- Improve output in HTML report

### 2.6.2
- Fix typo in HTML report

### 2.6.1
- Improve Logging Capabilities to not delete log if it's the same folder
- Add additional loggin options

### 2.6.0
- Fix display issue with HTML report

### 2.5.0
- Fix for Jamf Pro where it would only process 100 computers
- Fix for processed list during deletion would use DN instead of FullName as expected, preventing deletion

### 2.4.1 - 2023.06.06
- Fixes typo in a report

### 2.4.0 - 2023.05.30
- Fixes removing computers from processed list after list conversion

### 2.2.0 - 2023.05.30
- Fixes conversion logic

### 2.1.0 - 2023.05.30
- Fixes bug around AzureAD, Intune, Jamf processing wrong computers
- Fixed wrong function placement on import
- Small improvements

### 2.0.0
Issues resolved:
- Implement move and move on disable [#2](https://github.com/EvotecIT/CleanupMonster/issues/2)
- Allow exclude or include for Disable/Delete or Move and Service Principal Name [#7](https://github.com/EvotecIT/CleanupMonster/issues/7)

Improvements:
- Add ability to move objects (disable, move or/and delete) as separate action
  - disable, move and delete all have their separate rules to act upon
- Add ability to move objects as part of the disable process (disable and move right after) - `DisableAndMove` switch
- Fix handling processing list (using custom search rather then DN which would not work if object was moved)
- Add `DontWriteToEventLog` switch to disable writing to event log
- Processed lists now only remove items if delete or move is successful
- Computers is removed from processed list if it's moved, and there's no delete action, otherwise it's removed only on delete. Make sure to not use `Delete` switch if you don't plan to delete objects
- Add ability to exclude or include computers based on specific SPN (Service Principal Name) - `DisableExcludeServicePrincipalName` and `DisableIncludeServicePrincipalName`
- Add ability to exclude or include computers based on specific SPN (Service Principal Name) - `MoveExcludeServicePrincipalName` and `MoveIncludeServicePrincipalName`
- Add ability to exclude or include computers based on specific SPN (Service Principal Name) - `DeleteExcludeServicePrincipalName` and `DeleteIncludeServicePrincipalName`
- Added `DoNotAddToPendingList` switch to disable adding computers to pending list when disabling or moving, and when deletion is enabled

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