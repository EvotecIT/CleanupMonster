<#
.SYNOPSIS
Simple Azure AD / Intune-aware preview for stale computer cleanup.

.DESCRIPTION
This is the lightest cloud-aware example in the repo. It previews which AD
computers would be disabled when Azure AD and Intune inactivity thresholds
are also required.

Use this when you want a quick cloud-aware report before moving to a more
advanced scheduled configuration.
#>

Import-Module .\CleanupMonster.psd1 -Force

Connect-MgGraph -Scopes Device.Read.All, DeviceManagementManagedDevices.Read.All, Directory.ReadWrite.All, DeviceManagementConfiguration.Read.All

# cloud matching falls back to DNSHostName aliases, which helps when the AD computer name is truncated
# this is a fresh run and it will provide report only according to it's defaults
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -ShowHTML -DisableLastSeenAzureMoreThan 80 -DisableLastSyncAzureMoreThan 80 -DisableLastSeenIntuneMoreThan 80
$Output
