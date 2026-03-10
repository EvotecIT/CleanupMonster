BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Public/Invoke-ADSIDHistoryCleanup.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Set-LoggingCapabilities {}
    function Get-GitHubVersion { param($Cmdlet, $RepositoryOwner, $RepositoryName) '0.0.0' }
    function Import-SIDHistory { param($DataStorePath, $Export) $Export }
    function Get-WinADForestDetails { @{ Forest = 'contoso.com' } }
    function Get-WinADSIDHistory { throw 'Should not be called when import fails.' }
    function Request-ADSIDHistory {}
    function Remove-ADSIDHistory {}
    function New-HTMLProcessedSIDHistory {}
    function New-EmailBodySIDHistory { param($Export) '' }
}

Describe 'Invoke-ADSIDHistoryCleanup' {
    It 'stops early when the SID-history datastore cannot be loaded' {
        Mock Import-SIDHistory { $false }
        Mock Get-WinADSIDHistory {}

        $result = Invoke-ADSIDHistoryCleanup -ReportOnly

        $result | Should -BeNullOrEmpty
        Assert-MockCalled Get-WinADSIDHistory -Times 0
    }
}
