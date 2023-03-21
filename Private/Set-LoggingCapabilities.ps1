function Set-LoggingCapabilities {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Configuration
    )
    if ($Configuration.LogPath) {
        $FolderPath = [io.path]::GetDirectoryName($Configuration.LogPath)
        if (-not (Test-Path -LiteralPath $FolderPath)) {
            $null = New-Item -Path $FolderPath -ItemType Directory -Force -WhatIf:$false
        }
        $Script:PSDefaultParameterValues = @{
            "Write-Color:LogFile" = $Configuration.LogPath
        }

        $CurrentLogs = Get-ChildItem -LiteralPath $FolderPath | Sort-Object -Property CreationTime -Descending | Select-Object -Skip $Configuration.LogMaximum
        if ($CurrentLogs) {
            Write-Color -Text '[i] ', "Logs directory has more than ", $Configuration.LogMaximum, " log files. Cleanup required..." -Color Yellow, DarkCyan, Red, DarkCyan
            foreach ($Log in $CurrentLogs) {
                try {
                    Remove-Item -LiteralPath $Log.FullName -Confirm:$false -WhatIf:$false
                    Write-Color -Text '[+] ', "Deleted ", "$($Log.FullName)" -Color Yellow, White, Green
                } catch {
                    Write-Color -Text '[-] ', "Couldn't delete log file $($Log.FullName). Error: ', "$($_.Exception.Message) -Color Yellow, White, Red
                }
            }
        }
    }
}