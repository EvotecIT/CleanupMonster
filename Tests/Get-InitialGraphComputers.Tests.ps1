BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-InitialGraphComputers.ps1')

    function Get-MyDevice {
        param([switch] $Synchronized, $PropertySet, $WarningAction, $WarningVariable)
    }
    function Get-MyDeviceIntune {
        param([switch] $Synchronized, $PropertySet, $WarningAction, $WarningVariable)
    }
    function Write-Color { param([Parameter(ValueFromRemainingArguments)] $Values) }
}

Describe 'Get-InitialGraphComputers' {
    It 'requests compact complete inventories for synchronized AD computers' {
        Mock Get-MyDevice {
            [PSCustomObject] @{
                Name = 'DEVICE-01'
                LastSeenDays = 31
                LastSynchronizedDays = 30
                OwnerUserPrincipalName = @('owner@example.com')
            }
        }
        Mock Get-MyDeviceIntune {
            [PSCustomObject] @{
                Name = 'DEVICE-01'
                LastSeenDays = 29
                UserPrincipalName = 'owner@example.com'
            }
        }
        Mock Write-Color {}

        $result = Get-InitialGraphComputers -DisableLastSeenAzureMoreThan 90 -DisableLastSeenIntuneMoreThan 90

        $result.AzureAD['DEVICE-01'].OwnerUserPrincipalName | Should -Be @('owner@example.com')
        $result.Intune['DEVICE-01'].UserPrincipalName | Should -Be 'owner@example.com'
        Should -Invoke Get-MyDevice -Times 1 -Exactly -ParameterFilter {
            $Synchronized -and $PropertySet -eq 'Computer'
        }
        Should -Invoke Get-MyDeviceIntune -Times 1 -Exactly -ParameterFilter {
            $Synchronized -and $PropertySet -eq 'Computer'
        }
    }

    It 'stops if the compact Entra inventory is incomplete' {
        Mock Get-MyDevice { Write-Warning 'Graph inventory page 2 failed' }
        Mock Get-MyDeviceIntune {}
        Mock Write-Color {}

        $result = Get-InitialGraphComputers -DisableLastSeenAzureMoreThan 90

        $result | Should -BeFalse
        Should -Invoke Get-MyDeviceIntune -Times 0 -Exactly
    }
}
