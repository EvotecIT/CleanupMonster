BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"

    $Public = Get-CleanupMonsterPath 'Public/Invoke-ADServiceAccountsCleanup.ps1'
    $Private = Get-ChildItem -Path (Get-CleanupMonsterPath 'Private') -Filter '*ServiceAccounts*.ps1'
    . $Public
    foreach ($P in $Private) { . $P.FullName }

    function Write-Color { param([Parameter(ValueFromRemainingArguments=$true)]$Text,[object[]]$Color) }
    function Set-LoggingCapabilities {}
    function Get-GitHubVersion { param($Cmdlet,$RepositoryOwner,$RepositoryName) '0.0.0' }
    function Get-WinADForestDetails { param([string]$Forest,[string[]]$IncludeDomains,[string[]]$ExcludeDomains) @{ Domains=@('domain.local'); QueryServers=@{ 'domain.local'=@{ HostName=@('localhost') } }; DomainsExtended=@{}; Forest='domain.local' } }
    function Get-ADServiceAccount { param([string]$Filter,[string]$Server,[string[]]$Properties) @() }
    function Disable-ADAccount {}
    function Remove-ADObject {}
    function New-HTML { param([scriptblock]$Body,[string]$FilePath,[switch]$Online,[switch]$ShowHTML) & $Body }
    function New-HTMLProcessedServiceAccounts {}
}

Describe 'Invoke-ADServiceAccountsCleanup' {
    It 'exports the function' {
        Get-Command Invoke-ADServiceAccountsCleanup -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }
    It 'filters service accounts by last logon date' {
        $acc1 = [pscustomobject]@{ SamAccountName='gmsa1'; DistinguishedName='CN=gmsa1,DC=lab,DC=local'; LastLogonDate=(Get-Date).AddDays(-100); PasswordLastSet=(Get-Date).AddDays(-100); WhenCreated=(Get-Date).AddYears(-1) }
        $acc2 = [pscustomobject]@{ SamAccountName='gmsa2'; DistinguishedName='CN=gmsa2,DC=lab,DC=local'; LastLogonDate=(Get-Date).AddDays(-5); PasswordLastSet=(Get-Date).AddDays(-5); WhenCreated=(Get-Date).AddDays(-10) }
        $res = Get-ADServiceAccountsToProcess -Type 'Disable' -Accounts @($acc1,$acc2) -ActionIf @{ LastLogonDateMoreThan = 30 }
        $res.SamAccountName | Should -Be @('gmsa1')
    }
    It 'supports WhatIf' {
        { Invoke-ADServiceAccountsCleanup -Disable -ReportOnly -WhatIfDisable } | Should -Not -Throw
    }
    It 'generates HTML report when ReportPath is specified' {
        Mock -CommandName New-HTMLProcessedServiceAccounts
        Invoke-ADServiceAccountsCleanup -Disable -ReportOnly -ReportPath 'out.html'
        Assert-MockCalled New-HTMLProcessedServiceAccounts -Times 1
    }

    It 'respects include and exclude account patterns' {
        Mock -CommandName Get-ADServiceAccount -MockWith {
            @(
                [pscustomobject]@{ SamAccountName='gmsa1'; DistinguishedName='CN=gmsa1,DC=lab,DC=local'; LastLogonDate=$null; PasswordLastSet=$null; WhenCreated=$null },
                [pscustomobject]@{ SamAccountName='gmsa2'; DistinguishedName='CN=gmsa2,DC=lab,DC=local'; LastLogonDate=$null; PasswordLastSet=$null; WhenCreated=$null }
            )
        }
        $forest = @{ Domains=@('lab.local'); QueryServers=@{ 'lab.local'=@{ HostName=@('dc1') } } }
        $report = Get-InitialADServiceAccounts -ForestInformation $forest -IncludeAccounts @('gmsa*') -ExcludeAccounts @('gmsa2')
        $report['lab.local'].Accounts.SamAccountName | Should -Be @('gmsa1')
    }

    It 'does not delete accounts that are already scheduled for disable in the same run' {
        Mock -CommandName Get-ADServiceAccount -MockWith {
            @(
                [pscustomobject]@{
                    SamAccountName   = 'gmsa1'
                    DistinguishedName = 'CN=gmsa1,DC=domain,DC=local'
                    LastLogonDate    = (Get-Date).AddDays(-120)
                    PasswordLastSet  = (Get-Date).AddDays(-120)
                    WhenCreated      = (Get-Date).AddYears(-1)
                }
            )
        }

        $result = Invoke-ADServiceAccountsCleanup -Disable -Delete -DisableLastLogonDateMoreThan 30 -DeleteLastLogonDateMoreThan 30 -ReportOnly

        $result.CurrentRun.Count | Should -Be 1
        $result.CurrentRun[0].Action | Should -Be 'Disable'
        $result.CurrentRun[0].SamAccountName | Should -Be 'gmsa1'
    }

    It 'limits disable actions to one account by default' {
        Mock -CommandName Get-ADServiceAccount -MockWith {
            @(
                [pscustomobject]@{
                    SamAccountName    = 'gmsa1'
                    DistinguishedName = 'CN=gmsa1,DC=domain,DC=local'
                    LastLogonDate     = (Get-Date).AddDays(-120)
                    PasswordLastSet   = (Get-Date).AddDays(-120)
                    WhenCreated       = (Get-Date).AddYears(-1)
                }
                [pscustomobject]@{
                    SamAccountName    = 'gmsa2'
                    DistinguishedName = 'CN=gmsa2,DC=domain,DC=local'
                    LastLogonDate     = (Get-Date).AddDays(-120)
                    PasswordLastSet   = (Get-Date).AddDays(-120)
                    WhenCreated       = (Get-Date).AddYears(-1)
                }
            )
        }
        Mock -CommandName Disable-ADAccount {}

        $result = Invoke-ADServiceAccountsCleanup -Disable -DisableLastLogonDateMoreThan 30

        $result.CurrentRun | Should -HaveCount 1
        $result.CurrentRun[0].SamAccountName | Should -Be 'gmsa1'
    }

    It 'stops processing when SafetyADLimit is not met' {
        Mock -CommandName Get-ADServiceAccount -MockWith {
            @(
                [pscustomobject]@{
                    SamAccountName    = 'gmsa1'
                    DistinguishedName = 'CN=gmsa1,DC=domain,DC=local'
                    LastLogonDate     = (Get-Date).AddDays(-120)
                    PasswordLastSet   = (Get-Date).AddDays(-120)
                    WhenCreated       = (Get-Date).AddYears(-1)
                }
            )
        }
        Mock -CommandName Disable-ADAccount {}

        $result = Invoke-ADServiceAccountsCleanup -Disable -DisableLastLogonDateMoreThan 30 -SafetyADLimit 2

        $result | Should -BeNullOrEmpty
        Assert-MockCalled Disable-ADAccount -Times 0
    }
}
