Import-Module .\CleanupMonster.psd1 -Force

# this is a fresh run and it will provide report only according to it's defaults
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
$Output

# this is a fresh run and it will provide report only according to its defaults
# the defaults are 180 days last logon and 180 days password last set
# but we also now add the requirement that computer hasn't changed it's password before 2021-08-19 00:00:00
# and it hasn't logged on before 2021-08-19 00:00:00
$DateTime = Get-Date -Year 2021 -Month 8 -Day 19 -Hour 0 -Minute 0 -Second 0
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -ShowHTML -DisablePasswordLastSetOlderThan $DateTime -DisableLastLogonDateOlderThan $DateTime -DeletePasswordLastSetOlderThan $DateTime -DeleteLastLogonDateOlderThan $DateTime
$Output

# this is a fresh run and it will try to disable computers according to it's defaults
# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Disable -ShowHTML -WhatIfDisable -WhatIfDelete -Delete
$Output

# this is a fresh run and it will try to delete computers according to it's defaults
# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output