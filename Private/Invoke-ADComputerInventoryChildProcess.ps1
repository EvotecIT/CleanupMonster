function Invoke-ADComputerInventoryChildProcess {
    <#
    .SYNOPSIS
    Executes one AD computer query inside an isolated Windows PowerShell process.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ConfigurationPath
    )

    try {
        $Configuration = Import-Clixml -LiteralPath $ConfigurationPath -ErrorAction Stop
        Import-Module ActiveDirectory -ErrorAction Stop

        # Use the AD cmdlet itself for readiness so every supported -Server form,
        # including domain locator and host:port values, retains its native meaning.
        Get-ADRootDSE -Server $Configuration.Server -ErrorAction Stop | Out-Null
        [System.IO.File]::WriteAllText($Configuration.ReadyPath, 'Ready', [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($Configuration.ProgressPath, '0', [System.Text.Encoding]::UTF8)

        $Query = @{
            Filter         = $Configuration.Filter
            Properties     = @($Configuration.Properties)
            Server         = $Configuration.Server
            ResultPageSize = $Configuration.PageSize
            ResultSetSize  = $null
            ErrorAction    = 'Stop'
        }
        if ($Configuration.SearchBase) {
            $Query.SearchBase = $Configuration.SearchBase
        }

        $Count = 0
        Get-ADComputer @Query | ForEach-Object {
            $Count++
            if ($Count -eq 1 -or $Count % 100 -eq 0) {
                [System.IO.File]::WriteAllText($Configuration.ProgressPath, [string] $Count, [System.Text.Encoding]::UTF8)
            }

            [PSCustomObject] [ordered] @{
                Name                            = $_.Name
                DNSHostName                     = $_.DNSHostName
                SamAccountName                  = $_.SamAccountName
                DistinguishedName               = $_.DistinguishedName
                Enabled                         = $_.Enabled
                OperatingSystem                 = $_.OperatingSystem
                OperatingSystemVersion          = $_.OperatingSystemVersion
                LastLogonDateBinary              = if ($null -ne $_.LastLogonDate) { $_.LastLogonDate.ToBinary() } else { $null }
                PasswordLastSetBinary            = if ($null -ne $_.PasswordLastSet) { $_.PasswordLastSet.ToBinary() } else { $null }
                PasswordExpired                 = $_.PasswordExpired
                ServicePrincipalNameJson        = ConvertTo-Json -InputObject @($_.servicePrincipalName) -Compress
                LogonCount                      = $_.logonCount
                ManagedBy                       = $_.ManagedBy
                Description                     = $_.Description
                WhenCreatedBinary               = if ($null -ne $_.WhenCreated) { $_.WhenCreated.ToBinary() } else { $null }
                WhenChangedBinary               = if ($null -ne $_.WhenChanged) { $_.WhenChanged.ToBinary() } else { $null }
                ProtectedFromAccidentalDeletion = $_.ProtectedFromAccidentalDeletion
            }
        } | Export-Csv -LiteralPath $Configuration.DataPath -NoTypeInformation -Encoding UTF8

        [System.IO.File]::WriteAllText($Configuration.SuccessPath, [string] $Count, [System.Text.Encoding]::UTF8)
    } catch {
        if ($null -ne $Configuration -and $Configuration.ErrorPath) {
            [System.IO.File]::WriteAllText($Configuration.ErrorPath, $_.Exception.Message, [System.Text.Encoding]::UTF8)
        } else {
            Write-Error -ErrorRecord $_
        }
        exit 1
    }
}
