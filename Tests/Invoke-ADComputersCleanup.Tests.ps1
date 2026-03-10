BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Public/Invoke-ADComputersCleanup.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Set-LoggingCapabilities {}
    function Set-ReportingCapabilities {}
    function Get-GitHubVersion { param($Cmdlet, $RepositoryOwner, $RepositoryName) '0.0.0' }
    function Assert-InitialSettings { $true }
    function Remove-EmptyValue {
        param(
            [hashtable] $Hashtable
        )

        foreach ($Key in @($Hashtable.Keys)) {
            if ($null -eq $Hashtable[$Key]) {
                $Hashtable.Remove($Key)
            }
        }
    }
    function Get-WinADForestDetails {
        param(
            [string] $Forest,
            [string[]] $IncludeDomains,
            [string[]] $ExcludeDomains
        )

        @{
            Domains        = @('contoso.com')
            QueryServers   = @{
                'contoso.com' = @{
                    HostName = @('dc1.contoso.com')
                }
            }
            DomainsExtended = @{
                'contoso.com' = @{
                    DistinguishedName = 'DC=contoso,DC=com'
                }
            }
        }
    }
    function Import-ComputersData { [ordered] @{} }
    function Get-InitialGraphComputers { @{ AzureAD = @{}; Intune = @{} } }
    function Get-InitialJamfComputers { @{} }
    function Get-InitialADComputers {
        param(
            [hashtable] $Report,
            [bool] $Disable,
            [bool] $Delete,
            [bool] $Move
        )

        $Report['contoso.com'] = [ordered] @{
            Server                = 'dc1.contoso.com'
            Computers             = @()
            ComputersToBeDisabled = 0
            ComputersToBeMoved    = 0
            ComputersToBeDeleted  = 0
        }

        [ordered] @{}
    }
    function Request-ADComputersDisable { @() }
    function Request-ADComputersMove { @() }
    function Request-ADComputersDelete { @() }
    function New-ADComputersStatistics { @{} }
    function New-HTMLProcessedComputers {}
    function New-EmailBodyComputers { param($CurrentRun) '' }
}

Describe 'Invoke-ADComputersCleanup' {
    It 'allows move-only runs to reach the move request' {
        Mock Get-InitialADComputers -MockWith {
            param(
                [hashtable] $Report
            )

            $Report['contoso.com'] = [ordered] @{
                Server                = 'dc1.contoso.com'
                Computers             = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved    = 1
                ComputersToBeDeleted  = 0
            }

            [ordered] @{}
        }
        Mock Request-ADComputersMove {}

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -Suppress | Out-Null

        Assert-MockCalled Request-ADComputersMove -Times 1 -Exactly
    }

    It 'treats DisableAndMove as a disable discovery workflow' {
        Mock Get-InitialADComputers -ParameterFilter { $Disable -eq $true -and $Delete -eq $false -and $Move -eq $false } -MockWith {
            param(
                [hashtable] $Report
            )

            $Report['contoso.com'] = [ordered] @{
                Server                = 'dc1.contoso.com'
                Computers             = @()
                ComputersToBeDisabled = 1
                ComputersToBeMoved    = 0
                ComputersToBeDeleted  = 0
            }

            [ordered] @{}
        }
        Mock Request-ADComputersDisable {}

        Invoke-ADComputersCleanup -DisableAndMove -DisableMoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -Suppress | Out-Null

        Assert-MockCalled Get-InitialADComputers -Times 1 -Exactly -ParameterFilter { $Disable -eq $true -and $Delete -eq $false -and $Move -eq $false }
        Assert-MockCalled Request-ADComputersDisable -Times 1 -Exactly
    }

    It 'propagates top-level WhatIf to move actions' {
        $script:CapturedMoveWhatIf = $null

        Mock Get-InitialADComputers -MockWith {
            param(
                [hashtable] $Report
            )

            $Report['contoso.com'] = [ordered] @{
                Server                = 'dc1.contoso.com'
                Computers             = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved    = 1
                ComputersToBeDeleted  = 0
            }

            [ordered] @{}
        }
        Mock Request-ADComputersMove {
            $script:CapturedMoveWhatIf = $WhatIfMove
        }

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -WhatIf -Suppress | Out-Null

        Assert-MockCalled Request-ADComputersMove -Times 1 -Exactly
        $script:CapturedMoveWhatIf | Should -BeTrue
    }
}
