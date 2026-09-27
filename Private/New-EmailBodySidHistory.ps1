function New-EmailBodySidHistory {
    [CmdletBinding()]
    param([System.Collections.IDictionary] $Export)

    $report = Get-SIDHistoryEmailReport -Export $Export
    New-EmailBodyCleanup -Title 'SID history cleanup' -Report $report -ObjectLabel 'Object'
}
