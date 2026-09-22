BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-InitialGraphComputers.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Get-MyDevice {
        [CmdletBinding()]
        param([switch] $Synchronized, [string] $PropertySet, [switch] $ReportProgress)
    }
    function Get-MyDeviceIntune {
        [CmdletBinding()]
        param([switch] $Synchronized, [string] $PropertySet, [switch] $ReportProgress)
    }
}

Describe 'Get-InitialGraphComputers' {
    It 'requests paged computer inventory with transcript progress before building the cache' {
        $script:logLines = [System.Collections.Generic.List[string]]::new()
        Mock Write-Color { $script:logLines.Add((ConvertTo-Json -InputObject $Text -Compress -Depth 6)) }
        Mock Get-MyDevice {
            Write-Information -MessageData 'Graph inventory: 2 records across 1 page(s); complete.' -InformationAction Continue
            @(
                [PSCustomObject] @{ Name = 'COMPUTER-01'; LastSeenDays = 120 }
                [PSCustomObject] @{ Name = 'COMPUTER-02'; LastSeenDays = 150 }
            )
        }

        $result = Get-InitialGraphComputers -DisableLastSeenAzureMoreThan 90 -SafetyAzureADLimit 2

        Should -Invoke Get-MyDevice -Times 1 -Exactly -ParameterFilter {
            $Synchronized -and $PropertySet -eq 'Computer' -and $ReportProgress
        }
        $result.AzureAD.Count | Should -Be 2
        $result.AzureAD['COMPUTER-01'].LastSeenDays | Should -Be 120
        ($script:logLines -join "`n") | Should -Match 'Graph inventory: 2 records across 1 page'
    }

    It 'requests paged Intune computer inventory with transcript progress before building the cache' {
        $script:logLines = [System.Collections.Generic.List[string]]::new()
        Mock Write-Color { $script:logLines.Add((ConvertTo-Json -InputObject $Text -Compress -Depth 6)) }
        Mock Get-MyDeviceIntune {
            Write-Information -MessageData 'Graph inventory: 2 Intune records; complete.' -InformationAction Continue
            @(
                [PSCustomObject] @{ Name = 'COMPUTER-01'; LastSeenDays = 20; UserPrincipalName = 'owner@example.com' }
                [PSCustomObject] @{ Name = 'COMPUTER-02'; LastSeenDays = 130; UserPrincipalName = 'other@example.com' }
            )
        }

        $result = Get-InitialGraphComputers -DisableLastSeenIntuneMoreThan 90 -SafetyIntuneLimit 2

        Should -Invoke Get-MyDeviceIntune -Times 1 -Exactly -ParameterFilter {
            $Synchronized -and $PropertySet -eq 'Computer' -and $ReportProgress
        }
        $result.Intune.Count | Should -Be 2
        $result.Intune['COMPUTER-01'].UserPrincipalName | Should -Be 'owner@example.com'
        ($script:logLines -join "`n") | Should -Match 'Graph inventory: 2 Intune records'
    }

    It 'rejects an incomplete Entra inventory even if records arrived before the warning' {
        Mock Get-MyDevice {
            [PSCustomObject] @{ Name = 'COMPUTER-01'; LastSeenDays = 120 }
            Write-Warning 'Later Graph page failed'
        }

        $result = Get-InitialGraphComputers -DisableLastSeenAzureMoreThan 90 -SafetyAzureADLimit 1

        $result | Should -BeFalse
    }
}
