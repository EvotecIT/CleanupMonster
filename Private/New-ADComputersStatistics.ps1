function New-ADComputersStatistics {
    [CmdletBinding()]
    param(
        [Array] $ComputersToProcess
    )
    $Statistics = [ordered] @{
        ToDisable                    = 0
        ToDelete                     = 0
        ToDisableComputerWorkstation = 0
        ToDisableComputerServer      = 0
        ToDeleteComputerWorkstation  = 0
        ToDeleteComputerServer       = 0
        ToDisableComputerUnknown     = 0
        ToDeleteComputerUnknown      = 0
        Delete                       = [ordered] @{
            LastLogonDays           = [ordered ]@{}
            PasswordLastChangedDays = [ordered] @{}
            Systems                 = [ordered] @{}
        }
        Disable                      = [ordered] @{
            LastLogonDays           = [ordered] @{}
            PasswordLastChangedDays = [ordered] @{}
            Systems                 = [ordered] @{}
        }
        'Not required'               = [ordered] @{
            LastLogonDays           = [ordered] @{}
            PasswordLastChangedDays = [ordered] @{}
            Systems                 = [ordered] @{}
        }
    }
    foreach ($Computer in $ComputersToProcess) {
        if ($Computer.Action -eq 'Disable') {
            $Statistics.ToDisable++

            if ($Computer.OperatingSystem -like "Windows Server*") {
                $Statistics.ToDisableComputerServer++
            } elseif ($Computer.OperatingSystem -notlike "Windows Server*" -and $Computer.OperatingSystem -like "Windows*") {
                $Statistics.ToDisableComputerWorkstation++
            } else {
                $Statistics.ToDisableComputerUnknown++
            }
        } elseif ($Computer.Action -eq 'Delete') {
            $Statistics.ToDelete++

            if ($Computer.OperatingSystem -like "Windows Server*") {
                $Statistics.ToDeleteComputerServer++
            } elseif ($Computer.OperatingSystem -notlike "Windows Server*" -and $Computer.OperatingSystem -like "Windows*") {
                $Statistics.ToDeleteComputerWorkstation++
            } else {
                $Statistics.ToDeleteComputerUnknown++
            }
        } else {
            Write-Color -Text '[-] ', "Unknown action: $($Computer.Action)" -Color Yellow, Red
        }
        if ($Computer.OperatingSystem) {
            $Statistics[$Computer.Action]['Systems'][$Computer.OperatingSystem]++
        } else {
            $Statistics[$Computer.Action]['Systems']['Unknown']++
        }
        if ($Computer.LastLogonDays -gt 720) {
            $Statistics[$Computer.Action]['LastLogonDays']['Over 720 days']++
        } elseif ($Computer.LastLogonDays -gt 360) {
            $Statistics[$Computer.Action]['LastLogonDays']['Over 360 days']++
        } elseif ($Computer.LastLogonDays -gt 180) {
            $Statistics[$Computer.Action]['LastLogonDays']['Over 180 days']++
        } elseif ($Computer.LastLogonDays -gt 90) {
            $Statistics[$Computer.Action]['LastLogonDays']['Over 90 days']++
        } elseif ($Computer.LastLogonDays -gt 30) {
            $Statistics[$Computer.Action]['LastLogonDays']['Over 30 days']++
        } else {
            $Statistics[$Computer.Action]['LastLogonDays']['Under 30 days']++
        }
        if ($Computer.PasswordLastChangedDays -gt 720) {
            $Statistics[$Computer.Action]['PasswordLastChangedDays']['Over 720 days']++
        } elseif ($Computer.PasswordLastChangedDays -gt 360) {
            $Statistics[$Computer.Action]['PasswordLastChangedDays']['Over 360 days']++
        } elseif ($Computer.PasswordLastChangedDays -gt 180) {
            $Statistics[$Computer.Action]['PasswordLastChangedDays']['Over 180 days']++
        } elseif ($Computer.PasswordLastChangedDays -gt 90) {
            $Statistics[$Computer.Action]['PasswordLastChangedDays']['Over 90 days']++
        } elseif ($Computer.PasswordLastChangedDays -gt 30) {
            $Statistics[$Computer.Action]['PasswordLastChangedDays']['Over 30 days']++
        } else {
            $Statistics[$Computer.Action]['PasswordLastChangedDays']['Under 30 days']++
        }
    }
    $Statistics
}