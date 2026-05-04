BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ADComputersToProcess.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-ADComputersDisable.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Disable-WinADComputer {}
    function Move-WinADComputer {}
}

Describe 'Request-ADComputersDisable pending state' {
    BeforeEach {
        Mock Write-Color {}
        Mock Move-WinADComputer {
            param(
                [bool] $Success
            )

            $Success
        }
    }

    It 'does not add WhatIf disable results to the pending list' {
        Mock Disable-WinADComputer { $true }

        $processedComputers = [ordered] @{}
        $computer = [PSCustomObject] @{
            SamAccountName    = 'PC1$'
            DistinguishedName = 'CN=PC1,DC=contoso,DC=com'
            Action            = 'Disable'
            ActionStatus      = $null
            ActionDate        = $null
        }
        $report = [ordered] @{
            'contoso.com' = [ordered] @{
                Server    = 'dc1.contoso.com'
                Computers = @($computer)
            }
        }

        $result = @(Request-ADComputersDisable -Report $report -ProcessedComputers $processedComputers -DisableOnlyIf @{} -DisableLimit 1 -Today (Get-Date) -WhatIfDisable)

        $result | Should -HaveCount 1
        $result[0].ActionStatus | Should -Be 'WhatIf'
        $processedComputers.Count | Should -Be 0
    }

    It 'does not add failed disable results to the pending list' {
        Mock Disable-WinADComputer { $false }

        $processedComputers = [ordered] @{}
        $computer = [PSCustomObject] @{
            SamAccountName    = 'PC2$'
            DistinguishedName = 'CN=PC2,DC=contoso,DC=com'
            Action            = 'Disable'
            ActionStatus      = $null
            ActionDate        = $null
        }
        $report = [ordered] @{
            'contoso.com' = [ordered] @{
                Server    = 'dc1.contoso.com'
                Computers = @($computer)
            }
        }

        $result = @(Request-ADComputersDisable -Report $report -ProcessedComputers $processedComputers -DisableOnlyIf @{} -DisableLimit 1 -Today (Get-Date))

        $result | Should -HaveCount 1
        $result[0].ActionStatus | Should -BeFalse
        $processedComputers.Count | Should -Be 0
    }

    It 'adds successful real disable results to the pending list' {
        Mock Disable-WinADComputer { $true }

        $processedComputers = [ordered] @{}
        $computer = [PSCustomObject] @{
            SamAccountName    = 'PC3$'
            DistinguishedName = 'CN=PC3,DC=contoso,DC=com'
            Action            = 'Disable'
            ActionStatus      = $null
            ActionDate        = $null
        }
        $report = [ordered] @{
            'contoso.com' = [ordered] @{
                Server    = 'dc1.contoso.com'
                Computers = @($computer)
            }
        }

        Request-ADComputersDisable -Report $report -ProcessedComputers $processedComputers -DisableOnlyIf @{} -DisableLimit 1 -Today (Get-Date) | Out-Null

        $processedComputers.Keys | Should -Contain 'PC3$@contoso.com'
        $processedComputers['PC3$@contoso.com'].ActionStatus | Should -BeTrue
    }

    It 'does not promote pending records that were not successful real actions' {
        $computer = [PSCustomObject] @{
            SamAccountName       = 'PC4$'
            DomainName           = 'contoso.com'
            DistinguishedName    = 'CN=PC4,DC=contoso,DC=com'
            DNSHostName          = 'pc4.contoso.com'
            OperatingSystem      = 'Windows 11'
            ServicePrincipalName = @()
            Enabled              = $false
            Action               = 'Not required'
        }
        $processedComputers = [ordered] @{
            'PC4$@contoso.com' = [PSCustomObject] @{
                SamAccountName = 'PC4$'
                ActionStatus   = 'WhatIf'
                ActionDate     = (Get-Date).AddDays(-45)
            }
        }

        $count = Get-ADComputersToProcess -Type Delete -Computers @($computer) -ActionIf @{ ListProcessedMoreThan = 30 } -Exclusions @() -ProcessedComputers $processedComputers

        $count | Should -Be 0
        $computer.Action | Should -Be 'Not required'
    }
}
