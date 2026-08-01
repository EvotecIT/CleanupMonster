BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ADQueryServerCandidates.ps1')
    . (Get-CleanupMonsterPath 'Private/Test-ADQueryConfigurationError.ps1')
    . (Get-CleanupMonsterPath 'Private/Invoke-ADComputerInventoryQuery.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-InitialADComputers.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Get-ADComputer {
        [CmdletBinding()]
        param($Filter, $Properties, $SearchBase, $Server, $ResultPageSize, $ResultSetSize)
    }
    function ConvertTo-PreparedComputer {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)] $InputObject,
            $AzureInformationCache,
            $JamfInformationCache,
            [switch] $IncludeAzureAD,
            [switch] $IncludeIntune,
            [switch] $IncludeJamf,
            [DateTime] $Today
        )
        process { $InputObject }
    }
}

Describe 'AD computer inventory safety' {
    It 'marks a domain failed instead of broadening a missing per-domain filter' {
        $Report = [ordered] @{}
        $ForestInformation = [ordered] @{
            Domains         = @('contoso.com', 'child.contoso.com')
            QueryServers    = @{
                'contoso.com'       = @{ HostName = @('dc1.contoso.com') }
                'child.contoso.com' = @{ HostName = @('dc1.child.contoso.com') }
            }
            DomainsExtended = @{
                'contoso.com'       = @{ DistinguishedName = 'DC=contoso,DC=com' }
                'child.contoso.com' = @{ DistinguishedName = 'DC=child,DC=contoso,DC=com' }
            }
        }
        Mock Invoke-ADComputerInventoryQuery {
            [PSCustomObject] @{
                Succeeded = $true
                Server    = $Servers[0]
                Computers = @()
                Attempts  = @([PSCustomObject] @{ Server = $Servers[0] })
                Error     = $null
            }
        }

        $Result = Get-InitialADComputers -Report $Report -ForestInformation $ForestInformation -Filter @{ 'contoso.com' = '*' } -Properties @('SamAccountName') -Disable:$false -Move:$false -Delete:$false

        $Result.Succeeded | Should -BeFalse
        $Result.SuccessfulDomains | Should -Be @('contoso.com')
        $Result.FailedDomains | Should -Be @('child.contoso.com')
        $Report['child.contoso.com'].QueryStatus | Should -Be 'Failed'
        $Report['child.contoso.com'].QueryError | Should -Match 'No AD filter was configured'
        Assert-MockCalled Invoke-ADComputerInventoryQuery -Times 1 -Exactly
    }
}

Describe 'AD computer inventory server selection and failover' {
    It 'uses every manual server for the domain before detected fallbacks and removes duplicates' {
        $Configured = @{
            'contoso.com' = @('manual-1.contoso.com', 'manual-2.contoso.com', 'MANUAL-1.contoso.com')
        }

        $Actual = @(Get-ADQueryServerCandidates -Domain 'contoso.com' -TargetServers $Configured -DetectedServers @('auto-1.contoso.com', 'manual-2.contoso.com'))

        $Actual | Should -HaveCount 3
        $Actual[0] | Should -Be 'manual-1.contoso.com'
        $Actual[1] | Should -Be 'manual-2.contoso.com'
        $Actual[2] | Should -Be 'auto-1.contoso.com'
    }

    It 'fails over to the next domain controller after exhausting the first one' {
        Mock Get-ADComputer {
            if ($Server -eq 'dc1.contoso.com') {
                throw 'The server is not operational'
            }
            [PSCustomObject] @{ SamAccountName = 'PC01$' }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com', 'dc2.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 2 -RetryDelaySeconds 0 -PageSize 500

        $Result.Succeeded | Should -BeTrue
        $Result.Server | Should -Be 'dc2.contoso.com'
        $Result.Computers | Should -HaveCount 1
        $Result.Attempts | Should -HaveCount 3
        @($Result.Attempts | Where-Object Server -eq 'dc1.contoso.com') | Should -HaveCount 2
    }

    It 'records an explicit failed result after every domain controller fails' {
        Mock Get-ADComputer { throw 'The server is not operational' }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com', 'dc2.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 500

        $Result.Succeeded | Should -BeFalse
        $Result.Computers | Should -HaveCount 0
        $Result.Attempts | Should -HaveCount 2
        $Result.Error | Should -Be 'The server is not operational'
    }

    It 'retries a failed large-page query once with the bounded fallback page size' {
        Mock Get-ADComputer {
            if ($ResultPageSize -eq 1000) {
                throw 'invalid enumeration context'
            }
            [PSCustomObject] @{ SamAccountName = 'PC01$' }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 1000

        $Result.Succeeded | Should -BeTrue
        $Result.Attempts | Should -HaveCount 2
        $Result.Attempts[1].PageSize | Should -Be 500
    }

    It 'continues to the next domain controller after a partition error on a manual server' {
        Mock Get-ADComputer {
            if ($Server -eq 'manual.contoso.com') {
                throw 'The supplied distinguishedName must belong to one of the following partition(s)'
            }
            [PSCustomObject] @{ SamAccountName = 'PC01$' }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('manual.contoso.com', 'detected.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 500

        $Result.Succeeded | Should -BeTrue
        $Result.Server | Should -Be 'detected.contoso.com'
        $Result.Attempts | Should -HaveCount 2
    }
}
