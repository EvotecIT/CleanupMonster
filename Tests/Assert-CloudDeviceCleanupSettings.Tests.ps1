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
                Version = [version] '0.0.65'
            }
        }
        Mock Get-Command {
            param($Name)
            [PSCustomObject] @{
                Name       = $Name
                ModuleName = 'GraphEssentials'
                Module     = [PSCustomObject] @{
                    Version = [version] '0.0.65'
                }
            }
        }
    }

    It 'accepts the GraphEssentials release that provides fail-closed cloud paging' {
        Assert-CloudDeviceCleanupSettings | Should -BeTrue
    }

    It 'rejects the preceding installed GraphEssentials version without cloud paging' {
        Mock Get-Module {
            [PSCustomObject] @{
                Name    = 'GraphEssentials'
                Version = [version] '0.0.64'
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
                    Version = [version] '0.0.64'
                }
            }
        }

        Assert-CloudDeviceCleanupSettings | Should -BeFalse
    }

    It 'rejects an older Entra inventory command while Intune inventory is current' {
        Mock Get-Command {
            param($Name)
            [PSCustomObject] @{
                Name       = $Name
                ModuleName = 'GraphEssentials'
                Module     = [PSCustomObject] @{
                    Version = if ($Name -eq 'Get-MyDevice') { [version] '0.0.64' } else { [version] '0.0.65' }
                }
            }
        }

        Assert-CloudDeviceCleanupSettings | Should -BeFalse
    }
}
