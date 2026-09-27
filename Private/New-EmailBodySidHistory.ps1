function New-EmailBodySidHistory {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export
    )

    $report = Get-SIDHistoryEmailReport -Export $Export
    # The PSWriteHTML header, summary table and result table live in this shared template.
    $emailParameters = @{
        Title       = 'SID history cleanup'
        Report      = $report
        ObjectLabel = 'Object'
    }
    New-EmailBodyCleanup @emailParameters
}
