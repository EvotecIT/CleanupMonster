BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ADQueryServerCandidates.ps1')
    . (Get-CleanupMonsterPath 'Private/Test-ADQueryConfigurationError.ps1')
    . (Get-CleanupMonsterPath 'Private/ConvertFrom-ADComputerInventoryRow.ps1')
    . (Get-CleanupMonsterPath 'Private/Invoke-ADComputerInventoryAttempt.ps1')
    . (Get-CleanupMonsterPath 'Private/Invoke-ADComputerInventoryChildProcess.ps1')
    . (Get-CleanupMonsterPath 'Private/Invoke-ADComputerInventoryQuery.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-InitialADComputers.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
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

    It 'marks a domain failed instead of broadening an empty filter dictionary' {
        $Report = [ordered] @{}
        $ForestInformation = [ordered] @{
            Domains = @('contoso.com')
            QueryServers = @{ 'contoso.com' = @{ HostName = @('dc1.contoso.com') } }
            DomainsExtended = @{ 'contoso.com' = @{ DistinguishedName = 'DC=contoso,DC=com' } }
        }
        Mock Invoke-ADComputerInventoryQuery {}

        $Result = Get-InitialADComputers -Report $Report -ForestInformation $ForestInformation -Filter @{} -Properties @('SamAccountName') -Disable:$false -Move:$false -Delete:$false

        $Result.Succeeded | Should -BeFalse
        $Result.FailedDomains | Should -Be @('contoso.com')
        $Report['contoso.com'].QueryError | Should -Match 'No AD filter was configured'
        Assert-MockCalled Invoke-ADComputerInventoryQuery -Times 0 -Exactly
    }

    It 'marks a domain failed instead of broadening a missing per-domain search base' {
        $Report = [ordered] @{}
        $ForestInformation = [ordered] @{
            Domains = @('contoso.com', 'child.contoso.com')
            QueryServers = @{
                'contoso.com' = @{ HostName = @('dc1.contoso.com') }
                'child.contoso.com' = @{ HostName = @('dc1.child.contoso.com') }
            }
            DomainsExtended = @{
                'contoso.com' = @{ DistinguishedName = 'DC=contoso,DC=com' }
                'child.contoso.com' = @{ DistinguishedName = 'DC=child,DC=contoso,DC=com' }
            }
        }
        Mock Invoke-ADComputerInventoryQuery {
            [PSCustomObject] @{
                Succeeded = $true; Server = $Servers[0]; Computers = @(); Attempts = @([PSCustomObject] @{ Server = $Servers[0] }); Error = $null
            }
        }

        $Result = Get-InitialADComputers -Report $Report -ForestInformation $ForestInformation -Filter '*' -SearchBase @{ 'contoso.com' = 'OU=Computers,DC=contoso,DC=com' } -Properties @('SamAccountName') -Disable:$false -Move:$false -Delete:$false

        $Result.Succeeded | Should -BeFalse
        $Result.SuccessfulDomains | Should -Be @('contoso.com')
        $Result.FailedDomains | Should -Be @('child.contoso.com')
        $Report['child.contoso.com'].QueryError | Should -Match 'No AD search base was configured'
        Assert-MockCalled Invoke-ADComputerInventoryQuery -Times 1 -Exactly
    }
}

