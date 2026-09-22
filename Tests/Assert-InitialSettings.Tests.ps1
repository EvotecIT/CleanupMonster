BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Assert-InitialSettings.ps1')

    function Write-Color {
        param(
            [Parameter(ValueFromRemainingArguments = $true)] $Text,
            [object[]] $Color
        )
    }
}

Describe 'Assert-InitialSettings GraphEssentials contract' {
    BeforeEach {
        Mock Get-Module {
            [PSCustomObject] @{ Name = 'GraphEssentials'; Version = [version] '0.0.63' }
        }
        Mock Get-Command {
            param($Name)
            [PSCustomObject] @{
                Name = $Name
                ModuleName = 'GraphEssentials'
                Module = [PSCustomObject] @{ Version = [version] '0.0.63' }
            }
        }
    }

    It 'accepts both inventory commands from the new module version' {
        Assert-InitialSettings -DisableOnlyIf @{ LastSeenAzureMoreThan = 30 } | Should -BeNullOrEmpty
        Should -Invoke Get-Command -Times 2 -Exactly
    }

    It 'rejects the previous installed module version' {
        Mock Get-Module {
            [PSCustomObject] @{ Name = 'GraphEssentials'; Version = [version] '0.0.61' }
        }

        Assert-InitialSettings -DisableOnlyIf @{ LastSeenAzureMoreThan = 30 } | Should -BeFalse
    }

    It 'rejects an older command active in the session' {
        Mock Get-Command {
            param($Name)
            [PSCustomObject] @{
                Name = $Name
                ModuleName = 'GraphEssentials'
                Module = [PSCustomObject] @{ Version = [version] '0.0.61' }
            }
        }

        Assert-InitialSettings -DisableOnlyIf @{ LastSeenAzureMoreThan = 30 } | Should -BeFalse
    }
}
