function Assert-CloudDeviceCleanupSettings {
    [CmdletBinding()]
    param()

    $moduleAvailable = Get-Module -Name GraphEssentials -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $moduleAvailable) {
        Write-Color -Text '[e] ', "'GraphEssentials' module is required for cloud-device cleanup but is not available. Terminating." -Color Yellow, Red
        return $false
    }

    $minimumVersion = [version] '0.0.56'
    if ($moduleAvailable.Version -lt $minimumVersion) {
        Write-Color -Text '[e] ', "'GraphEssentials' module is outdated for cloud-device cleanup. Please update to minimum version '$minimumVersion'. Terminating." -Color Yellow, Red
        return $false
    }

    $requiredCommands = @(
        'Get-MyDevice'
        'Get-MyDeviceIntune'
        'Invoke-MyDeviceRetire'
        'Disable-MyDevice'
        'Remove-MyDevice'
        'Remove-MyDeviceIntuneRecord'
    )

    $missingCommands = foreach ($commandName in $requiredCommands) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $commandName
        }
    }

    if ($missingCommands.Count -gt 0) {
        Write-Color -Text '[e] ', 'GraphEssentials cloud-device commands are missing: ', ($missingCommands -join ', '), '. Terminating.' -Color Yellow, Red, Yellow, Red
        return $false
    }

    $true
}
