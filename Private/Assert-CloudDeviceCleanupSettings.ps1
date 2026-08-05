function Assert-CloudDeviceCleanupSettings {
    [CmdletBinding()]
    param()

    $moduleAvailable = Get-Module -Name GraphEssentials -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $moduleAvailable) {
        Write-Color -Text '[e] ', "'GraphEssentials' module is required for cloud-device cleanup but is not available. Terminating." -Color Yellow, Red
        return $false
    }

    $minimumVersion = [version] '0.0.57'
    if ($moduleAvailable.Version -lt $minimumVersion) {
        Write-Color -Text '[e] ', "'GraphEssentials' module is outdated for cloud-device cleanup. Please update to minimum version '$minimumVersion'. Terminating." -Color Yellow, Red
        return $false
    }

    $requiredCommands = @(
        'Get-MyDevice'
        'Get-MyDeviceIntune'
        'Invoke-MyDeviceRetire'
        'Disable-MyDevice'
        'Remove-MyAutopilotDevice'
        'Remove-MyDevice'
        'Remove-MyDeviceIntuneRecord'
    )

    $resolvedCommands = @{}
    $missingCommands = foreach ($commandName in $requiredCommands) {
        $command = Get-Command -Name $commandName -ErrorAction SilentlyContinue
        if (-not $command) {
            $commandName
        } else {
            $resolvedCommands[$commandName] = $command
        }
    }

    if ($missingCommands.Count -gt 0) {
        Write-Color -Text '[e] ', 'GraphEssentials cloud-device commands are missing: ', ($missingCommands -join ', '), '. Terminating.' -Color Yellow, Red, Yellow, Red
        return $false
    }

    $inventoryCommand = $resolvedCommands['Get-MyDeviceIntune']
    if ($inventoryCommand.ModuleName -ne 'GraphEssentials' -or -not $inventoryCommand.Module -or $inventoryCommand.Module.Version -lt $minimumVersion) {
        Write-Color -Text '[e] ', "'Get-MyDeviceIntune' is not provided by the required GraphEssentials version '$minimumVersion' in the current session. Import the updated module and try again. Terminating." -Color Yellow, Red
        return $false
    }

    $true
}
