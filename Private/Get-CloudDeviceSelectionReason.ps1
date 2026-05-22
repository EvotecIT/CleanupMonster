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
    } elseif ($null -ne $ActionIf.LastSeenEntraMoreThan -and $ActionIf.IncludeUnknownActivity -and $null -eq $Device.EntraLastSeenDays) {
        $reasons.Add("EntraLastSeenDays=Unknown allowed")
    }

    if ($null -ne $ActionIf.LastSeenIntuneMoreThan -and $null -ne $Device.IntuneLastSeenDays) {
        $reasons.Add("IntuneLastSeenDays=$($Device.IntuneLastSeenDays) > $($ActionIf.LastSeenIntuneMoreThan)")
    } elseif ($null -ne $ActionIf.LastSeenIntuneMoreThan -and $ActionIf.IncludeUnknownActivity -and $null -eq $Device.IntuneLastSeenDays) {
        $reasons.Add("IntuneLastSeenDays=Unknown allowed")
    }

    if ($null -ne $ActionIf.RegisteredMoreThan -and $null -ne $Device.RegisteredDays) {
        $reasons.Add("RegisteredDays=$($Device.RegisteredDays) > $($ActionIf.RegisteredMoreThan)")
    }

    if ($ActionIf.EnabledState -and $ActionIf.EnabledState -ne 'Any') {
        $reasons.Add("EnabledState=$($ActionIf.EnabledState)")
    }

    if ($ActionIf.AutopilotState -and $ActionIf.AutopilotState -ne 'Any') {
        $reasons.Add("AutopilotState=$($ActionIf.AutopilotState)")
    }

    if ($ActionIf.OwnerState -and $ActionIf.OwnerState -ne 'Any') {
        $reasons.Add("OwnerState=$($ActionIf.OwnerState)")
    }

    if ($ActionIf.ManagementState -and $ActionIf.ManagementState -ne 'Any') {
        $reasons.Add("ManagementState=$($ActionIf.ManagementState)")
    }

    if ($ActionIf.ComplianceState -and $ActionIf.ComplianceState -ne 'Any') {
        $reasons.Add("ComplianceState=$($ActionIf.ComplianceState)")
    }

    foreach ($key in @('IncludeManagementAgent', 'ExcludeManagementAgent', 'IncludeEnrollmentType', 'ExcludeEnrollmentType', 'IncludeDeviceRegistrationState', 'ExcludeDeviceRegistrationState', 'IncludeAutopilotGroupTag', 'ExcludeAutopilotGroupTag')) {
        if ($ActionIf.Contains($key) -and $ActionIf[$key] -and $ActionIf[$key].Count -gt 0) {
            $reasons.Add("$key=$($ActionIf[$key] -join ',')")
        }
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
        if ($Device.RecordState -eq 'Matched' -and $Device.HasIntuneRecord -and $Device.HasEntraRecord) {
            $reasons.Add('Delete Intune record and Entra device object')
        } elseif ($Device.RecordState -eq 'IntuneOnly' -and $Device.HasIntuneRecord) {
            $reasons.Add('Delete Intune orphan record')
            $reasons.Add("IncludeIntuneOnly=$($ActionIf.IncludeIntuneOnly)")
        } elseif ($Device.RecordState -eq 'EntraOnly' -and $Device.HasEntraRecord) {
            $reasons.Add('Delete Entra orphan record')
            $reasons.Add("IncludeEntraOnly=$($ActionIf.IncludeEntraOnly)")
        } elseif ($Device.HasIntuneRecord -and $Device.HasEntraRecord) {
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
