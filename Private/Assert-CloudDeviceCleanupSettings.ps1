function Assert-CloudDeviceCleanupSettings {
    [CmdletBinding()]
    param()

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