Describe 'AD computer inventory server selection and failover' {
    BeforeEach {
        Mock Invoke-ADComputerInventoryAttempt {
            [PSCustomObject] @{
                Succeeded    = $true
                Computers    = @([PSCustomObject] @{ SamAccountName = 'PC01$' })
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = [TimeSpan]::Zero
                ErrorMessage = $null
            }
        }
    }

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
        Mock Invoke-ADComputerInventoryAttempt {
            if ($Server -eq 'dc1.contoso.com') {
                return [PSCustomObject] @{
                    Succeeded    = $false
                    Computers    = @()
                    TimedOut     = $false
                    TimeoutPhase = $null
                    Duration     = [TimeSpan]::Zero
                    ErrorMessage = 'The server is not operational'
                }
            }
            [PSCustomObject] @{
                Succeeded    = $true
                Computers    = @([PSCustomObject] @{ SamAccountName = 'PC01$' })
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = [TimeSpan]::Zero
                ErrorMessage = $null
            }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com', 'dc2.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 2 -RetryDelaySeconds 0 -PageSize 500

        $Result.Succeeded | Should -BeTrue
        $Result.Server | Should -Be 'dc2.contoso.com'
        $Result.Computers | Should -HaveCount 1
        $Result.Attempts | Should -HaveCount 3
        @($Result.Attempts | Where-Object Server -eq 'dc1.contoso.com') | Should -HaveCount 2
    }

    It 'bounds the real isolated AD query and preserves port-qualified server values during failover' {
        Mock Invoke-ADComputerInventoryAttempt {
            if ($Server -eq 'dc1.contoso.com:60000') {
                return [PSCustomObject] @{
                    Succeeded    = $false
                    Computers    = @()
                    TimedOut     = $true
                    TimeoutPhase = 'Connection'
                    Duration     = [TimeSpan]::FromSeconds(10)
                    ErrorMessage = 'AD connection timeout after 10 seconds through dc1.contoso.com:60000. The isolated query process was stopped.'
                }
            }
            [PSCustomObject] @{
                Succeeded    = $true
                Computers    = @([PSCustomObject] @{ SamAccountName = 'PC01$' })
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = [TimeSpan]::Zero
                ErrorMessage = $null
            }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com:60000', 'dc2.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 2 -RetryDelaySeconds 0 -ConnectionTimeoutSeconds 10 -PageSize 1000

        $Result.Succeeded | Should -BeTrue
        $Result.Server | Should -Be 'dc2.contoso.com'
        @($Result.Attempts | Where-Object Server -eq 'dc1.contoso.com:60000') | Should -HaveCount 2
        @($Result.Attempts | Where-Object Server -eq 'dc1.contoso.com:60000').ErrorMessage | Should -Match 'isolated query process was stopped'
        Assert-MockCalled Invoke-ADComputerInventoryAttempt -Times 2 -Exactly -ParameterFilter { $Server -eq 'dc1.contoso.com:60000' }
        Assert-MockCalled Invoke-ADComputerInventoryAttempt -Times 1 -Exactly -ParameterFilter { $Server -eq 'dc2.contoso.com' }
    }

    It 'skips the smaller-page retry when the child cannot initialize' {
        Mock Invoke-ADComputerInventoryAttempt {
            [PSCustomObject] @{
                Succeeded    = $false
                Computers    = @()
                TimedOut     = $true
                TimeoutPhase = 'Initialization'
                Duration     = [TimeSpan]::FromSeconds(60)
                ErrorMessage = 'AD initialization timeout after 60 seconds. The isolated query process was stopped.'
            }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 1000

        $Result.Succeeded | Should -BeFalse
        $Result.Attempts | Should -HaveCount 1
        Assert-MockCalled Invoke-ADComputerInventoryAttempt -Times 1 -Exactly
    }

    It 'records an explicit failed result after every domain controller fails' {
        Mock Invoke-ADComputerInventoryAttempt {
            [PSCustomObject] @{
                Succeeded    = $false
                Computers    = @()
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = [TimeSpan]::Zero
                ErrorMessage = 'The server is not operational'
            }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com', 'dc2.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 500

        $Result.Succeeded | Should -BeFalse
        $Result.Computers | Should -HaveCount 0
        $Result.Attempts | Should -HaveCount 2
        $Result.Error | Should -Be 'The server is not operational'
    }

    It 'retries a failed large-page query once with the bounded fallback page size' {
        Mock Invoke-ADComputerInventoryAttempt {
            if ($PageSize -eq 1000) {
                return [PSCustomObject] @{
                    Succeeded    = $false
                    Computers    = @()
                    TimedOut     = $false
                    TimeoutPhase = $null
                    Duration     = [TimeSpan]::Zero
                    ErrorMessage = 'invalid enumeration context'
                }
            }
            [PSCustomObject] @{
                Succeeded    = $true
                Computers    = @([PSCustomObject] @{ SamAccountName = 'PC01$' })
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = [TimeSpan]::Zero
                ErrorMessage = $null
            }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('dc1.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 1000

        $Result.Succeeded | Should -BeTrue
        $Result.Attempts | Should -HaveCount 2
        $Result.Attempts[1].PageSize | Should -Be 500
    }

    It 'continues to the next domain controller after a partition error on a manual server' {
        Mock Invoke-ADComputerInventoryAttempt {
            if ($Server -eq 'manual.contoso.com') {
                return [PSCustomObject] @{
                    Succeeded    = $false
                    Computers    = @()
                    TimedOut     = $false
                    TimeoutPhase = $null
                    Duration     = [TimeSpan]::Zero
                    ErrorMessage = 'The supplied distinguishedName must belong to one of the following partition(s)'
                }
            }
            [PSCustomObject] @{
                Succeeded    = $true
                Computers    = @([PSCustomObject] @{ SamAccountName = 'PC01$' })
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = [TimeSpan]::Zero
                ErrorMessage = $null
            }
        }

        $Result = Invoke-ADComputerInventoryQuery -Domain 'contoso.com' -Servers @('manual.contoso.com', 'detected.contoso.com') -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -MaxAttemptsPerServer 1 -RetryDelaySeconds 0 -PageSize 500

        $Result.Succeeded | Should -BeTrue
        $Result.Server | Should -Be 'detected.contoso.com'
        $Result.Attempts | Should -HaveCount 2
    }
}

Describe 'AD computer inventory process isolation' {
    It 'records time-throttled progress when fewer than 100 slow results arrive' {
        function Get-ADRootDSE {}
        function Get-ADComputer {}
        Mock Import-Module {}
        Mock Get-ADRootDSE { [PSCustomObject] @{} }
        Mock Get-ADComputer {
            1..3 | ForEach-Object {
                Start-Sleep -Milliseconds 350
                [PSCustomObject] @{
                    Name = "PC$_"
                    SamAccountName = "PC$_`$"
                    DistinguishedName = "CN=PC$_,DC=contoso,DC=com"
                }
            }
        }

        $ConfigurationPath = Join-Path $TestDrive 'query.clixml'
        $Configuration = [PSCustomObject] @{
            Server = 'dc1.contoso.com'; Filter = '*'; Properties = @('SamAccountName'); SearchBase = $null; PageSize = 1000; ProgressIntervalMilliseconds = 250
            InitializationPath = (Join-Path $TestDrive 'initialized'); ReadyPath = (Join-Path $TestDrive 'ready'); ProgressPath = (Join-Path $TestDrive 'progress')
            SuccessPath = (Join-Path $TestDrive 'success'); ErrorPath = (Join-Path $TestDrive 'error.txt'); DataPath = (Join-Path $TestDrive 'computers.csv')
        }
        $Configuration | Export-Clixml -LiteralPath $ConfigurationPath

        Invoke-ADComputerInventoryChildProcess -ConfigurationPath $ConfigurationPath

        Get-Content -LiteralPath $Configuration.ProgressPath | Should -Be '3'
        Get-Content -LiteralPath $Configuration.SuccessPath | Should -Be '3'
    }

    It 'terminates a still-running child when polling exits unexpectedly' {
        $script:FakeChildKilled = $false
        $FakeProcess = [PSCustomObject] @{ HasExited = $false; Id = 4242; ExitCode = 0 }
        $FakeProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
            param([int] $Milliseconds)
            $this.HasExited
        }
        $FakeProcess | Add-Member -MemberType ScriptMethod -Name Kill -Value {
            $script:FakeChildKilled = $true
            $this.HasExited = $true
        }
        $FakeProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
        Mock Start-Process { $FakeProcess }
        Mock Test-Path { throw 'Polling interrupted' }

        $Result = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 5 -IdleTimeoutSeconds 5

        $Result.Succeeded | Should -BeFalse
        $Result.ErrorMessage | Should -Be 'Polling interrupted'
        $script:FakeChildKilled | Should -BeTrue
    }

    It 'embeds the child function when no source-layout helper path is supplied' {
        $script:EncodedChildCommand = $null
        $FakeProcess = [PSCustomObject] @{ HasExited = $false; Id = 4243; ExitCode = 0 }
        $FakeProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
            param([int] $Milliseconds)
            $this.HasExited
        }
        $FakeProcess | Add-Member -MemberType ScriptMethod -Name Kill -Value { $this.HasExited = $true }
        $FakeProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
        Mock Start-Process {
            $script:EncodedChildCommand = $ArgumentList[-1]
            $FakeProcess
        }
        Mock Test-Path { throw 'Stop after command capture' }

        $null = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') }

        $DecodedCommand = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($script:EncodedChildCommand))
        $DecodedCommand | Should -Match 'function Invoke-ADComputerInventoryChildProcess'
        $DecodedCommand | Should -Not -Match "\. '.*Invoke-ADComputerInventoryChildProcess\.ps1'"
    }

    It 'kills a child that never completes native AD connection readiness' {
        $ChildPath = Join-Path $TestDrive 'UnreadyChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    $Configuration = Import-Clixml -LiteralPath $ConfigurationPath
    [System.IO.File]::WriteAllText($Configuration.InitializationPath, 'Initialized')
    Start-Sleep -Seconds 10
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $Result = Invoke-ADComputerInventoryAttempt -Server 'unavailable.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 1 -IdleTimeoutSeconds 5 -ChildProcessFunctionPath $ChildPath

        $Result.Succeeded | Should -BeFalse
        $Result.TimedOut | Should -BeTrue
        $Result.TimeoutPhase | Should -Be 'Connection'
        $Result.ErrorMessage | Should -Match 'isolated query process was stopped'
    }

    It 'does not charge child initialization time against the connection timeout' {
        $ChildPath = Join-Path $TestDrive 'SlowInitializationChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    $Configuration = Import-Clixml -LiteralPath $ConfigurationPath
    Start-Sleep -Seconds 2
    [System.IO.File]::WriteAllText($Configuration.InitializationPath, 'Initialized')
    [System.IO.File]::WriteAllText($Configuration.ReadyPath, 'Ready')
    [System.IO.File]::WriteAllText($Configuration.ProgressPath, '0')
    [System.IO.File]::WriteAllText($Configuration.SuccessPath, '0')
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $Result = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 1 -InitializationTimeoutSeconds 5 -IdleTimeoutSeconds 5 -ChildProcessFunctionPath $ChildPath

        $Result.Succeeded | Should -BeTrue -Because $Result.ErrorMessage
    }

    It 'kills a child that never completes initialization' {
        $ChildPath = Join-Path $TestDrive 'StalledInitializationChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    Start-Sleep -Seconds 10
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $Result = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 5 -InitializationTimeoutSeconds 1 -IdleTimeoutSeconds 5 -ChildProcessFunctionPath $ChildPath

        $Result.Succeeded | Should -BeFalse
        $Result.TimedOut | Should -BeTrue
        $Result.TimeoutPhase | Should -Be 'Initialization'
        $Result.ErrorMessage | Should -Match 'isolated query process was stopped'
    }

    It 'kills an established child query after the configured idle timeout' {
        $ChildPath = Join-Path $TestDrive 'StalledChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    $Configuration = Import-Clixml -LiteralPath $ConfigurationPath
    [System.IO.File]::WriteAllText($Configuration.InitializationPath, 'Initialized')
    [System.IO.File]::WriteAllText($Configuration.ReadyPath, 'Ready')
    [System.IO.File]::WriteAllText($Configuration.ProgressPath, '0')
    Start-Sleep -Seconds 10
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $Result = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 5 -IdleTimeoutSeconds 1 -ChildProcessFunctionPath $ChildPath

        $Result.Succeeded | Should -BeFalse
        $Result.TimedOut | Should -BeTrue
        $Result.TimeoutPhase | Should -Be 'Query'
        $Result.ErrorMessage | Should -Match 'isolated query process was stopped'
    }

    It 'keeps a burst-shaped result stream alive across progress-marker throttle lag' {
        $ChildPath = Join-Path $TestDrive 'SlowProgressChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    $Configuration = Import-Clixml -LiteralPath $ConfigurationPath
    [System.IO.File]::WriteAllText($Configuration.InitializationPath, 'Initialized')
    [System.IO.File]::WriteAllText($Configuration.ReadyPath, 'Ready')
    [System.IO.File]::WriteAllText($Configuration.ProgressPath, '1')
    Start-Sleep -Milliseconds 200
    # A second result arrives inside the throttle window without a marker write.
    Start-Sleep -Milliseconds 850
    [System.IO.File]::WriteAllText($Configuration.ProgressPath, '3')
    [System.IO.File]::WriteAllText($Configuration.SuccessPath, '3')
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $Result = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 5 -IdleTimeoutSeconds 1 -ChildProcessFunctionPath $ChildPath

        $Result.Succeeded | Should -BeTrue -Because $Result.ErrorMessage
        $Result.TimedOut | Should -BeFalse
    }

    It 'streams only the required row fields back from a successful isolated child' {
        $ChildPath = Join-Path $TestDrive 'SuccessfulChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    $Configuration = Import-Clixml -LiteralPath $ConfigurationPath
    [System.IO.File]::WriteAllText($Configuration.InitializationPath, 'Initialized')
    [System.IO.File]::WriteAllText($Configuration.ReadyPath, 'Ready')
    [System.IO.File]::WriteAllText($Configuration.ProgressPath, '1')
    [PSCustomObject] @{
        Name = 'PC01'; DNSHostName = 'pc01.contoso.com'; SamAccountName = 'PC01$'; DistinguishedName = 'CN=PC01,DC=contoso,DC=com'
        Enabled = $true; OperatingSystem = 'Windows'; OperatingSystemVersion = '10.0'; LastLogonDateBinary = (Get-Date).ToBinary()
        PasswordLastSetBinary = (Get-Date).ToBinary(); PasswordExpired = $false; ServicePrincipalNameJson = '["HOST/PC01"]'
        LogonCount = 12; ManagedBy = ''; Description = 'Test'; WhenCreatedBinary = (Get-Date).ToBinary(); WhenChangedBinary = (Get-Date).ToBinary()
        ProtectedFromAccidentalDeletion = $true
    } | Export-Csv -LiteralPath $Configuration.DataPath -NoTypeInformation -Encoding UTF8
    [System.IO.File]::WriteAllText($Configuration.SuccessPath, '1')
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $Result = Invoke-ADComputerInventoryAttempt -Server 'contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 5 -IdleTimeoutSeconds 5 -ChildProcessFunctionPath $ChildPath

        $Result.Succeeded | Should -BeTrue -Because $Result.ErrorMessage
        $Result.Computers | Should -HaveCount 1
        $Result.Computers[0].SamAccountName | Should -Be 'PC01$'
        $Result.Computers[0].servicePrincipalName | Should -Be @('HOST/PC01')
        $Result.Computers[0].LastLogonDate | Should -BeOfType ([DateTime])
        $Result.Computers[0].ProtectedFromAccidentalDeletion | Should -BeTrue
    }

    It 'runs inventory setup even when ambient WhatIf is enabled' {
        $ChildPath = Join-Path $TestDrive 'WhatIfChild.ps1'
        @'
function Invoke-ADComputerInventoryChildProcess {
    param([string] $ConfigurationPath)
    $Configuration = Import-Clixml -LiteralPath $ConfigurationPath
    [System.IO.File]::WriteAllText($Configuration.InitializationPath, 'Initialized')
    [System.IO.File]::WriteAllText($Configuration.ReadyPath, 'Ready')
    [System.IO.File]::WriteAllText($Configuration.ProgressPath, '0')
    [System.IO.File]::WriteAllText($Configuration.SuccessPath, '0')
}
'@ | Set-Content -LiteralPath $ChildPath -Encoding UTF8

        $PreviousWhatIfPreference = $WhatIfPreference
        try {
            $WhatIfPreference = $true
            $Result = Invoke-ADComputerInventoryAttempt -Server 'dc1.contoso.com' -QueryParameters @{ Filter = '*'; Properties = @('SamAccountName') } -ConnectionTimeoutSeconds 5 -IdleTimeoutSeconds 5 -ChildProcessFunctionPath $ChildPath
        } finally {
            $WhatIfPreference = $PreviousWhatIfPreference
        }

        $Result.Succeeded | Should -BeTrue -Because $Result.ErrorMessage
        $Result.TimedOut | Should -BeFalse
    }
}
