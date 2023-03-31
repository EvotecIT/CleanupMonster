Import-Module .\CleanupActiveDirectory.psd1 -Force

# this is a fresh run and it will provide report only according to it's defaults
$Output = Invoke-ADComputersCleanup -WhatIf -ReportOnly -Disable -Delete -ShowHTML
$Output

# this is a fresh run and it will try to disable computers according to it's defaults
# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Disable -ShowHTML -WhatIfDisable -WhatIfDelete -Delete
$Output

# this is a fresh run and it will try to delete computers according to it's defaults
# read documentation to understand what it does
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML -LogPath $PSScriptRoot\Logs\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).log -ReportPath $PSScriptRoot\Reports\DeleteComputers_$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss')).html
$Output