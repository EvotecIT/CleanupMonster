Describe 'Disable-WinADComputer' {
    BeforeAll {
        . "$PSScriptRoot/../Private/Get-ADComputerCurrentDistinguishedName.ps1"
        . "$PSScriptRoot/../Private/Disable-WinADComputer.ps1"
    }

    It 'does not remove ProtectedFromAccidentalDeletion during disable-only operations' {
        $computer = [pscustomobject]@{
            SamAccountName                   = 'TEST$'
            DistinguishedName                = 'CN=Test,CN=Computers,DC=example,DC=com'
            DistinguishedNameAfterMove       = $null
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

        function Disable-ADAccount {
            [CmdletBinding(SupportsShouldProcess)]
            param($Identity, $Server)

            $global:DisableCalled = $true
            $global:DisabledIdentity = $Identity
        }

        Disable-WinADComputer -Success $true -Computer $computer -Server 'server' -WhatIfDisable:$false -DontWriteToEventLog | Out-Null

        $global:FlagRemoved | Should -Be $false
        $global:DisableCalled | Should -Be $true
        $global:DisabledIdentity | Should -Be $computer.DistinguishedName
    }

    It 'uses the post-move distinguished name for disabling and event data' {
        $movedDistinguishedName = 'CN=Test,OU=Disabled,DC=example,DC=com'
        $computer = [pscustomobject]@{
            SamAccountName             = 'TEST$'
            DistinguishedName          = 'CN=Test,CN=Computers,DC=example,DC=com'
            DistinguishedNameAfterMove = $movedDistinguishedName
            Enabled                    = $true
            OperatingSystem            = 'Windows'
            LastLogonDate              = Get-Date
            LastLogonDays              = 0
            PasswordLastSet            = Get-Date
            PasswordLastChangedDays    = 0
        }
        $script:DisabledIdentity = $null
        $script:DisableEventFields = $null
        function Write-Color { param([Parameter(ValueFromRemainingArguments)][object[]]$Args) }
        function Disable-ADAccount {
            [CmdletBinding(SupportsShouldProcess)]
            param($Identity, $Server)

            $script:DisabledIdentity = $Identity
        }
        function Write-Event {
            [CmdletBinding()]
            param(
                $ID,
                $LogName,
                $EntryType,
                $Category,
                $Source,
                $Message,
                $AdditionalFields
            )

            $script:DisableEventFields = $AdditionalFields
        }

        Disable-WinADComputer -Success $true -Computer $computer -Server 'server' | Out-Null

        $script:DisabledIdentity | Should -Be $movedDistinguishedName
        $script:DisableEventFields[2] | Should -Be $movedDistinguishedName
    }
}
