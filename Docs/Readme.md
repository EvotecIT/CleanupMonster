---
Module Name: CleanupMonster
Module Guid: cd1f9987-6242-452c-a7db-6337d4a6b639
Download Help Link: https://github.com/EvotecIT/CleanupMonster
Help Version: 3.1.14
Locale: en-US
---
# CleanupMonster Module
## Description
This module provides an easy way to cleanup Active Directory and cloud devices from dead/old objects based on various criteria. It can also disable, move, retire or delete objects. It can utilize Azure AD, Intune and Jamf to get additional information about objects before deleting them.

## CleanupMonster Cmdlets
### [Invoke-ADComputersCleanup](Invoke-ADComputersCleanup.md)
Active Directory Cleanup function that can disable or delete computers
that have not been logged on for a certain amount of time.

### [Invoke-ADServiceAccountsCleanup](Invoke-ADServiceAccountsCleanup.md)
Cleans up stale Active Directory service accounts.

### [Invoke-ADSIDHistoryCleanup](Invoke-ADSIDHistoryCleanup.md)
Cleans up SID history entries in Active Directory based on various filtering criteria.

### [Invoke-CloudDevicesCleanup](Invoke-CloudDevicesCleanup.md)
Cleans up stale Microsoft Entra registered cloud devices.
