function Remove-SIDHistory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $ObjectsToProcess,
        [System.Collections.IDictionary] $Export
    )
    Write-Color -Text "[i] ", "Removing SID History entries from ", $ObjectsToProcess.Count, " objects" -Color Yellow, White, Green

    $ProcessedSIDs = 0
    $ProcessedObjects = 0

    foreach ($Item in $ObjectsToProcess) {
        $Object = $Item.Object
        $QueryServer = $Item.QueryServer

        if ($LimitPerSID) {
            # Process individual SIDs for this object
            foreach ($SID in $Object.SIDHistory) {
                if ($GlobalLimitSID -ge $RemoveLimit) {
                    Write-Color -Text "[i] ", "Reached SID limit of ", $RemoveLimit, ". Stopping processing." -Color Yellow, White, Green, White
                    break
                }
                if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove SID History entry $SID")) {
                    Write-Color -Text "[i] ", "Removing SID History entry $SID from ", $Object.Name -Color Yellow, White, Green
                    try {
                        Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer -ErrorAction Stop
                        $Result = [PSCustomObject]@{
                            ObjectDN     = $Object.DistinguishedName
                            ObjectName   = $Object.Name
                            ObjectDomain = $Object.Domain
                            SID          = $SID
                            Action       = 'RemovePerSID'
                            ActionDate   = Get-Date
                            ActionStatus = 'Success'
                        }
                        $Export.History.Add($Result)
                    } catch {
                        Write-Color -Text "[!] ", "Failed to remove SID History entry $SID from ", $Object.Name -Color Yellow, White, Red
                        $Result = [PSCustomObject]@{
                            ObjectDN     = $Object.DistinguishedName
                            ObjectName   = $Object.Name
                            ObjectDomain = $Object.Domain
                            SID          = $SID
                            Action       = 'RemovePerSID'
                            ActionDate   = Get-Date
                            ActionStatus = 'Failed'
                        }
                        $Export.History.Add($Result)
                        continue
                    }
                    Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer
                    $GlobalLimitSID++
                    $ProcessedSIDs++
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
                    }
                    $Export.History.Add($Result)
                }
            }
        } else {
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
                        ActionDate   = Get-Date
                        ActionStatus = 'Success'
                    }
                    $Export.History.Add($Result)
                } catch {
                    Write-Color -Text "[!] ", "Failed to remove SID History entries from ", $Object.Name -Color Yellow, White, Red
                    $Result = [PSCustomObject]@{
                        ObjectDN     = $Object.DistinguishedName
                        ObjectName   = $Object.Name
                        ObjectDomain = $Object.Domain
                        SID          = $Object.SIDHistory -join ", "
                        Action       = 'RemoveAll'
                        ActionDate   = Get-Date
                        ActionStatus = 'Failed'
                    }
                    $Export.History.Add($Result)
                    continue
                }
                $ProcessedSIDs += $Object.SIDHistory.Count
                $ProcessedObjects++
            } else {
                Write-Color -Text "[i] ", "Would have removed all SID History entries from ", $Object.Name -Color Yellow, White, Green
                $Result = [PSCustomObject]@{
                    ObjectDN     = $Object.DistinguishedName
                    ObjectName   = $Object.Name
                    ObjectDomain = $Object.Domain
                    SID          = $Object.SIDHistory -join ", "
                    Action       = 'RemoveAll'
                    ActionDate   = Get-Date
                    ActionStatus = 'WhatIf'
                }
                $Export.History.Add($Result)
            }
        }
    }
    $Export['ProcessedObjects'] = $ProcessedObjects
    $Export['ProcessedSIDs'] = $ProcessedSIDs

    Write-Color -Text "[i] ", "Processed ", $ProcessedObjects, " objects and ", $ProcessedSIDs, " SID History entries" -Color Yellow, White, Green
}