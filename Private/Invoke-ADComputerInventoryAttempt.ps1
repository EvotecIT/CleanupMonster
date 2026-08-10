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
        [ValidateRange(1, 3600)]
        [int] $IdleTimeoutSeconds = 120,
        [DateTime] $Today = (Get-Date),
        [string] $ChildProcessFunctionPath = (Join-Path $PSScriptRoot 'Invoke-ADComputerInventoryChildProcess.ps1')
    )

    $Started = Get-Date
    $PowerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $TemporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "CleanupMonster.ADQuery.$([Guid]::NewGuid().ToString('N'))"
    $null = [System.IO.Directory]::CreateDirectory($TemporaryDirectory)
    $ConfigurationPath = Join-Path $TemporaryDirectory 'query.clixml'
    $ReadyPath = Join-Path $TemporaryDirectory 'ready'
    $ProgressPath = Join-Path $TemporaryDirectory 'progress'
    $SuccessPath = Join-Path $TemporaryDirectory 'success'
    $ErrorPath = Join-Path $TemporaryDirectory 'error.txt'
    $DataPath = Join-Path $TemporaryDirectory 'computers.csv'
    $StandardOutputPath = Join-Path $TemporaryDirectory 'stdout.txt'
    $StandardErrorPath = Join-Path $TemporaryDirectory 'stderr.txt'
    $Process = $null

    try {
        $Configuration = [PSCustomObject] [ordered] @{
            Server       = $Server
            Filter       = $QueryParameters.Filter
            Properties   = @($QueryParameters.Properties)
            SearchBase   = $QueryParameters.SearchBase
            PageSize     = $PageSize
            ReadyPath    = $ReadyPath
            ProgressPath = $ProgressPath
            SuccessPath  = $SuccessPath
            ErrorPath    = $ErrorPath
            DataPath     = $DataPath
        }
        $Configuration | Export-Clixml -LiteralPath $ConfigurationPath -Depth 4

        $EscapedFunctionPath = $ChildProcessFunctionPath.Replace("'", "''")
        $EscapedConfigurationPath = $ConfigurationPath.Replace("'", "''")
        $Command = "& { . '$EscapedFunctionPath'; Invoke-ADComputerInventoryChildProcess -ConfigurationPath '$EscapedConfigurationPath'; exit 0 }"
        $EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
        $Process = Start-Process -FilePath $PowerShellPath `
            -ArgumentList '-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', $EncodedCommand `
            -WindowStyle Hidden `
            -RedirectStandardOutput $StandardOutputPath `
            -RedirectStandardError $StandardErrorPath `
            -PassThru

        $ReadyObserved = $false
        $ConnectionDeadline = [DateTime]::UtcNow.AddSeconds($ConnectionTimeoutSeconds)
        $LastProgress = [DateTime]::UtcNow
        $TimedOut = $false
        $TimeoutPhase = $null

        while (-not $Process.WaitForExit(250)) {
            $Now = [DateTime]::UtcNow
            if (-not $ReadyObserved) {
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
                if (($Now - $LastProgress).TotalSeconds -ge $IdleTimeoutSeconds) {
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
                # The process may have exited between the timeout decision and Kill.
            }
            $TimeoutSeconds = if ($TimeoutPhase -eq 'Connection') { $ConnectionTimeoutSeconds } else { $IdleTimeoutSeconds }
            return [PSCustomObject] [ordered] @{
                Succeeded    = $false
                Computers    = @()
                TimedOut     = $true
                TimeoutPhase = $TimeoutPhase
                Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                ErrorMessage = "AD $($TimeoutPhase.ToLowerInvariant()) timeout after $TimeoutSeconds seconds through $Server. The isolated query process was stopped."
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
