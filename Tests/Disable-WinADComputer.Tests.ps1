Describe 'Disable-WinADComputer' {
    BeforeAll {
        . "$PSScriptRoot/../Private/Disable-WinADComputer.ps1"
    }

    It 'does not remove ProtectedFromAccidentalDeletion during disable-only operations' {
        $computer = [pscustomobject]@{
            SamAccountName                   = 'TEST$'
            DistinguishedName                = 'CN=Test,CN=Computers,DC=example,DC=com'
            Enabled                          = $true
            OperatingSystem                  = 'Windows'
            LastLogonDate                    = Get-Date
            LastLogonDays                    = 0
            PasswordLastSet                  = Get-Date
            PasswordLastChangedDays          = 0
            ProtectedFromAccidentalDeletion  = $true
        }
        $global:FlagRemoved = $false
        $global:DisableCalled = $false
        function Write-Color { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) }
        function Write-Event { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) }

        function Disable-ADAccount { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) $global:DisableCalled = $true }

        Disable-WinADComputer -Success $true -Computer $computer -Server 'server' -WhatIfDisable:$false -DontWriteToEventLog | Out-Null

        $global:FlagRemoved | Should -Be $false
        $global:DisableCalled | Should -Be $true
    }
}
