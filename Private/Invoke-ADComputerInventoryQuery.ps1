function Invoke-ADComputerInventoryQuery {
    <#
    .SYNOPSIS
    Queries one AD domain with retry and domain-controller failover.

    .DESCRIPTION
    Attempts each configured domain controller in order. Each controller receives
    the configured number of attempts, followed by one smaller-page attempt when
    the configured page size is greater than 500. Raw ADComputer objects are
    converted as they arrive and are not retained after normalization.
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
        [ValidateRange(1, 10000)]
        [int] $PageSize = 1000,
        [DateTime] $Today = (Get-Date)
    )

    $Attempts = [System.Collections.Generic.List[object]]::new()
    $LastError = $null

    foreach ($Server in $Servers) {
        $Delay = $RetryDelaySeconds
        for ($Attempt = 1; $Attempt -le $MaxAttemptsPerServer; $Attempt++) {
            $Query = @{}
            foreach ($Key in $QueryParameters.Keys) {
                $Query[$Key] = $QueryParameters[$Key]
            }
            $Query.Server = $Server
            $Query.ResultPageSize = $PageSize
            $Query.ResultSetSize = $null
            $Query.ErrorAction = 'Stop'

            $Started = Get-Date
            try {
                Write-Color -Text '[i] ', "Querying $Domain through $Server (attempt $Attempt of $MaxAttemptsPerServer, page size $PageSize)..." -Color Yellow, Cyan
                [Array] $PreparedComputers = @(
                    Get-ADComputer @Query | ConvertTo-PreparedComputer `
                        -AzureInformationCache $AzureInformationCache `
                        -JamfInformationCache $JamfInformationCache `
                        -IncludeAzureAD:$IncludeAzureAD.IsPresent `
                        -IncludeIntune:$IncludeIntune.IsPresent `
                        -IncludeJamf:$IncludeJamf.IsPresent `
                        -Today $Today
                )
                $Attempts.Add([PSCustomObject] [ordered] @{
                        Server       = $Server
                        Attempt      = $Attempt
                        PageSize     = $PageSize
                        Succeeded    = $true
                        Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                        ErrorMessage = $null
                    })
                return [PSCustomObject] [ordered] @{
                    Succeeded = $true
                    Server    = $Server
                    Computers = $PreparedComputers
                    Attempts  = $Attempts.ToArray()
                    Error     = $null
                }
            } catch {
                $LastError = $_
                $PreparedComputers = $null
                $Attempts.Add([PSCustomObject] [ordered] @{
                        Server       = $Server
                        Attempt      = $Attempt
                        PageSize     = $PageSize
                        Succeeded    = $false
                        Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                        ErrorMessage = $_.Exception.Message
                    })
                Write-Color -Text '[w] ', "AD query failed for $Domain through $Server`: $($_.Exception.Message)" -Color Yellow, DarkYellow

                if (Test-ADQueryConfigurationError -ErrorRecord $_) {
                    return [PSCustomObject] [ordered] @{
                        Succeeded = $false
                        Server    = $null
                        Computers = @()
                        Attempts  = $Attempts.ToArray()
                        Error     = $_.Exception.Message
                    }
                }
                if ($Attempt -lt $MaxAttemptsPerServer -and $Delay -gt 0) {
                    Start-Sleep -Seconds $Delay
                    $Delay = [math]::Min($Delay * 2, 300)
                }
            }
        }

        if ($PageSize -gt 500) {
            $FallbackPageSize = 500
            $Query = @{}
            foreach ($Key in $QueryParameters.Keys) {
                $Query[$Key] = $QueryParameters[$Key]
            }
            $Query.Server = $Server
            $Query.ResultPageSize = $FallbackPageSize
            $Query.ResultSetSize = $null
            $Query.ErrorAction = 'Stop'
            $Started = Get-Date
            try {
                Write-Color -Text '[i] ', "Retrying $Domain through $Server with page size $FallbackPageSize..." -Color Yellow, Cyan
                [Array] $PreparedComputers = @(
                    Get-ADComputer @Query | ConvertTo-PreparedComputer `
                        -AzureInformationCache $AzureInformationCache `
                        -JamfInformationCache $JamfInformationCache `
                        -IncludeAzureAD:$IncludeAzureAD.IsPresent `
                        -IncludeIntune:$IncludeIntune.IsPresent `
                        -IncludeJamf:$IncludeJamf.IsPresent `
                        -Today $Today
                )
                $Attempts.Add([PSCustomObject] [ordered] @{
                        Server       = $Server
                        Attempt      = 'SmallPageFallback'
                        PageSize     = $FallbackPageSize
                        Succeeded    = $true
                        Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                        ErrorMessage = $null
                    })
                return [PSCustomObject] [ordered] @{
                    Succeeded = $true
                    Server    = $Server
                    Computers = $PreparedComputers
                    Attempts  = $Attempts.ToArray()
                    Error     = $null
                }
            } catch {
                $LastError = $_
                $PreparedComputers = $null
                $Attempts.Add([PSCustomObject] [ordered] @{
                        Server       = $Server
                        Attempt      = 'SmallPageFallback'
                        PageSize     = $FallbackPageSize
                        Succeeded    = $false
                        Duration     = (New-TimeSpan -Start $Started -End (Get-Date))
                        ErrorMessage = $_.Exception.Message
                    })
                Write-Color -Text '[w] ', "Small-page AD query failed for $Domain through $Server`: $($_.Exception.Message)" -Color Yellow, DarkYellow
                if (Test-ADQueryConfigurationError -ErrorRecord $_) {
                    break
                }
            }
        }
    }

    [PSCustomObject] [ordered] @{
        Succeeded = $false
        Server    = $null
        Computers = @()
        Attempts  = $Attempts.ToArray()
        Error     = if ($LastError) { $LastError.Exception.Message } else { "No domain controller was available for $Domain." }
    }
}
