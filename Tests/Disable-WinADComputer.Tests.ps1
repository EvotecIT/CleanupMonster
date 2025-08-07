Describe 'Disable-WinADComputer' {
    BeforeAll {
        . "$PSScriptRoot/../Private/Disable-WinADComputer.ps1"
    }

    It 'removes ProtectedFromAccidentalDeletion when requested' {
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
        function Set-ADObject { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) $global:FlagRemoved = $true }
        function Disable-ADAccount { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) }
        function Write-Color { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) }
        function Write-Event { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) }

        Disable-WinADComputer -Success $true -Computer $computer -Server 'server' -WhatIfDisable:$false -DontWriteToEventLog -RemoveProtectedFromAccidentalDeletionFlag
        $global:FlagRemoved | Should -Be $true
    }
}

