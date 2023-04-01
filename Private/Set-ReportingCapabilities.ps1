function Set-ReportingCapabilities {
    [CmdletBinding()]
    param(
        [string] $ReportPath,
        [int] $ReportMaximum
    )
    if ($ReportPath) {
        $FolderPath = [io.path]::GetDirectoryName($ReportPath)
        if (-not (Test-Path -LiteralPath $FolderPath)) {
            $null = New-Item -Path $FolderPath -ItemType Directory -Force -WhatIf:$false
        }
        if ($ReportMaximum -gt 0) {
            $CurrentLogs = Get-ChildItem -LiteralPath $FolderPath | Sort-Object -Property CreationTime -Descending | Select-Object -Skip $ReportMaximum
            if ($CurrentLogs) {
                Write-Color -Text '[i] ', "Reporting directory has more than ", $ReportMaximum, " report files. Cleanup required..." -Color Yellow, DarkCyan, Red, DarkCyan
                foreach ($Report in $CurrentLogs) {
                    try {
                        Remove-Item -LiteralPath $Report.FullName -Confirm:$false -WhatIf:$false
                        Write-Color -Text '[+] ', "Deleted ", "$($Report.FullName)" -Color Yellow, White, Green
                    } catch {
                        Write-Color -Text '[-] ', "Couldn't delete report file $($Report.FullName). Error: ', "$($_.Exception.Message) -Color Yellow, White, Red
                    }
                }
            }
        } else {
            Write-Color -Text '[i] ', "ReportMaximum is set to 0 (Unlimited). No report files will be deleted." -Color Yellow, DarkCyan
        }
    }
}