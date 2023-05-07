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

```powershell
$DateTime = Get-Date -Year 2021 -Month 8 -Day 19 -Hour 0 -Minute 0 -Second 0
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -ShowHTML -DisablePasswordLastSetOlderThan $DateTime -DisableLastLogonDateOlderThan $DateTime -DeletePasswordLastSetOlderThan $DateTime -DeleteLastLogonDateOlderThan $DateTime
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