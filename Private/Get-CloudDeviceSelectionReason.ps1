function Get-CloudDeviceSelectionReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject] $Device,

        [Parameter(Mandatory)]
        [ValidateSet('Retire', 'Disable', 'Delete')]
        [string] $Type,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $ActionIf,

        [PSObject] $ProcessedDevice
    )

    $reasons = [System.Collections.Generic.List[string]]::new()

    $reasons.Add("RecordState=$($Device.RecordState)")

    if ($null -ne $ActionIf.LastSeenEntraMoreThan -and $null -ne $Device.EntraLastSeenDays) {
        $reasons.Add("EntraLastSeenDays=$($Device.EntraLastSeenDays) > $($ActionIf.LastSeenEntraMoreThan)")
    }

    if ($null -ne $ActionIf.LastSeenIntuneMoreThan -and $null -ne $Device.IntuneLastSeenDays) {
        $reasons.Add("IntuneLastSeenDays=$($Device.IntuneLastSeenDays) > $($ActionIf.LastSeenIntuneMoreThan)")
    }

    if ($null -ne $ActionIf.ListProcessedMoreThan -and $ProcessedDevice -and $ProcessedDevice.ActionDate) {
        $pendingDays = (New-TimeSpan -Start $ProcessedDevice.ActionDate -End (Get-Date)).Days
        $reasons.Add("PendingDays=$pendingDays >= $($ActionIf.ListProcessedMoreThan)")
        $reasons.Add("PreviousAction=$($ProcessedDevice.Action)")
    }

    if ($Type -eq 'Retire' -and $Device.HasIntuneRecord) {
        $reasons.Add('Retire via Intune managed device')
        if ($Device.RecordState -eq 'IntuneOnly') {
            $reasons.Add("IncludeIntuneOnly=$($ActionIf.IncludeIntuneOnly)")
        }
    }

    if ($Type -eq 'Disable' -and $Device.HasEntraRecord) {
        $reasons.Add('Disable via Microsoft Entra device object')
        if ($Device.RecordState -eq 'EntraOnly') {
            $reasons.Add("IncludeEntraOnly=$($ActionIf.IncludeEntraOnly)")
        }
    }

    if ($Type -eq 'Delete') {
        if ($Device.HasIntuneRecord -and $Device.HasEntraRecord) {
            $reasons.Add('Delete Intune record and Entra device object')
        } elseif ($Device.HasIntuneRecord) {
            $reasons.Add('Delete Intune orphan record')
            $reasons.Add("IncludeIntuneOnly=$($ActionIf.IncludeIntuneOnly)")
        } elseif ($Device.HasEntraRecord) {
            $reasons.Add('Delete Entra orphan record')
            $reasons.Add("IncludeEntraOnly=$($ActionIf.IncludeEntraOnly)")
        }
    }

    $reasons -join '; '
}
