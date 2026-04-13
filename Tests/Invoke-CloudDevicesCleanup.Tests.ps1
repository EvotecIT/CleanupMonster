BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Public/Invoke-CloudDevicesCleanup.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Set-LoggingCapabilities {}
    function Set-ReportingCapabilities {}
    function Get-GitHubVersion { param($Cmdlet, $RepositoryOwner, $RepositoryName) '0.0.0' }
    function Assert-CloudDeviceCleanupSettings { $true }
    function Import-CloudDevicesData { [ordered] @{} }
    function Get-InitialCloudDevices { @() }
    function Get-CloudDevicesToProcess { @() }
    function Request-CloudDevicesRetire { @() }
    function Request-CloudDevicesDisable { @() }
    function Request-CloudDevicesDelete { @() }
    function New-HTMLProcessedCloudDevices {}
    function New-EmailBodyCloudDevices { param($CurrentRun) '' }
}

Describe 'Invoke-CloudDevicesCleanup' {
    It 'retires stale cloud devices when retire mode is enabled' {
        Mock Get-InitialCloudDevices {
            @(
                [PSCustomObject] @{
                    Name                 = 'iPhone-01'
                    EntraDeviceObjectId  = 'entra-1'
                    ManagedDeviceId      = 'managed-1'
                    DeviceId             = 'device-1'
                    HasEntraRecord       = $true
                    HasIntuneRecord      = $true
                    Enabled              = $true
                    OperatingSystem      = 'iOS'
                    ManagedDeviceOwnerType = 'personal'
                    IntuneLastSeenDays   = 150
                    EntraLastSeenDays    = 150
                }
            )
        }
        Mock Get-CloudDevicesToProcess {
            @(
                [PSCustomObject] @{
                    Name                = 'iPhone-01'
                    EntraDeviceObjectId = 'entra-1'
                    ManagedDeviceId     = 'managed-1'
                    DeviceId            = 'device-1'
                    HasEntraRecord      = $true
                    HasIntuneRecord     = $true
                    ProcessedDeviceKey  = 'entra:entra-1'
                }
            )
        } -ParameterFilter { $Type -eq 'Retire' }
        Mock Request-CloudDevicesRetire {
            @(
                [PSCustomObject] @{
                    Name         = 'iPhone-01'
                    Action       = 'Retire'
                    ActionStatus = 'True'
                }
            )
        }

        Invoke-CloudDevicesCleanup -Retire -Suppress | Out-Null

        Assert-MockCalled Request-CloudDevicesRetire -Times 1 -Exactly
    }

    It 'passes company-owned exclusion by default to candidate selection' {
        $script:capturedRetireExcludeCompanyOwned = $null

        Mock Get-InitialCloudDevices {
            @(
                [PSCustomObject] @{
                    Name                = 'iPhone-02'
                    EntraDeviceObjectId = 'entra-2'
                    ManagedDeviceId     = 'managed-2'
                    DeviceId            = 'device-2'
                    HasEntraRecord      = $true
                    HasIntuneRecord     = $true
                }
            )
        }
        Mock Get-CloudDevicesToProcess {
            param(
                $Type,
                $Devices,
                $ActionIf,
                $ProcessedDevices
            )
            $script:capturedRetireExcludeCompanyOwned = $ActionIf.ExcludeCompanyOwned
            @()
        }

        Invoke-CloudDevicesCleanup -Retire -Suppress | Out-Null

        $script:capturedRetireExcludeCompanyOwned | Should -BeTrue
    }

    It 'allows including company-owned devices when requested' {
        $script:capturedRetireExcludeCompanyOwned = $null

        Mock Get-InitialCloudDevices { @() }
        Mock Get-CloudDevicesToProcess {
            param(
                $Type,
                $Devices,
                $ActionIf,
                $ProcessedDevices
            )
            $script:capturedRetireExcludeCompanyOwned = $ActionIf.ExcludeCompanyOwned
            @()
        } -ParameterFilter { $Type -eq 'Retire' }

        Invoke-CloudDevicesCleanup -Retire -IncludeCompanyOwned -Suppress | Out-Null

        $script:capturedRetireExcludeCompanyOwned | Should -BeFalse
    }

    It 'does not include orphan states for actions unless explicitly requested' {
        $script:capturedRetireIncludeIntuneOnly = $null
        $script:capturedDisableIncludeEntraOnly = $null
        $script:capturedDeleteIncludeEntraOnly = $null
        $script:capturedDeleteIncludeIntuneOnly = $null

        Mock Get-InitialCloudDevices { @() }
        Mock Get-CloudDevicesToProcess {
            param(
                $Type,
                $Devices,
                $ActionIf,
                $ProcessedDevices
            )

            if ($Type -eq 'Retire') {
                $script:capturedRetireIncludeIntuneOnly = $ActionIf.IncludeIntuneOnly
            } elseif ($Type -eq 'Disable') {
                $script:capturedDisableIncludeEntraOnly = $ActionIf.IncludeEntraOnly
            } elseif ($Type -eq 'Delete') {
                $script:capturedDeleteIncludeEntraOnly = $ActionIf.IncludeEntraOnly
                $script:capturedDeleteIncludeIntuneOnly = $ActionIf.IncludeIntuneOnly
            }

            @()
        }

        Invoke-CloudDevicesCleanup -Retire -Disable -Delete -Suppress | Out-Null

        $script:capturedRetireIncludeIntuneOnly | Should -BeFalse
        $script:capturedDisableIncludeEntraOnly | Should -BeFalse
        $script:capturedDeleteIncludeEntraOnly | Should -BeFalse
        $script:capturedDeleteIncludeIntuneOnly | Should -BeFalse
    }

    It 'passes orphan inclusion switches through when explicitly requested' {
        $script:capturedRetireIncludeIntuneOnly = $null
        $script:capturedDisableIncludeEntraOnly = $null
        $script:capturedDeleteIncludeEntraOnly = $null
        $script:capturedDeleteIncludeIntuneOnly = $null

        Mock Get-InitialCloudDevices { @() }
        Mock Get-CloudDevicesToProcess {
            param(
                $Type,
                $Devices,
                $ActionIf,
                $ProcessedDevices
            )

            if ($Type -eq 'Retire') {
                $script:capturedRetireIncludeIntuneOnly = $ActionIf.IncludeIntuneOnly
            } elseif ($Type -eq 'Disable') {
                $script:capturedDisableIncludeEntraOnly = $ActionIf.IncludeEntraOnly
            } elseif ($Type -eq 'Delete') {
                $script:capturedDeleteIncludeEntraOnly = $ActionIf.IncludeEntraOnly
                $script:capturedDeleteIncludeIntuneOnly = $ActionIf.IncludeIntuneOnly
            }

            @()
        }

        Invoke-CloudDevicesCleanup `
            -Retire `
            -Disable `
            -Delete `
            -RetireIncludeIntuneOnly `
            -DisableIncludeEntraOnly `
            -DeleteIncludeEntraOnly `
            -DeleteIncludeIntuneOnly `
            -Suppress | Out-Null

        $script:capturedRetireIncludeIntuneOnly | Should -BeTrue
        $script:capturedDisableIncludeEntraOnly | Should -BeTrue
        $script:capturedDeleteIncludeEntraOnly | Should -BeTrue
        $script:capturedDeleteIncludeIntuneOnly | Should -BeTrue
    }
}
