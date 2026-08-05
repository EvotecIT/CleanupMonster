BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Assert-CloudDeviceCleanupSettings.ps1')

    function Write-Color {
        param(
            [Parameter(ValueFromRemainingArguments = $true)]
            $Text,
            [object[]] $Color
        )
    }
}

Describe 'Assert-CloudDeviceCleanupSettings' {
    BeforeEach {
        Mock Get-Module {
            [PSCustomObject] @{
                Name    = 'GraphEssentials'
                Version = [version] '0.0.57'
            }
        }
        Mock Get-Command {
            param($Name)
            [PSCustomObject] @{
                Name       = $Name
                ModuleName = 'GraphEssentials'
                Module     = [PSCustomObject] @{
                    Version = [version] '0.0.57'
                }
            }
        }
    }

    It 'accepts the GraphEssentials release that provides lifecycle projection' {
        Assert-CloudDeviceCleanupSettings | Should -BeTrue
    }

    It 'rejects the preceding installed GraphEssentials version' {
        Mock Get-Module {
            [PSCustomObject] @{
                Name    = 'GraphEssentials'
                Version = [version] '0.0.56'
            }
        }

        Assert-CloudDeviceCleanupSettings | Should -BeFalse
    }

    It 'rejects an older GraphEssentials command already active in the session' {
        Mock Get-Command {
            param($Name)
            [PSCustomObject] @{
                Name       = $Name
                ModuleName = 'GraphEssentials'
                Module     = [PSCustomObject] @{
                    Version = [version] '0.0.56'
                }
            }
        }

        Assert-CloudDeviceCleanupSettings | Should -BeFalse
    }
}
