BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Public/Invoke-ADComputersCleanup.ps1')

    function Write-Color { param([Parameter(ValueFromRemainingArguments = $true)] $Text, [object[]] $Color) }
    function Set-LoggingCapabilities {}
    function Set-ReportingCapabilities {}
    function Get-GitHubVersion { param($Cmdlet, $RepositoryOwner, $RepositoryName) '0.0.0' }
    function Assert-InitialSettings { $true }
    function Remove-EmptyValue {
        param(
            [hashtable] $Hashtable
        )

        foreach ($Key in @($Hashtable.Keys)) {
            if ($null -eq $Hashtable[$Key]) {
                $Hashtable.Remove($Key)
            }
        }
    }
    function Get-WinADForestDetails {
        param(
            [string] $Forest,
            [string[]] $IncludeDomains,
            [string[]] $ExcludeDomains
        )

        @{
            Domains        = @('contoso.com')
            QueryServers   = @{
                'contoso.com' = @{
                    HostName = @('dc1.contoso.com')
                }
            }
            DomainsExtended = @{
                'contoso.com' = @{
                    DistinguishedName = 'DC=contoso,DC=com'
                }
            }
        }
    }
    function Import-ComputersData { [ordered] @{} }
    function Get-InitialGraphComputers { @{ AzureAD = @{}; Intune = @{} } }
    function Get-InitialJamfComputers { @{} }
    function New-TestInventoryResult {
        [PSCustomObject] @{
            Succeeded            = $true
            SafetyLimitSatisfied = $true
            ComputerKeys         = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            SuccessfulDomains    = @('contoso.com')
            FailedDomains        = @()
            PendingStateRollback = [ordered] @{}
        }
    }
    function Get-InitialADComputers {
        param(
            [hashtable] $Report,
            [bool] $Disable,
            [bool] $Delete,
            [bool] $Move,
            [int] $ADQueryConnectionTimeout,
            [int] $ADQueryIdleTimeout
        )

        $script:CapturedADQueryConnectionTimeout = $ADQueryConnectionTimeout
        $script:CapturedADQueryIdleTimeout = $ADQueryIdleTimeout

        $Report['contoso.com'] = [ordered] @{
            QueryStatus          = 'Succeeded'
            QueryError           = $null
            Server                = 'dc1.contoso.com'
            AttemptedServers      = @('dc1.contoso.com')
            QueryAttempts         = 1
            ComputerCount         = 0
            Computers             = @()
            ComputersToBeDisabled = 0
            ComputersToBeMoved    = 0
            ComputersToBeDeleted  = 0
        }

        New-TestInventoryResult
    }
    function Request-ADComputersDisable { @() }
    function Request-ADComputersMove {
        param(
            $Report,
            $WhatIfMove,
            $WhatIf,
            $MoveLimit,
            $ReportOnly,
            $Today,
            $ProcessedComputers,
            $TargetOrganizationalUnit,
            $DontWriteToEventLog,
            $Delete,
            $DoNotAddToPendingList,
            $RemoveProtectedFromAccidentalDeletionFlag
        )
        @()
    }
    function Request-ADComputersDelete { @() }
    function New-ADComputersStatistics { @{} }
    function Export-ADComputerReportData {
        param($Computers, $FilePath)

        [PSCustomObject] @{
            FilePath    = $FilePath
            Count       = @($Computers).Count
            Sample      = $null
            DataStoreID = 'CleanupMonsterADComputers'
        }
    }
    function New-HTMLProcessedComputers {}
    function New-EmailBodyComputers { param($CurrentRun) '' }
}

