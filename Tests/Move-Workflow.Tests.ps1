BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ADComputersToProcess.ps1')
    . (Get-CleanupMonsterPath 'Private/Request-ADComputersMove.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Write-Event { param([Parameter(ValueFromRemainingArguments = $true)] $Args) }
    function ConvertFrom-DistinguishedName {
        param(
            [string] $DistinguishedName,
            [switch] $ToDomainCN
        )

        'contoso.com'
    }
    function Move-ADObject {
        param(
            [string] $Identity,
            [string] $TargetPath
        )

        [PSCustomObject] @{
            DistinguishedName = "CN=PC1,$TargetPath"
        }
    }
    function Set-ADObject {}
}

Describe 'Move workflow helpers' {
    It 'honors MoveListProcessedMoreThan when staging move candidates' {
        $computer = [PSCustomObject] @{
            SamAccountName       = 'PC1$'
            DomainName           = 'contoso.com'
            DistinguishedName    = 'CN=PC1,OU=Workstations,DC=contoso,DC=com'
            DNSHostName          = 'pc1.contoso.com'
            OperatingSystem      = 'Windows 11'
            ServicePrincipalName = @()
            Enabled              = $false
            WhenCreated          = (Get-Date).AddYears(-1)
            OrganizationalUnit   = 'OU=Workstations,DC=contoso,DC=com'
            Action               = 'Not required'
        }
        $processedComputers = [ordered] @{
            'PC1$@contoso.com' = [PSCustomObject] @{
                SamAccountName      = 'PC1$'
                DistinguishedName   = $computer.DistinguishedName
                ActionDate          = (Get-Date).AddDays(-5)
                TimeToLeavePendingList = $null
            }
        }

        $count = Get-ADComputersToProcess -Type Move -Computers @($computer) -ActionIf @{ ListProcessedMoreThan = 10 } -Exclusions @() -ProcessedComputers $processedComputers

        $count | Should -Be 0
        $computer.Action | Should -Be 'Not required'
        $processedComputers['PC1$@contoso.com'].TimeToLeavePendingList | Should -BeGreaterThan 0
    }

    It 'recognizes the move target stored under TargetOrganizationalUnit for DisableAndMove tracking' {
        $computer = [PSCustomObject] @{
            SamAccountName       = 'PC1$'
            DomainName           = 'contoso.com'
            DistinguishedName    = 'CN=PC1,OU=Disabled,DC=contoso,DC=com'
            DNSHostName          = 'pc1.contoso.com'
            OperatingSystem      = 'Windows 11'
            ServicePrincipalName = @()
            Enabled              = $false
            WhenCreated          = (Get-Date).AddYears(-1)
            OrganizationalUnit   = 'OU=Disabled,DC=contoso,DC=com'
            Action               = 'Not required'
        }
        $processedComputers = [ordered] @{
            'PC1$@contoso.com' = [PSCustomObject] @{
                SamAccountName    = 'PC1$'
                DistinguishedName = $computer.DistinguishedName
                ActionDate        = (Get-Date).AddDays(-30)
            }
        }

        $count = Get-ADComputersToProcess -Type Disable -Computers @($computer) -ActionIf @{
            DisableAndMove           = $true
            TargetOrganizationalUnit = 'OU=Disabled,DC=contoso,DC=com'
        } -Exclusions @() -ProcessedComputers $processedComputers

        $count | Should -Be 0
        $processedComputers.Keys | Should -Contain 'PC1$@contoso.com'
    }

    It 'does not remove pending-list entries during WhatIf moves' {
        $computer = [PSCustomObject] @{
            SamAccountName                   = 'PC1$'
            DistinguishedName                = 'CN=PC1,OU=Workstations,DC=contoso,DC=com'
            OrganizationalUnit               = 'OU=Workstations,DC=contoso,DC=com'
            DistinguishedNameAfterMove       = $null
            Enabled                          = $false
            OperatingSystem                  = 'Windows 11'
            LastLogonDate                    = (Get-Date).AddDays(-30)
            LastLogonDays                    = 30
            PasswordLastSet                  = (Get-Date).AddDays(-30)
            PasswordLastChangedDays          = 30
            ProtectedFromAccidentalDeletion  = $false
            Action                           = 'Move'
            ActionDate                       = $null
            ActionStatus                     = $null
            ActionComment                    = $null
        }
        $processedComputers = [ordered] @{
            'PC1$@contoso.com' = $computer
        }
        $report = [ordered] @{
            'contoso.com' = [ordered] @{
                Server    = 'dc1.contoso.com'
                Computers = @($computer)
            }
        }

        Request-ADComputersMove -Report $report -WhatIfMove -MoveLimit 1 -ProcessedComputers $processedComputers -Today (Get-Date) -TargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com'

        $processedComputers.Keys | Should -Contain 'PC1$@contoso.com'
    }
}
