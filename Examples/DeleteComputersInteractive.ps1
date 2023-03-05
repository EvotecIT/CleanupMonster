Import-Module .\CleanupActiveDirectory.psd1 -Force


#$Output = Invoke-ADComputersCleanup -Disable -WhatIfDisable -ShowHTML
$Output = Invoke-ADComputersCleanup -Delete -WhatIfDelete -ShowHTML
#$Output = Invoke-ADComputersCleanup -Delete -WhatIf
$Output