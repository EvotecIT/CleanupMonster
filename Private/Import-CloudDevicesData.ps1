function Import-CloudDevicesData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DataStorePath,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Export
    )

    $processedDevices = [ordered] @{}
    $today = Get-Date

    try {
        if ($DataStorePath -and (Test-Path -LiteralPath $DataStorePath -ErrorAction Stop)) {
            $fileImport = Import-Clixml -LiteralPath $DataStorePath -ErrorAction Stop

            if ($fileImport.PendingActions) {
                if ($fileImport.PendingActions.GetType().Name -notin 'Hashtable', 'OrderedDictionary') {
                    Write-Color -Text '[e] ', 'Incorrect XML format. PendingActions is not a hashtable/ordereddictionary. Terminating.' -Color Yellow, Red
                    return $false
                }
            }

            if ($fileImport.History) {
                if ($fileImport.History.GetType().Name -notin 'ArrayList', 'Object[]') {
                    Write-Color -Text '[e] ', 'Incorrect XML format. History is not an array. Terminating.' -Color Yellow, Red
                    return $false
                }
            }

            $processedDevices = if ($fileImport.PendingActions) { $fileImport.PendingActions } else { [ordered] @{} }
            foreach ($deviceKey in @($processedDevices.Keys)) {
                $device = $processedDevices[$deviceKey]
                $timeOnPendingList = if ($device.ActionDate) {
                    - ($device.ActionDate - $today).Days
                } else {
                    $null
                }

                if ($device.PSObject.Properties.Name -notcontains 'TimeOnPendingList') {
                    Add-Member -InputObject $device -MemberType NoteProperty -Name 'TimeOnPendingList' -Value $timeOnPendingList -Force
                    Add-Member -InputObject $device -MemberType NoteProperty -Name 'TimeToNextAction' -Value $null -Force
                } else {
                    $device.TimeOnPendingList = $timeOnPendingList
                }
            }

            $Export.History = @($fileImport.History)
        }
    } catch {
        Write-Color -Text '[e] ', "Couldn't read cloud device list or wrong format. Error: $($_.Exception.Message)" -Color Yellow, Red
        return $false
    }

    $processedDevices
}
