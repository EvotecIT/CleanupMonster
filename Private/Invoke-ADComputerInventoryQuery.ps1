function Invoke-ADComputerInventoryQuery {
    <#
    .SYNOPSIS
    Queries one AD domain with retry and domain-controller failover.

    .DESCRIPTION
    Attempts each configured domain controller in order. Every Get-ADComputer call
    runs in an isolated Windows PowerShell process so a connection or idle-query
    timeout can stop the real AD operation. Each controller receives the configured
    number of attempts, followed by one smaller-page attempt when the configured
    page size is greater than 500. The child process transports only the properties
    required by CleanupMonster and raw ADComputer objects are never retained beside
    the normalized inventory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Domain,
        [Parameter(Mandatory)]
        [string[]] $Servers,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $QueryParameters,
        [System.Collections.IDictionary] $AzureInformationCache,
        [System.Collections.IDictionary] $JamfInformationCache,
        [switch] $IncludeAzureAD,
        [switch] $IncludeIntune,
        [switch] $IncludeJamf,
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxAttemptsPerServer = 3,
        [ValidateRange(0, [int]::MaxValue)]
        [int] $RetryDelaySeconds = 5,
        [ValidateRange(1, 300)]
        [int] $ConnectionTimeoutSeconds = 15,
        [ValidateRange(1, 3600)]
        [int] $IdleTimeoutSeconds = 120,
        [ValidateRange(1, 10000)]
        [int] $PageSize = 1000,
        [DateTime] $Today = (Get-Date)
    )

    $Attempts = [System.Collections.Generic.List[object]]::new()
    $LastError = $null

    foreach ($Server in $Servers) {
        $Delay = $RetryDelaySeconds
        $QueryReachedServer = $false
        for ($Attempt = 1; $Attempt -le $MaxAttemptsPerServer; $Attempt++) {
            Write-Color -Text '[i] ', "Querying $Domain through $Server (attempt $Attempt of $MaxAttemptsPerServer, page size $PageSize)..." -Color Yellow, Cyan
            $AttemptResult = Invoke-ADComputerInventoryAttempt `
                -Server $Server `
                -QueryParameters $QueryParameters `
                -AzureInformationCache $AzureInformationCache `
                -JamfInformationCache $JamfInformationCache `
                -IncludeAzureAD:$IncludeAzureAD.IsPresent `
                -IncludeIntune:$IncludeIntune.IsPresent `
                -IncludeJamf:$IncludeJamf.IsPresent `
                -PageSize $PageSize `
                -ConnectionTimeoutSeconds $ConnectionTimeoutSeconds `
                -IdleTimeoutSeconds $IdleTimeoutSeconds `
                -Today $Today

            $QueryReachedServer = $QueryReachedServer -or $AttemptResult.TimeoutPhase -notin @('Initialization', 'Connection')
            $Attempts.Add([PSCustomObject] @{
                    Server       = $Server
                    Attempt      = $Attempt
                    PageSize     = $PageSize
                    Succeeded    = $AttemptResult.Succeeded
                    Duration     = $AttemptResult.Duration
                    ErrorMessage = $AttemptResult.ErrorMessage
                })

            if ($AttemptResult.Succeeded) {
                return [PSCustomObject] @{
                    Succeeded = $true
                    Server    = $Server
                    Computers = $AttemptResult.Computers
                    Attempts  = $Attempts.ToArray()
                    Error     = $null
                }
            }

            $LastError = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($AttemptResult.ErrorMessage),
                'ADComputerInventoryQueryFailed',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $Server
            )
            Write-Color -Text '[w] ', "AD query failed for $Domain through $Server`: $($AttemptResult.ErrorMessage)" -Color Yellow, DarkYellow

            if (Test-ADQueryConfigurationError -ErrorRecord $LastError) {
                return [PSCustomObject] @{
                    Succeeded = $false
                    Server    = $null
                    Computers = @()
                    Attempts  = $Attempts.ToArray()
                    Error     = $AttemptResult.ErrorMessage
                }
            }
            if ($Attempt -lt $MaxAttemptsPerServer -and $Delay -gt 0) {
                Start-Sleep -Seconds $Delay
                $Delay = [math]::Min($Delay * 2, 300)
            }
        }

        if ($QueryReachedServer -and $PageSize -gt 500) {
            $FallbackPageSize = 500
            Write-Color -Text '[i] ', "Retrying $Domain through $Server with page size $FallbackPageSize..." -Color Yellow, Cyan
            $AttemptResult = Invoke-ADComputerInventoryAttempt `
                -Server $Server `
                -QueryParameters $QueryParameters `
                -AzureInformationCache $AzureInformationCache `
                -JamfInformationCache $JamfInformationCache `
                -IncludeAzureAD:$IncludeAzureAD.IsPresent `
                -IncludeIntune:$IncludeIntune.IsPresent `
                -IncludeJamf:$IncludeJamf.IsPresent `
                -PageSize $FallbackPageSize `
                -ConnectionTimeoutSeconds $ConnectionTimeoutSeconds `
                -IdleTimeoutSeconds $IdleTimeoutSeconds `
                -Today $Today

            $Attempts.Add([PSCustomObject] @{
                    Server       = $Server
                    Attempt      = 'SmallPageFallback'
                    PageSize     = $FallbackPageSize
                    Succeeded    = $AttemptResult.Succeeded
                    Duration     = $AttemptResult.Duration
                    ErrorMessage = $AttemptResult.ErrorMessage
                })

            if ($AttemptResult.Succeeded) {
                return [PSCustomObject] @{
                    Succeeded = $true
                    Server    = $Server
                    Computers = $AttemptResult.Computers
                    Attempts  = $Attempts.ToArray()
                    Error     = $null
                }
            }

            $LastError = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($AttemptResult.ErrorMessage),
                'ADComputerInventoryQueryFailed',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $Server
            )
            Write-Color -Text '[w] ', "Small-page AD query failed for $Domain through $Server`: $($AttemptResult.ErrorMessage)" -Color Yellow, DarkYellow
        }
    }

    [PSCustomObject] @{
        Succeeded = $false
        Server    = $null
        Computers = @()
        Attempts  = $Attempts.ToArray()
        Error     = if ($LastError) { $LastError.Exception.Message } else { "No domain controller was available for $Domain." }
    }
}
