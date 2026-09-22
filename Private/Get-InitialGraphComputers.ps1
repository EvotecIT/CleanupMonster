function Get-InitialGraphComputers {
    [CmdletBinding()]
    param(
        [nullable[int]] $SafetyAzureADLimit,
        [nullable[int]] $SafetyIntuneLimit,
        [nullable[int]] $DeleteLastSeenAzureMoreThan,
        [nullable[int]] $DeleteLastSeenIntuneMoreThan,
        [nullable[int]] $DeleteLastSyncAzureMoreThan,
        [nullable[int]] $DisableLastSeenAzureMoreThan,
        [nullable[int]] $DisableLastSeenIntuneMoreThan,
        [nullable[int]] $DisableLastSyncAzureMoreThan,
        [nullable[int]] $MoveLastSeenAzureMoreThan,
        [nullable[int]] $MoveLastSeenIntuneMoreThan,
        [nullable[int]] $MoveLastSyncAzureMoreThan
    )

    $AzureInformationCache = [ordered] @{
        AzureAD = [ordered] @{}
        Intune  = [ordered] @{}
    }

    if ($PSBoundParameters.ContainsKey('DisableLastSeenAzureMoreThan') -or
        $PSBoundParameters.ContainsKey('DisableLastSyncAzureMoreThan') -or
        $PSBoundParameters.ContainsKey('DeleteLastSeenAzureMoreThan') -or
        $PSBoundParameters.ContainsKey('DeleteLastSyncAzureMoreThan') -or
        $PSBoundParameters.ContainsKey('MoveLastSeenAzureMoreThan') -or
        $PSBoundParameters.ContainsKey('MoveLastSyncAzureMoreThan')) {
        Write-Color "[i] ", "Getting synchronized computers from AzureAD (page progress follows)" -Color Yellow, Cyan, Green

        [Array] $Devices = @(Get-MyDevice -Synchronized -PropertySet Computer -ReportProgress -WarningAction SilentlyContinue -WarningVariable WarningVar 6>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.InformationRecord]) {
                Write-Color "[i] ", ([string] $_.MessageData) -Color Yellow, Cyan
            } else {
                $_
            }
        })
        if ($WarningVar) {
            Write-Color "[e] ", "Error getting computers from AzureAD: ", $WarningVar, " Terminating!" -Color Yellow, Red, Yellow, Red
            return $false
        }
        if ($Devices.Count -eq 0) {
            Write-Color "[e] ", "No computers found in AzureAD, terminating! Please disable Azure AD integration or fix connectivity." -Color Yellow, Red
            return $false
        }
        Write-Color "[i] ", "AzureAD download complete. Indexing ", $Devices.Count, " computers for AD correlation." -Color Yellow, Cyan, Green, Cyan
        $indexedCount = 0
        foreach ($Device in $Devices) {
            $AzureInformationCache.AzureAD[$Device.Name] = $Device
            $indexedCount++
            if ($indexedCount % 25000 -eq 0) {
                Write-Color "[i] ", "Indexed ", $indexedCount, " of ", $Devices.Count, " AzureAD computers." -Color Yellow, Cyan, Green, Cyan, Green
            }
        }

        if ($null -ne $SafetyAzureADLimit -and $Devices.Count -lt $SafetyAzureADLimit) {
            Write-Color "[e] ", "Only ", $($Devices.Count), " computers found in AzureAD, this is less than the safety limit of ", $SafetyAzureADLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
            return $false
        }
        Write-Color "[i] ", "Synchronized Computers found in AzureAD`: ", $($Devices.Count) -Color Yellow, Cyan, Green
    }
    if ($PSBoundParameters.ContainsKey('DisableLastSeenIntuneMoreThan') -or
        $PSBoundParameters.ContainsKey('DeleteLastSeenIntuneMoreThan') -or
        $PSBoundParameters.ContainsKey('MoveLastSeenIntuneMoreThan')) {
        Write-Color "[i] ", "Getting synchronized computers from Intune (page progress follows)" -Color Yellow, Cyan, Green

        [Array] $DevicesIntune = @(Get-MyDeviceIntune -Synchronized -PropertySet Computer -ReportProgress -WarningAction SilentlyContinue -WarningVariable WarningVar 6>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.InformationRecord]) {
                Write-Color "[i] ", ([string] $_.MessageData) -Color Yellow, Cyan
            } else {
                $_
            }
        })
        if ($WarningVar) {
            Write-Color "[e] ", "Error getting computers from Intune: ", $WarningVar, " Terminating!" -Color Yellow, Red, Yellow, Red
            return $false
        }
        if ($DevicesIntune.Count -eq 0) {
            Write-Color "[e] ", "No computers found in Intune, terminating! Please disable Intune integration or fix connectivity." -Color Yellow, Red
            return $false
        }

        Write-Color "[i] ", "Intune download complete. Indexing ", $DevicesIntune.Count, " computers for AD correlation." -Color Yellow, Cyan, Green, Cyan
        $indexedIntuneCount = 0
        foreach ($device in $DevicesIntune) {
            $AzureInformationCache.Intune[$Device.Name] = $device
            $indexedIntuneCount++
            if ($indexedIntuneCount % 25000 -eq 0) {
                Write-Color "[i] ", "Indexed ", $indexedIntuneCount, " of ", $DevicesIntune.Count, " Intune computers." -Color Yellow, Cyan, Green, Cyan, Green
            }
        }

        if ($null -ne $SafetyIntuneLimit -and $DevicesIntune.Count -lt $SafetyIntuneLimit) {
            Write-Color "[e] ", "Only ", $($DevicesIntune.Count), " computers found in Intune, this is less than the safety limit of ", $SafetyIntuneLimit, ". Terminating!" -Color Yellow, Cyan, Red, Cyan
            return $false
        }

        Write-Color "[i] ", "Synchronized Computers found in Intune`: ", $($DevicesIntune.Count) -Color Yellow, Cyan, Green
    }

    $AzureInformationCache
}
