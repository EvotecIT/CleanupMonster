function Invoke-ADComputerInventoryAttempt {
    <#
    .SYNOPSIS
    Runs one killable, bounded-idle AD computer inventory attempt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Server,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $QueryParameters,
        [System.Collections.IDictionary] $AzureInformationCache,
        [System.Collections.IDictionary] $JamfInformationCache,
        [switch] $IncludeAzureAD,
        [switch] $IncludeIntune,
        [switch] $IncludeJamf,
        [ValidateRange(1, 10000)]
        [int] $PageSize = 1000,
        [ValidateRange(1, 300)]
        [int] $ConnectionTimeoutSeconds = 15,
        [ValidateRange(1, 300)]
        [int] $InitializationTimeoutSeconds = 60,
        [ValidateRange(1, 3600)]
        [int] $IdleTimeoutSeconds = 120,
        [DateTime] $Today = (Get-Date),
        [string] $ChildProcessFunctionPath
    )

    $Started = Get-Date
    $PowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $TemporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "CleanupMonster.ADQuery.$([Guid]::NewGuid().ToString('N'))"
    $null = [System.IO.Directory]::CreateDirectory($TemporaryDirectory)
    $ConfigurationPath = Join-Path $TemporaryDirectory 'query.clixml'
    $InitializationPath = Join-Path $TemporaryDirectory 'initialized'
    $ReadyPath = Join-Path $TemporaryDirectory 'ready'
    $ProgressPath = Join-Path $TemporaryDirectory 'progress'
    $SuccessPath = Join-Path $TemporaryDirectory 'success'
    $ErrorPath = Join-Path $TemporaryDirectory 'error.txt'
    $DataPath = Join-Path $TemporaryDirectory 'computers.csv'
    $StandardOutputPath = Join-Path $TemporaryDirectory 'stdout.txt'
    $StandardErrorPath = Join-Path $TemporaryDirectory 'stderr.txt'
    $Process = $null
    $ProgressIntervalMilliseconds = [Math]::Max(100, [Math]::Min(1000, [int] ($IdleTimeoutSeconds * 250)))
    $EffectiveIdleTimeoutMilliseconds = ($IdleTimeoutSeconds * 1000) + $ProgressIntervalMilliseconds

    try {
        $Configuration = [PSCustomObject] [ordered] @{
            Server       = $Server
            Filter       = $QueryParameters.Filter
            Properties   = @($QueryParameters.Properties)
            SearchBase   = $QueryParameters.SearchBase
            PageSize     = $PageSize
            ProgressIntervalMilliseconds = $ProgressIntervalMilliseconds
            InitializationPath = $InitializationPath
            ReadyPath    = $ReadyPath
            ProgressPath = $ProgressPath
            SuccessPath  = $SuccessPath
            ErrorPath    = $ErrorPath
            DataPath     = $DataPath
        }
        $PreviousWhatIfPreference = $WhatIfPreference
        try {
            # Inventory setup is non-destructive infrastructure required even
            # when the caller previews later cleanup actions with -WhatIf.
            $WhatIfPreference = $false
            $Configuration | Export-Clixml -LiteralPath $ConfigurationPath -Depth 4

            $EscapedConfigurationPath = $ConfigurationPath.Replace("'", "''")
            if ($ChildProcessFunctionPath) {
                $EscapedFunctionPath = $ChildProcessFunctionPath.Replace("'", "''")
                $Command = "& { . '$EscapedFunctionPath'; Invoke-ADComputerInventoryChildProcess -ConfigurationPath '$EscapedConfigurationPath'; exit 0 }"
            } else {
                $ChildProcessFunction = Get-Command -Name Invoke-ADComputerInventoryChildProcess -CommandType Function -ErrorAction Stop
                $Command = "& { function Invoke-ADComputerInventoryChildProcess {`n$($ChildProcessFunction.Definition)`n}; Invoke-ADComputerInventoryChildProcess -ConfigurationPath '$EscapedConfigurationPath'; exit 0 }"
            }
            $EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
            $Process = Start-Process -FilePath $PowerShellPath `
                -ArgumentList '-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', $EncodedCommand `
                -WindowStyle Hidden `
                -RedirectStandardOutput $StandardOutputPath `
                -RedirectStandardError $StandardErrorPath `
                -PassThru
        } finally {
            $WhatIfPreference = $PreviousWhatIfPreference
        }

        $InitializationObserved = $false
        $ReadyObserved = $false
        $InitializationDeadline = [DateTime]::UtcNow.AddSeconds($InitializationTimeoutSeconds)
        $ConnectionDeadline = $null
        $LastProgress = [DateTime]::UtcNow
        $TimedOut = $false
        $TimeoutPhase = $null

        while (-not $Process.WaitForExit(250)) {
            $Now = [DateTime]::UtcNow
            if (-not $InitializationObserved) {
                if (Test-Path -LiteralPath $InitializationPath) {
                    $InitializationObserved = $true
                    $ConnectionDeadline = $Now.AddSeconds($ConnectionTimeoutSeconds)
                } elseif ($Now -ge $InitializationDeadline) {
                    $TimedOut = $true
                    $TimeoutPhase = 'Initialization'
                    break
                }
            } elseif (-not $ReadyObserved) {
                if (Test-Path -LiteralPath $ReadyPath) {
                    $ReadyObserved = $true
                    $LastProgress = $Now
                } elseif ($Now -ge $ConnectionDeadline) {
                    $TimedOut = $true
                    $TimeoutPhase = 'Connection'
                    break
                }
            } else {
                if (Test-Path -LiteralPath $ProgressPath) {
                    $ProgressWriteTime = [System.IO.File]::GetLastWriteTimeUtc($ProgressPath)
                    if ($ProgressWriteTime -gt $LastProgress) {
                        $LastProgress = $ProgressWriteTime
                    }
                }
                if (($Now - $LastProgress).TotalMilliseconds -ge $EffectiveIdleTimeoutMilliseconds) {
                    $TimedOut = $true
                    $TimeoutPhase = 'Query'
                    break
                }
            }
        }

        if ($TimedOut) {
            try {
                $Process.Kill()
                $null = $Process.WaitForExit(5000)
            } catch {
                Write-Verbose "The isolated AD query process exited before it could be stopped: $($_.Exception.Message)"
            }
            $TimeoutSeconds = switch ($TimeoutPhase) {
                'Initialization' { $InitializationTimeoutSeconds }
                'Connection' { $ConnectionTimeoutSeconds }
                default { $IdleTimeoutSeconds }
            }
            $TimeoutMessage = if ($TimeoutPhase -eq 'Query') {
                "AD query timeout after $TimeoutSeconds seconds without result progress through $Server, plus up to $ProgressIntervalMilliseconds milliseconds for progress signaling. The isolated query process was stopped."
            } else {
                "AD $($TimeoutPhase.ToLowerInvariant()) timeout after $TimeoutSeconds seconds through $Server. The isolated query process was stopped."
            }
            return [PSCustomObject] [ordered] @{
                Succeeded    = $false
                Computers    = @()
                TimedOut     = $true
                TimeoutPhase = $TimeoutPhase
                Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                ErrorMessage = $TimeoutMessage
            }
        }

        $Process.WaitForExit()
        # The success marker is written only after the complete CSV is closed. It
        # is more reliable than the host exit code on Windows PowerShell 5.1,
        # which can be non-zero after emitting first-use progress CLIXML.
        if (-not (Test-Path -LiteralPath $SuccessPath)) {
            $StandardErrorText = if (Test-Path -LiteralPath $StandardErrorPath) {
                [System.IO.File]::ReadAllText($StandardErrorPath)
            }
            $ErrorMessage = if (Test-Path -LiteralPath $ErrorPath) {
                [System.IO.File]::ReadAllText($ErrorPath)
            } elseif (-not [string]::IsNullOrWhiteSpace($StandardErrorText)) {
                $StandardErrorText
            } else {
                "The isolated AD query process exited with code $($Process.ExitCode)."
            }
            return [PSCustomObject] [ordered] @{
                Succeeded    = $false
                Computers    = @()
                TimedOut     = $false
                TimeoutPhase = $null
                Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                ErrorMessage = $ErrorMessage.Trim()
            }
        }

        [Array] $PreparedComputers = if (Test-Path -LiteralPath $DataPath) {
            @(
                Import-Csv -LiteralPath $DataPath | ConvertFrom-ADComputerInventoryRow | ConvertTo-PreparedComputer `
                    -AzureInformationCache $AzureInformationCache `
                    -JamfInformationCache $JamfInformationCache `
                    -IncludeAzureAD:$IncludeAzureAD.IsPresent `
                    -IncludeIntune:$IncludeIntune.IsPresent `
                    -IncludeJamf:$IncludeJamf.IsPresent `
                    -Today $Today
            )
        } else {
            @()
        }

        [PSCustomObject] [ordered] @{
            Succeeded    = $true
            Computers    = $PreparedComputers
            TimedOut     = $false
            TimeoutPhase = $null
            Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
            ErrorMessage = $null
        }
    } catch {
        [PSCustomObject] [ordered] @{
            Succeeded    = $false
            Computers    = @()
            TimedOut     = $false
            TimeoutPhase = $null
            Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
            ErrorMessage = $_.Exception.Message
        }
    } finally {
        if ($null -ne $Process) {
            try {
                # Cover caller cancellation, Ctrl+C, and unexpected terminating
                # errors as well as the explicit timeout branch above.
                if (-not $Process.HasExited) {
                    $Process.Kill()
                    $null = $Process.WaitForExit(5000)
                }
            } catch {
                Write-Warning "Unable to stop isolated AD query process $($Process.Id): $($_.Exception.Message)"
            }
            $Process.Dispose()
        }
        try {
            [System.IO.Directory]::Delete($TemporaryDirectory, $true)
        } catch {
            Write-Verbose "Unable to remove temporary AD query directory $TemporaryDirectory`: $($_.Exception.Message)"
        }
    }
}
