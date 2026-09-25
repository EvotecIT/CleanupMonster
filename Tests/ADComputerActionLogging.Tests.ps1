BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ADComputerSelectionReason.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-ADComputersToProcess.ps1')
    . (Get-CleanupMonsterPath 'Private/Write-ADComputerActionLog.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-ADComputersMove.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-ADComputersDelete.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-ADComputerReportOutcome.ps1')

    function Write-Color {
        param([string[]] $Text, [object[]] $Color, [string] $LogFile)
        $script:actionLogLines.Add([pscustomobject] @{ Text = ($Text -join ''); LogFile = $LogFile })
    }
    function ConvertFrom-DistinguishedName { param($DistinguishedName, [switch] $ToDomainCN) 'contoso.com' }
    function Set-ADObject {}
}

Describe 'AD computer action reasons' {
    BeforeEach {
        $script:actionLogLines = [System.Collections.Generic.List[object]]::new()
    }

    It 'shows the observed AD, cloud, and pending ages against the configured rules' {
        $today = Get-Date
        $computer = [pscustomobject] @{
            LastLogonDays          = 210
            PasswordLastChangedDays = 205
            AzureLastSeenDays      = 190
            IntuneLastSeenDays     = 195
            Enabled                = $false
        }
        $processedComputer = [pscustomobject] @{ ActionDate = $today.AddDays(-96) }
        $actionIf = [ordered] @{
            LastLogonDateMoreThan   = 180
            PasswordLastSetMoreThan = 180
            LastSeenAzureMoreThan   = 180
            LastSeenIntuneMoreThan  = 180
            ListProcessedMoreThan   = 90
            IsEnabled               = $false
        }

        $reason = Get-ADComputerSelectionReason -Computer $computer -ActionIf $actionIf -ProcessedComputer $processedComputer -IncludeAzureAD -IncludeIntune -Today $today

        $reason | Should -Match 'LastLogonDays=210 \(LastLogonDateMoreThan=180\)'
        $reason | Should -Match 'PasswordLastChangedDays=205 \(PasswordLastSetMoreThan=180\)'
        $reason | Should -Match 'AzureLastSeenDays=190 \(LastSeenAzureMoreThan=180\)'
        $reason | Should -Match 'IntuneLastSeenDays=195 \(LastSeenIntuneMoreThan=180\)'
        $reason | Should -Match 'PendingDays=96 \(ListProcessedMoreThan=90\)'
        $reason | Should -Match 'Enabled=False \(IsEnabled=False\)'
    }

    It 'attaches a reason only after a computer passes action selection' {
        $stale = [pscustomobject] @{
            SamAccountName       = 'STALE$'
            DomainName           = 'contoso.com'
            DistinguishedName    = 'CN=STALE,DC=contoso,DC=com'
            Enabled              = $true
            LastLogonDate        = (Get-Date).AddDays(-210)
            LastLogonDays        = 210
            OperatingSystem      = 'Windows 11'
            ServicePrincipalName = @()
            Action               = 'Not required'
        }
        $recent = [pscustomobject] @{
            SamAccountName       = 'RECENT$'
            DomainName           = 'contoso.com'
            DistinguishedName    = 'CN=RECENT,DC=contoso,DC=com'
            Enabled              = $true
            LastLogonDate        = (Get-Date).AddDays(-5)
            LastLogonDays        = 5
            OperatingSystem      = 'Windows 11'
            ServicePrincipalName = @()
            Action               = 'Not required'
        }

        $count = Get-ADComputersToProcess -Type Disable -Computers @($stale, $recent) -ActionIf @{ LastLogonDateMoreThan = 90 } -Exclusions @() -ProcessedComputers ([ordered] @{})

        $count | Should -Be 1
        $stale.SelectionReason | Should -Match 'LastLogonDays=210 \(LastLogonDateMoreThan=90\)'
        $recent.PSObject.Properties['SelectionReason'] | Should -BeNullOrEmpty
    }

    It 'includes zero-day Intune rules and the matching SPN in the reason' {
        $computer = [pscustomobject] @{
            IntuneLastSeenDays     = 1
            ServicePrincipalName  = @('HOST/PC1', 'HTTP/PC1')
        }
        $actionIf = [ordered] @{
            LastSeenIntuneMoreThan    = 0
            IncludeServicePrincipalName = @('HTTP/*')
        }

        $reason = Get-ADComputerSelectionReason -Computer $computer -ActionIf $actionIf -IncludeIntune

        $reason | Should -Match 'IntuneLastSeenDays=1 \(LastSeenIntuneMoreThan=0\)'
        $reason | Should -Match 'ServicePrincipalName=HTTP/PC1 \(IncludeServicePrincipalName=HTTP/\*\)'
    }

    It 'does not log protected move and delete candidates when no AD action call was reached' {
        $computer = [pscustomobject] @{
            SamAccountName                  = 'PC1$'
            DistinguishedName               = 'CN=PC1,OU=Workstations,DC=contoso,DC=com'
            OrganizationalUnit              = 'OU=Workstations,DC=contoso,DC=com'
            ProtectedFromAccidentalDeletion = $true
            Action                          = 'Move'
            ActionStatus                    = $null
            ActionDate                      = $null
            SelectionReason                 = 'PendingDays=95 (ListProcessedMoreThan=90)'
        }
        $report = [ordered] @{ 'contoso.com' = [ordered] @{ Server = 'dc1.contoso.com'; Computers = @($computer) } }

        $moveResult = @(Request-ADComputersMove -Report $report -WhatIfMove -MoveLimit 1 -ProcessedComputers ([ordered] @{}) -Today (Get-Date) -TargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -DontWriteToEventLog)
        $moveResult[0].ActionStatus | Should -Be 'WhatIf'
        $moveResult[0].ActionAttempted | Should -Not -BeTrue
        $script:actionLogLines.Clear()
        Write-ADComputerActionLog -Action Move -Results $moveResult
        $script:actionLogLines.Count | Should -Be 0

        $computer.Action = 'Delete'
        $deleteResult = @(Request-ADComputersDelete -Report $report -WhatIfDelete -DeleteLimit 1 -ProcessedComputers ([ordered] @{}) -Today (Get-Date) -DontWriteToEventLog)
        $deleteResult[0].ActionStatus | Should -Be 'WhatIf'
        $deleteResult[0].ActionAttempted | Should -Not -BeTrue
        $script:actionLogLines.Clear()
        Write-ADComputerActionLog -Action Delete -Results $deleteResult
        $script:actionLogLines.Count | Should -Be 0
    }

    It 'records a failed protection-removal call as an attempted move' {
        Mock Set-ADObject { throw 'Protection update denied' }
        $computer = [pscustomobject] @{
            SamAccountName = 'PC1$'; DistinguishedName = 'CN=PC1,OU=Workstations,DC=contoso,DC=com'
            OrganizationalUnit = 'OU=Workstations,DC=contoso,DC=com'; ProtectedFromAccidentalDeletion = $true
            Action = 'Move'; ActionComment = $null; ActionStatus = $null; ActionDate = $null
        }
        $report = [ordered] @{ 'contoso.com' = [ordered] @{ Server = 'dc1.contoso.com'; Computers = @($computer) } }

        $result = @(Request-ADComputersMove -Report $report -MoveLimit 1 -ProcessedComputers ([ordered] @{}) -Today (Get-Date) -TargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -RemoveProtectedFromAccidentalDeletionFlag -DontWriteToEventLog)

        $result[0].ActionAttempted | Should -BeTrue
        $result[0].ActionStatus | Should -BeFalse
        $result[0].ActionComment | Should -Match 'Protection update denied'
        (Get-ADComputerReportOutcome -Computer $result[0]).Label | Should -Be 'Failed'
        Write-ADComputerActionLog -Action Move -Results $result
        $script:actionLogLines[-1].Text | Should -Match 'Move failed.*Protection update denied'
    }

    It 'records a failed protection-removal call as an attempted WhatIf delete' {
        Mock Set-ADObject { throw 'Protection update denied' }
        $computer = [pscustomobject] @{
            SamAccountName = 'PC1$'; DistinguishedName = 'CN=PC1,OU=Workstations,DC=contoso,DC=com'
            ProtectedFromAccidentalDeletion = $true; Action = 'Delete'; ActionComment = $null; ActionStatus = $null; ActionDate = $null
        }
        $report = [ordered] @{ 'contoso.com' = [ordered] @{ Server = 'dc1.contoso.com'; Computers = @($computer) } }

        $result = @(Request-ADComputersDelete -Report $report -WhatIfDelete -DeleteLimit 1 -ProcessedComputers ([ordered] @{}) -Today (Get-Date) -RemoveProtectedFromAccidentalDeletionFlag -DontWriteToEventLog)

        $result[0].ActionAttempted | Should -BeTrue
        $result[0].ActionStatus | Should -Be 'WhatIf'
        $result[0].ActionComment | Should -Match 'Protection update denied'
        (Get-ADComputerReportOutcome -Computer $result[0]).Label | Should -Be 'WhatIf error'
        Write-ADComputerActionLog -Action Delete -Results $result
        $script:actionLogLines[-1].Text | Should -Match 'Delete WhatIf attempted with error.*Protection update denied'
    }

    It 'logs only attempted and WhatIf actions with their reason to the configured file' {
        $results = @(
            [pscustomobject] @{ SamAccountName = 'PC1$'; DistinguishedName = 'CN=PC1,DC=contoso,DC=com'; ActionDate = (Get-Date); ActionStatus = 'WhatIf'; ActionAttempted = $true; SelectionReason = 'LastLogonDays=210 (LastLogonDateMoreThan=180)' },
            [pscustomobject] @{ SamAccountName = 'PC2$'; DistinguishedName = 'CN=PC2,DC=contoso,DC=com'; ActionDate = $null; ActionStatus = $null; SelectionReason = 'LastLogonDays=220 (LastLogonDateMoreThan=180)' },
            [pscustomobject] @{ SamAccountName = 'PC3$'; DistinguishedName = 'CN=PC3,DC=contoso,DC=com'; ActionDate = (Get-Date); ActionStatus = 'ReportOnly'; SelectionReason = 'LastLogonDays=230 (LastLogonDateMoreThan=180)' }
        )

        Write-ADComputerActionLog -Action Disable -Results $results -LogPath 'C:\Logs\Cleanup.log'

        $script:actionLogLines.Count | Should -Be 1
        $script:actionLogLines[0].Text | Should -Match 'Disable WhatIf preview.*PC1.*LastLogonDays=210'
        $script:actionLogLines[0].LogFile | Should -Be 'C:\Logs\Cleanup.log'
    }

    It 'reports partial disable-and-move outcomes without claiming both steps completed' {
        $results = @(
            [pscustomobject] @{ SamAccountName = 'PC1$'; DistinguishedName = 'CN=PC1,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = $false; DisableActionResult = 'True'; MoveActionResult = 'False'; SelectionReason = 'LastLogonDays=210 (LastLogonDateMoreThan=180)' },
            [pscustomobject] @{ SamAccountName = 'PC2$'; DistinguishedName = 'CN=PC2,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = $true; DisableActionResult = $null; MoveActionResult = 'True'; SelectionReason = 'LastLogonDays=220 (LastLogonDateMoreThan=180)' }
        )

        Write-ADComputerActionLog -Action DisableAndMove -Results $results

        $script:actionLogLines.Count | Should -Be 2
        $script:actionLogLines[0].Text | Should -Match 'DisableAndMove partially completed.*Disable=True; Move=False'
        $script:actionLogLines[1].Text | Should -Match 'DisableAndMove partially completed.*Disable=NotAttempted; Move=True'
    }

    It 'logs composite actions with an already-satisfied step as complete' {
        $results = @(
            [pscustomobject] @{ SamAccountName = 'PC1$'; DistinguishedName = 'CN=PC1,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = $true; DisableActionResult = 'AlreadySatisfied'; MoveActionResult = 'True' },
            [pscustomobject] @{ SamAccountName = 'PC2$'; DistinguishedName = 'CN=PC2,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = $true; DisableActionResult = 'True'; MoveActionResult = 'AlreadySatisfied'; ActionComment = 'Metadata failed' }
        )

        Write-ADComputerActionLog -Action DisableAndMove -Results $results

        $script:actionLogLines[0].Text | Should -Match 'DisableAndMove completed.*Disable=AlreadySatisfied; Move=True'
        $script:actionLogLines[1].Text | Should -Match 'DisableAndMove completed with issue.*Metadata failed'
    }

    It 'logs a WhatIf composite with one already-satisfied step as a preview' {
        $result = [pscustomobject] @{ SamAccountName = 'PC3$'; DistinguishedName = 'CN=PC3,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = 'WhatIf'; DisableActionResult = 'AlreadySatisfied'; MoveActionResult = 'WhatIf' }

        Write-ADComputerActionLog -Action DisableAndMove -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'DisableAndMove WhatIf preview.*Disable=AlreadySatisfied; Move=WhatIf'
    }

    It 'logs metadata-only WhatIf on an already-satisfied composite as a preview' {
        $result = [pscustomobject] @{ SamAccountName = 'PC10$'; DistinguishedName = 'CN=PC10,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = 'WhatIf'; DisableActionResult = 'AlreadySatisfied'; MoveActionResult = 'AlreadySatisfied' }

        Write-ADComputerActionLog -Action DisableAndMove -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'DisableAndMove WhatIf preview.*Disable=AlreadySatisfied; Move=AlreadySatisfied'
    }

    It 'labels a failed WhatIf attempt as an error' {
        $result = [pscustomobject] @{
            SamAccountName       = 'PC3$'
            DistinguishedName    = 'CN=PC3,DC=contoso,DC=com'
            ActionAttempted      = $true
            ActionStatus         = 'WhatIf'
            ActionComment        = 'Access denied'
            SelectionReason      = 'LastLogonDays=210 (LastLogonDateMoreThan=180)'
        }

        Write-ADComputerActionLog -Action Disable -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'Disable WhatIf attempted with error.*Access denied'
    }

    It 'labels a completed AD action with a later metadata error for review' {
        $result = [pscustomobject] @{ SamAccountName = 'PC5$'; DistinguishedName = 'CN=PC5,DC=contoso,DC=com'; ActionAttempted = $true; ActionStatus = $true; ActionComment = 'Description update failed' }

        Write-ADComputerActionLog -Action Disable -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'Disable completed with issue.*Description update failed'
    }

    It 'logs a failed metadata call when the disable step was already satisfied' {
        $result = [pscustomobject] @{
            SamAccountName = 'PC9$'; DistinguishedName = 'CN=PC9,DC=contoso,DC=com'
            ActionAttempted = $true; ActionStatus = $true; ActionComment = 'Description update denied'
            DisableActionResult = 'AlreadySatisfied'
        }

        Write-ADComputerActionLog -Action Disable -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'Disable completed with issue.*Description update denied'
    }

    It 'does not log one previewed step as a complete disable-and-move preview' {
        $result = [pscustomobject] @{
            SamAccountName      = 'PC4$'
            DistinguishedName   = 'CN=PC4,DC=contoso,DC=com'
            ActionAttempted     = $true
            ActionStatus        = 'WhatIf'
            DisableActionResult = 'WhatIf'
            MoveActionResult    = $null
        }

        Write-ADComputerActionLog -Action DisableAndMove -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'DisableAndMove incomplete WhatIf preview.*Disable=WhatIf; Move=NotAttempted'
    }

    It 'retains WhatIf context when the first composite step fails' {
        $result = [pscustomobject] @{
            SamAccountName = 'PC8$'; DistinguishedName = 'CN=PC8,DC=contoso,DC=com'
            ActionAttempted = $true; ActionStatus = 'WhatIf'; ActionComment = 'Access denied'
            DisableActionResult = 'False'; MoveActionResult = $null
        }

        Write-ADComputerActionLog -Action DisableAndMove -Results @($result)

        $script:actionLogLines[0].Text | Should -Match 'DisableAndMove WhatIf attempted with error.*Disable=False; Move=NotAttempted.*Access denied'
    }
}
