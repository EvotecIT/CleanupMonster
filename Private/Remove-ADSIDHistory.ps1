function Remove-ADSIDHistory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $ObjectsToProcess,
        [System.Collections.IDictionary] $Export
    )
    Write-Color -Text "[i] ", "Removing SID History entries from ", $ObjectsToProcess.Count, " objects" -Color Yellow, White, Green

    $GlobalLimitSID = 0
    $ProcessedSIDs = 0
    $ProcessedObjects = 0

    $Export['CurrentRun'] = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($Item in $ObjectsToProcess) {
        $Object = $Item.Object
        $QueryServer = $Item.QueryServer

        $CurrentRunObject = [PSCustomObject] @{
            ObjectDN       = $Object.DistinguishedName
            ObjectName     = $Object.Name
            ObjectDomain   = $Object.Domain
            Enabled        = $Object.Enabled
            SIDBefore      = $Object.SIDHistory -join ", "
            SIDBeforeCount = $Object.SIDHistory.Count
            Action         = $null
            ActionDate     = $null
            ActionStatus   = $null
            ActionError    = ''
            SIDRemoved     = @()
            SIDAfter       = @()
            SIDAfterCount  = 0
        }

        if ($LimitPerSID) {
            # Process individual SIDs for this object
            foreach ($SID in $Object.SIDHistory) {
                $CurrentDate = Get-Date
                if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove SID History entry $SID")) {
                    Write-Color -Text "[i] ", "Removing SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                    try {
                        Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer -ErrorAction Stop
                        $Result = [PSCustomObject]@{
                            ObjectDN     = $Object.DistinguishedName
                            ObjectName   = $Object.Name
                            ObjectDomain = $Object.Domain
                            Enabled      = $Object.Enabled
                            SID          = $SID
                            Action       = 'RemovePerSID'
                            ActionDate   = $CurrentDate
                            ActionStatus = 'Success'
                            ActionError  = ''
                        }
                        $CurrentRunObject.Action = 'RemovePerSID'
                        $CurrentRunObject.ActionDate = $CurrentDate
                        $CurrentRunObject.ActionStatus = 'Success'
                        $CurrentRunObject.ActionError = ''
                        $CurrentRunObject.SIDRemoved += $SID
                    } catch {
                        Write-Color -Text "[!] ", "Failed to remove SID History entry $SID from ", $Object.Name -Color Yellow, White, Red
                        $Result = [PSCustomObject]@{
                            ObjectDN     = $Object.DistinguishedName
                            ObjectName   = $Object.Name
                            ObjectDomain = $Object.Domain
                            SID          = $SID
                            Action       = 'RemovePerSID'
                            ActionDate   = $CurrentDate
                            ActionStatus = 'Failed'
                            ActionError  = $_.Exception.Message
                        }
                        $CurrentRunObject.Action = 'RemovePerSID'
                        $CurrentRunObject.ActionDate = $CurrentDate
                        $CurrentRunObject.ActionStatus = 'Failed'
                        $CurrentRunObject.ActionError = $_.Exception.Message
                    }
                } else {
                    Write-Color -Text "[i] ", "Would have removed SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                    $Result = [PSCustomObject]@{
                        ObjectDN     = $Object.DistinguishedName
                        ObjectName   = $Object.Name
                        ObjectDomain = $Object.Domain
                        SID          = $SID
                        Action       = 'RemovePerSID'
                        ActionDate   = Get-Date
                        ActionStatus = 'WhatIf'
                        ActionError  = ''
                    }
                    $CurrentRunObject.SIDRemoved += $SID
                    $CurrentRunObject.Action = 'RemovePerSID'
                    $CurrentRunObject.ActionDate = $CurrentDate
                    $CurrentRunObject.ActionStatus = 'WhatIf'
                    $CurrentRunObject.ActionError = ''
                }
                $null = $Export.History.Add($Result)

                try {
                    $RefreshedObject = Get-ADObject -Identity $Object.DistinguishedName -Properties SIDHistory -Server $QueryServer -ErrorAction Stop
                } catch {
                    Write-Color -Text "[!] ", "Failed to refresh object ", $Object.Name, " exception: ", $_.Exception.Message -Color Yellow, White, Red, Red
                    $RefreshedObject = $null
                }
                if ($RefreshedObject -and $RefreshedObject.SIDHistory) {
                    $CurrentRunObject.SIDAfter = $RefreshedObject.SIDHistory -join ", "
                } else {
                    $CurrentRunObject.SIDAfter = $null
                }

                $CurrentRunObject.SIDAfterCount = $RefreshedObject.SIDHistory.Count
                $Export.CurrentRun.Add($CurrentRunObject)
                $GlobalLimitSID++
                $ProcessedSIDs++

                if ($GlobalLimitSID -ge $RemoveLimit) {
                    Write-Color -Text "[i] ", "Reached SID limit of ", $RemoveLimit, ". Stopping processing." -Color Yellow, White, Green, White
                    break
                }
            }
            $ProcessedObjects++
        } else {
            $CurrentDate = Get-Date
            # Process all SIDs for this object at once
            if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove all SID History entries")) {
                Write-Color -Text "[i] ", "Removing all SID History entries from ", $Object.Name -Color Yellow, White, Green
                try {
                    Set-ADObject -Identity $Object.DistinguishedName -Clear SIDHistory -Server $QueryServer -ErrorAction Stop
                    $Result = [PSCustomObject]@{
                        ObjectDN     = $Object.DistinguishedName
                        ObjectName   = $Object.Name
                        ObjectDomain = $Object.Domain
                        SID          = $Object.SIDHistory -join ", "
                        Action       = 'RemoveAll'
                        ActionDate   = $CurrentDate
                        ActionStatus = 'Success'
                        ActionError  = ''
                    }
                    $CurrentRunObject.ActionStatus = 'Success'
                    $CurrentRunObject.ActionError = ''
                } catch {
                    Write-Color -Text "[!] ", "Failed to remove SID History entries from ", $Object.Name -Color Yellow, White, Red
                    $Result = [PSCustomObject]@{
                        ObjectDN     = $Object.DistinguishedName
                        ObjectName   = $Object.Name
                        ObjectDomain = $Object.Domain
                        SID          = $Object.SIDHistory -join ", "
                        Action       = 'RemoveAll'
                        ActionDate   = $CurrentDate
                        ActionStatus = 'Failed'
                        ActionError  = $_.Exception.Message
                    }
                    $CurrentRunObject.ActionStatus = 'Failed'
                    $CurrentRunObject.ActionError = $_.Exception.Message
                }
            } else {
                Write-Color -Text "[i] ", "Would have removed all SID History entries from ", $Object.Name -Color Yellow, White, Green
                $Result = [PSCustomObject]@{
                    ObjectDN     = $Object.DistinguishedName
                    ObjectName   = $Object.Name
                    ObjectDomain = $Object.Domain
                    SID          = $Object.SIDHistory -join ", "
                    Action       = 'RemoveAll'
                    ActionDate   = $CurrentDate
                    ActionStatus = 'WhatIf'
                    ActionError  = ''
                }
                $CurrentRunObject.ActionStatus = 'WhatIf'
                $CurrentRunObject.ActionError = ''
            }
            $CurrentRunObject.SIDRemoved += $Object.SIDHistory
            $CurrentRunObject.Action = 'RemoveAll'
            $CurrentRunObject.ActionDate = $CurrentDate
            $CurrentRunObject.ActionError = ''

            $null = $Export.History.Add($Result)

            try {
                $RefreshedObject = Get-ADObject -Identity $Object.DistinguishedName -Properties SIDHistory -Server $QueryServer -ErrorAction Stop
            } catch {
                Write-Color -Text "[!] ", "Failed to refresh object ", $Object.Name, " exception: ", $_.Exception.Message -Color Yellow, White, Red, Red
                $RefreshedObject = $null
            }
            if ($RefreshedObject -and $RefreshedObject.SIDHistory) {
                $CurrentRunObject.SIDAfter = $RefreshedObject.SIDHistory -join ", "
            } else {
                $CurrentRunObject.SIDAfter = $null
            }

            $CurrentRunObject.SIDAfterCount = $RefreshedObject.SIDHistory.Count
            $Export.CurrentRun.Add($CurrentRunObject)
            $ProcessedSIDs += $Object.SIDHistory.Count
            $ProcessedObjects++
        }
    }
    $Export['ProcessedObjects'] = $ProcessedObjects
    $Export['ProcessedSIDs'] = $ProcessedSIDs

    Write-Color -Text "[i] ", "Processed ", $ProcessedObjects, " objects and ", $ProcessedSIDs, " SID History entries" -Color Yellow, White, Green, White, Green, White
}