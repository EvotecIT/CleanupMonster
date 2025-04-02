function Remove-ADSIDHistory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $ObjectsToProcess,
        [System.Collections.IDictionary] $Export,
        [int] $RemoveLimitSID
    )
    Write-Color -Text "[i] ", "Starting process of removing SID History entries from ", $ObjectsToProcess.Count, " objects" -Color Yellow, White, Green

    $GlobalLimitSID = 0
    $ProcessedSIDs = 0
    $ProcessedObjects = 0

    $Export['CurrentRun'] = [System.Collections.Generic.List[PSCustomObject]]::new()

    :TopLoop foreach ($Item in $ObjectsToProcess) {
        $Object = $Item.Object
        $QueryServer = $Item.QueryServer

        $CurrentRunObject = [PSCustomObject] @{
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
            ObjectDN       = $Object.DistinguishedName
        }

        $ProcessedObjects++

        # Process individual SIDs for this object
        foreach ($SID in $Object.SIDHistory) {
            $CurrentDate = Get-Date
            if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove SID History entry $SID")) {
                Write-Color -Text "[i] ", "Removing SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                try {
                    Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer -ErrorAction Stop
                    $Result = [PSCustomObject]@{
                        ObjectName   = $Object.Name
                        ObjectDomain = $Object.Domain
                        Enabled      = $Object.Enabled
                        SID          = $SID
                        Action       = 'RemovePerSID'
                        ActionDate   = $CurrentDate
                        ActionStatus = 'Success'
                        ActionError  = ''
                        ObjectDN     = $Object.DistinguishedName
                    }
                    $CurrentRunObject.Action = 'RemovePerSID'
                    $CurrentRunObject.ActionDate = $CurrentDate
                    $CurrentRunObject.ActionStatus = 'Success'
                    $CurrentRunObject.ActionError = ''
                    $CurrentRunObject.SIDRemoved += $SID
                    Write-Color -Text "[+] ", "Removed SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                } catch {
                    Write-Color -Text "[!] ", "Failed to remove SID History entry $SID from ", $Object.Name, " exception: ", $_.Exception.Message -Color Yellow, White, Red
                    $Result = [PSCustomObject]@{
                        ObjectName   = $Object.Name
                        ObjectDomain = $Object.Domain
                        SID          = $SID
                        Action       = 'RemovePerSID'
                        ActionDate   = $CurrentDate
                        ActionStatus = 'Failed'
                        ActionError  = $_.Exception.Message
                        ObjectDN     = $Object.DistinguishedName
                    }
                    $CurrentRunObject.Action = 'RemovePerSID'
                    $CurrentRunObject.ActionDate = $CurrentDate
                    $CurrentRunObject.ActionStatus = 'Failed'
                    $CurrentRunObject.ActionError = $_.Exception.Message
                }
            } else {
                Write-Color -Text "[i] ", "Would have removed SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                $Result = [PSCustomObject]@{
                    ObjectName   = $Object.Name
                    ObjectDomain = $Object.Domain
                    SID          = $SID
                    Action       = 'RemovePerSID'
                    ActionDate   = Get-Date
                    ActionStatus = 'WhatIf'
                    ActionError  = ''
                    ObjectDN     = $Object.DistinguishedName
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

            if ($GlobalLimitSID -ge $RemoveLimitSID) {
                Write-Color -Text "[i] ", "Reached SID limit of ", $RemoveLimitSID, ". Stopping processing." -Color Yellow, White, Green, White
                break TopLoop
            }
        }
    }
    $Export['ProcessedObjects'] = $ProcessedObjects
    $Export['ProcessedSIDs'] = $ProcessedSIDs

    Write-Color -Text "[i] ", "Processed ", $ProcessedObjects, " objects out of ", $ObjectsToProcess.Count, " and removed ", $ProcessedSIDs, " SID History entries" -Color Yellow, White, Green, White, Green, White, Green, White
}