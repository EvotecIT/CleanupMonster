function Get-InitialJamfComputers {
    [CmdletBinding()]
    param(
        [bool] $DisableLastContactJamfMoreThan,
        [bool] $MoveLastContactJamfMoreThan,
        [bool] $DeleteLastContactJamfMoreThan,
        [nullable[int]] $SafetyJamfLimit
    )
    $JamfCache = [ordered] @{}
    if ($PSBoundParameters.ContainsKey('DisableLastContactJamfMoreThan') -or
        $PSBoundParameters.ContainsKey('DeleteLastContactJamfMoreThan') -or
        $PSBoundParameters.ContainsKey('MoveLastContactJamfMoreThan')
    ) {
        Write-Color "[i] ", "Getting all computers from Jamf" -Color Yellow, Cyan, Green
        [Array] $Jamf = Get-JamfDevice -WarningAction SilentlyContinue -WarningVariable WarningVar
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

        if ($null -ne $SafetyJamfLimit -and $Jamf.Count -lt $SafetyJamfLimit) {
            Write-Color "[e] ", "Only ", $($Jamf.Count), " computers found in Jamf, this is less than the safety limit of ", $SafetyJamfLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
            return $false
        }

        foreach ($device in $Jamf) {
            $JamfCache[$Device.Name] = $device
        }
    }
    $JamfCache
}