Describe 'Invoke-ADComputersCleanup' {
    It 'passes the bounded AD connection and idle timeouts to inventory discovery' {
        $script:CapturedADQueryConnectionTimeout = $null
        $script:CapturedADQueryIdleTimeout = $null

        Invoke-ADComputersCleanup -Disable -ReportOnly -ADQueryConnectionTimeout 17 -ADQueryIdleTimeout 45 -Suppress | Out-Null

        $script:CapturedADQueryConnectionTimeout | Should -Be 17
        $script:CapturedADQueryIdleTimeout | Should -Be 45
    }

    It 'allows move-only runs to reach the move request' {
        Mock Get-InitialADComputers -MockWith {
            param(
                [hashtable] $Report
            )

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server                = 'dc1.contoso.com'
                AttemptedServers      = @('dc1.contoso.com')
                QueryAttempts         = 1
                ComputerCount         = 0
                Computers             = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved    = 1
                ComputersToBeDeleted  = 0
            }

            New-TestInventoryResult
        }
        Mock Request-ADComputersMove {}

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -Suppress | Out-Null

        Assert-MockCalled Request-ADComputersMove -Times 1 -Exactly
    }

    It 'treats DisableAndMove as a disable discovery workflow' {
        Mock Get-InitialADComputers -ParameterFilter { $Disable -eq $true -and $Delete -eq $false -and $Move -eq $false } -MockWith {
            param(
                [hashtable] $Report
            )

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server                = 'dc1.contoso.com'
                AttemptedServers      = @('dc1.contoso.com')
                QueryAttempts         = 1
                ComputerCount         = 0
                Computers             = @()
                ComputersToBeDisabled = 1
                ComputersToBeMoved    = 0
                ComputersToBeDeleted  = 0
            }

            New-TestInventoryResult
        }
        Mock Request-ADComputersDisable {}

        Invoke-ADComputersCleanup -DisableAndMove -DisableMoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -Suppress | Out-Null

        Assert-MockCalled Get-InitialADComputers -Times 1 -Exactly -ParameterFilter { $Disable -eq $true -and $Delete -eq $false -and $Move -eq $false }
        Assert-MockCalled Request-ADComputersDisable -Times 1 -Exactly
    }

    It 'propagates top-level WhatIf to move actions' {
        $script:CapturedMoveWhatIf = $null

        Mock Get-InitialADComputers -MockWith {
            param(
                [hashtable] $Report
            )

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server                = 'dc1.contoso.com'
                AttemptedServers      = @('dc1.contoso.com')
                QueryAttempts         = 1
                ComputerCount         = 0
                Computers             = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved    = 1
                ComputersToBeDeleted  = 0
            }

            New-TestInventoryResult
        }
        Mock Request-ADComputersMove {
            $script:CapturedMoveWhatIf = $WhatIfMove
        }

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -WhatIf -Suppress | Out-Null

        Assert-MockCalled Request-ADComputersMove -Times 1 -Exactly
        $script:CapturedMoveWhatIf | Should -BeTrue
    }

    It 'suppresses every write when a domain inventory fails by default' {
        $script:CapturedReportOnly = $null
        $script:CapturedHtmlReportOnly = $null
        Mock Get-InitialADComputers -MockWith {
            param([hashtable] $Report)

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server               = 'dc1.contoso.com'
                AttemptedServers     = @('dc1.contoso.com')
                QueryAttempts        = 1
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 0
                ComputersToBeDeleted = 0
            }
            $Report['child.contoso.com'] = [ordered] @{
                QueryStatus          = 'Failed'
                QueryError           = 'server unavailable'
                Server               = $null
                AttemptedServers     = @('dc1.child.contoso.com')
                QueryAttempts        = 3
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 0
                ComputersToBeDeleted = 0
            }

            [PSCustomObject] @{
                Succeeded         = $false
                ComputerKeys      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                SuccessfulDomains = @('contoso.com')
                FailedDomains     = @('child.contoso.com')
            }
        }
        Mock Request-ADComputersMove {
            $script:CapturedReportOnly = $ReportOnly
        }
        Mock New-HTMLProcessedComputers {
            $script:CapturedHtmlReportOnly = $ReportOnly
        }

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -Suppress | Out-Null

        $script:CapturedReportOnly | Should -BeTrue
        $script:CapturedHtmlReportOnly | Should -BeFalse
    }

    It 'allows writes only after explicitly selecting successful-domain continuation' {
        $script:CapturedReportOnly = $null
        Mock Get-InitialADComputers -MockWith {
            param([hashtable] $Report)

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server               = 'dc1.contoso.com'
                AttemptedServers     = @('dc1.contoso.com')
                QueryAttempts        = 1
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 1
                ComputersToBeDeleted = 0
            }
            $Report['child.contoso.com'] = [ordered] @{
                QueryStatus          = 'Failed'
                QueryError           = 'server unavailable'
                Server               = $null
                AttemptedServers     = @('dc1.child.contoso.com')
                QueryAttempts        = 3
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 0
                ComputersToBeDeleted = 0
            }

            [PSCustomObject] @{
                Succeeded         = $false
                ComputerKeys      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                SuccessfulDomains = @('contoso.com')
                FailedDomains     = @('child.contoso.com')
            }
        }
        Mock Request-ADComputersMove {
            $script:CapturedReportOnly = $ReportOnly
        }

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -DomainFailureAction ContinueSuccessfulDomains -Suppress | Out-Null

        $script:CapturedReportOnly | Should -BeFalse
    }

    It 'suppresses writes when the successful-domain count is below the AD safety limit' {
        $script:CapturedReportOnly = $null
        Mock Get-InitialADComputers -MockWith {
            param([hashtable] $Report)

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server               = 'dc1.contoso.com'
                AttemptedServers      = @('dc1.contoso.com')
                QueryAttempts         = 1
                ComputerCount         = 0
                Computers             = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved    = 1
                ComputersToBeDeleted  = 0
            }

            $Result = New-TestInventoryResult
            $Result.SafetyLimitSatisfied = $false
            $Result
        }
        Mock Request-ADComputersMove {
            $script:CapturedReportOnly = $ReportOnly
        }

        Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -SafetyADLimit 300000 -DomainFailureAction ContinueSuccessfulDomains -Suppress | Out-Null

        $script:CapturedReportOnly | Should -BeTrue
    }

    It 'never prunes pending entries that belong to a failed domain' {
        Mock Import-ComputersData {
            [ordered] @{
                'OLD-SUCCESS$@contoso.com' = [PSCustomObject] @{
                    SamAccountName    = 'OLD-SUCCESS$'
                    DomainName        = 'contoso.com'
                    DistinguishedName = 'CN=OLD-SUCCESS,DC=contoso,DC=com'
                }
                'OLD-FAILED$@child.contoso.com' = [PSCustomObject] @{
                    SamAccountName    = 'OLD-FAILED$'
                    DomainName        = 'child.contoso.com'
                    DistinguishedName = 'CN=OLD-FAILED,DC=child,DC=contoso,DC=com'
                }
            }
        }
        Mock Get-InitialADComputers -MockWith {
            param([hashtable] $Report)

            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server               = 'dc1.contoso.com'
                AttemptedServers     = @('dc1.contoso.com')
                QueryAttempts        = 1
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 0
                ComputersToBeDeleted = 0
            }
            $Report['child.contoso.com'] = [ordered] @{
                QueryStatus          = 'Failed'
                QueryError           = 'server unavailable'
                Server               = $null
                AttemptedServers     = @('dc1.child.contoso.com')
                QueryAttempts        = 3
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 0
                ComputersToBeDeleted = 0
            }

            [PSCustomObject] @{
                Succeeded         = $false
                ComputerKeys      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                SuccessfulDomains = @('contoso.com')
                FailedDomains     = @('child.contoso.com')
            }
        }

        $Result = Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com' -DomainFailureAction ContinueSuccessfulDomains -DataStorePath (Join-Path $TestDrive 'state.xml') -ReportPath (Join-Path $TestDrive 'report.html')

        $Result.PendingDeletion.Contains('OLD-SUCCESS$@contoso.com') | Should -BeFalse
        $Result.PendingDeletion.Contains('OLD-FAILED$@child.contoso.com') | Should -BeTrue
    }

    It 'keeps persisted pending and history state unchanged when inventory fails closed' {
        $ExistingHistory = [PSCustomObject] @{ SamAccountName = 'HISTORY$'; Action = 'Move'; ActionStatus = $true }
        Mock Import-ComputersData {
            param($Export)

            $Export.History = @($ExistingHistory)
            [ordered] @{
                'PENDING$@contoso.com' = [PSCustomObject] @{
                    SamAccountName    = 'PENDING$'
                    DomainName        = 'contoso.com'
                    DistinguishedName = 'CN=PENDING,DC=contoso,DC=com'
                    ActionStatus      = $true
                }
            }
        }
        Mock Get-InitialADComputers -MockWith {
            param(
                [hashtable] $Report,
                [System.Collections.IDictionary] $ProcessedComputers
            )

            $PendingStateRollback = [ordered] @{
                'PENDING$@contoso.com' = $ProcessedComputers['PENDING$@contoso.com'].PSObject.Copy()
            }
            $ProcessedComputers.Remove('PENDING$@contoso.com')
            $Candidate = [PSCustomObject] @{
                SamAccountName = 'MOVE-ME$'
                DomainName     = 'contoso.com'
                Action         = 'Move'
            }
            $Report['contoso.com'] = [ordered] @{
                QueryStatus          = 'Succeeded'
                QueryError           = $null
                Server               = 'dc1.contoso.com'
                AttemptedServers     = @('dc1.contoso.com')
                QueryAttempts        = 1
                ComputerCount        = 1
                Computers            = @($Candidate)
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 1
                ComputersToBeDeleted = 0
            }
            $Report['child.contoso.com'] = [ordered] @{
                QueryStatus          = 'Failed'
                QueryError           = 'server unavailable'
                Server               = $null
                AttemptedServers     = @('dc1.child.contoso.com')
                QueryAttempts        = 3
                ComputerCount        = 0
                Computers            = @()
                ComputersToBeDisabled = 0
                ComputersToBeMoved   = 0
                ComputersToBeDeleted = 0
            }

            [PSCustomObject] @{
                Succeeded            = $false
                SafetyLimitSatisfied = $true
                ComputerKeys         = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                SuccessfulDomains    = @('contoso.com')
                FailedDomains        = @('child.contoso.com')
                PendingStateRollback = $PendingStateRollback
            }
        }
        Mock Request-ADComputersMove {
            [PSCustomObject] @{ SamAccountName = 'MOVE-ME$'; Action = 'Move'; ActionStatus = $null }
        }

        $Result = Invoke-ADComputersCleanup -Move -MoveTargetOrganizationalUnit 'OU=Disabled,DC=contoso,DC=com'

        $Result.PendingDeletion.Contains('PENDING$@contoso.com') | Should -BeTrue
        $Result.CurrentRun | Should -BeNullOrEmpty
        $Result.History | Should -HaveCount 1
        $Result.History[0].SamAccountName | Should -Be 'HISTORY$'
    }
}
