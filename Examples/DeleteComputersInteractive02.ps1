<#
.SYNOPSIS
Short interactive examples focused on report retention and pending-age gates.

.DESCRIPTION
Use this file when you want to review:
- report/log rotation settings
- delete-only previews for disabled computers
- delete staging that requires time on the pending list
#>

Import-Module .\CleanupMonster.psd1 -Force

$Output = Invoke-ADComputersCleanup -LogMaximum 4 -ReportMaximum 4 -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output

$Output = Invoke-ADComputersCleanup -DeleteListProcessedMoreThan 100 -Disable -DeleteIsEnabled $false -Delete -WhatIfDelete -ShowHTML -ReportOnly -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output
