function Get-InitialJamfComputers {
    [CmdletBinding()]
    param(
        [bool] $DisableLastContactJamfMoreThan,
        [bool] $DeleteLastContactJamfMoreThan
    )
    $JamfCache = [ordered] @{}
    if ($PSBoundParameters.ContainsKey('DisableLastContactJamfMoreThan') -or $PSBoundParameters.ContainsKey('DeleteLastContactJamfMoreThan')) {
        Write-Color "[i] ", "Getting all computers from Jamf" -Color Yellow, Cyan, Green
        [Array] $Jamf = Get-JamfDevice -Verbose -WarningAction SilentlyContinue -WarningVariable WarningVar
        if ($WarningVar) {
            Write-Color "[e] ", "Error getting computers from Jamf: ", $WarningVar, " Terminating!" -Color Yellow, Red, Yellow, Red
            return $false
        }
        if ($Jamf.Count -eq 0) {
            Write-Color "[e] ", "No computers found in Jamf, terminating! Please disable Jamf integration or fix connectivity." -Color Yellow, Red
            return $false
        } else {
            Write-Color "[i] ", "Computers found in Jamf`: ", $($Jamf.Count) -Color Yellow, Cyan, Green
        }
        foreach ($device in $Jamf) {
            $JamfCache[$Device.Name] = $device
        }
        $Script:CleanupOptions.Jamf = $true
    }
    $JamfCache
}