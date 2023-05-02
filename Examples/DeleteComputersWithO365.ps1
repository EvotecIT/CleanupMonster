Import-Module .\CleanupMonster.psd1 -Force

Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.ReadWrite.All, DeviceManagementConfiguration.Read.All

# this is a fresh run and it will provide report only according to it's defaults
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -ShowHTML -DisableLastSeenAzureMoreThan 80 -DisableLastSyncAzureMoreThan 80 -DisableLastSeenIntuneMoreThan 80
$Output