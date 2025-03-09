function Remove-SIDHistory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Array] $ObjectsToProcess,
        [System.Collections.IDictionary] $Export
    )
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
                    #Set-ADObject -Identity $Object.DistinguishedName -Remove @{ SIDHistory = $SID } -Server $QueryServer
                    $GlobalLimitSID++
                    $ProcessedSIDs++
                }
            }
        } else {
            # Process all SIDs for this object at once
            if ($PSCmdlet.ShouldProcess("$($Object.Name) ($($Object.Domain))", "Remove all SID History entries")) {
                Write-Color -Text "[i] ", "Removing all SID History entries from ", $Object.Name -Color Yellow, White, Green
                #Set-ADObject -Identity $Object.DistinguishedName -Clear SIDHistory -Server $QueryServer
                $ProcessedSIDs += $Object.SIDHistory.Count
                $ProcessedObjects++
            }
        }

        $Export.History.Add(
            [PSCustomObject]@{
                ObjectDN     = $Object.DistinguishedName
                ObjectName   = $Object.Name
                ObjectDomain = $Object.Domain
                SID          = $SID
                Action       = 'Remove'
                ActionDate   = Get-Date
            }
        )
    }
}