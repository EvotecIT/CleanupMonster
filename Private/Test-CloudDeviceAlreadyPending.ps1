function Test-CloudDeviceAlreadyPending {
    <#
    .SYNOPSIS
    Checks the matched or current pending key used by deletion staging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $Device,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $ProcessedDevices
    )

    foreach ($property in @('MatchedProcessedDeviceKey', 'ProcessedDeviceKey')) {
        if (-not $Device.PSObject.Properties[$property]) { continue }
        $key = $Device.$property
        if ($key -and $ProcessedDevices.Contains($key)) { return $true }
    }
    $false
}
