BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Remove-ADSIDHistory.ps1')

    function Write-Color {}
}

Describe 'Remove-ADSIDHistory' {
    BeforeEach {
        Mock Write-Color {}
    }

    It 'tracks targeted SID counts separately from the full SID history' {
        $targetedSid = 'S-1-5-21-111-222-333-1001'
        $otherSid = 'S-1-5-21-444-555-666-1002'

        $export = @{
            History = [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        $object = [PSCustomObject]@{
            Name              = 'User1'
            Domain            = 'contoso.com'
            Enabled           = $false
            SIDHistory        = @($targetedSid, $otherSid)
            DistinguishedName = 'CN=User1,DC=contoso,DC=com'
        }

        $objectsToProcess = @(
            [PSCustomObject]@{
                Object             = $object
                QueryServer        = 'dc1.contoso.com'
                SIDHistoryToRemove = @($targetedSid)
            }
        )

        Mock Set-ADObject {}
        Mock Get-ADObject {
            [PSCustomObject]@{
                SIDHistory = @($otherSid)
            }
        }

        Remove-ADSIDHistory -ObjectsToProcess $objectsToProcess -Export $export -RemoveLimitSID 5

        $export.CurrentRun | Should -HaveCount 1
        $export.History | Should -HaveCount 1

        $currentRun = $export.CurrentRun[0]
        $currentRun.SIDBeforeCount | Should -Be 2
        $currentRun.SIDBeforeTargetedCount | Should -Be 1
        $currentRun.SIDAfterCount | Should -Be 1
        $currentRun.SIDAfterTargetedCount | Should -Be 0
        $currentRun.ActionStatus | Should -Be 'Success'
        $currentRun.SIDAfterTargeted | Should -BeNullOrEmpty
        $export.History[0].SID | Should -Be $targetedSid

        Assert-MockCalled Set-ADObject -Times 1 -Exactly
    }

    It 'falls back to the full SID history when no targeted list is provided' {
        $sid = 'S-1-5-21-111-222-333-1001'

        $export = @{
            History = [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        $object = [PSCustomObject]@{
            Name              = 'User2'
            Domain            = 'contoso.com'
            Enabled           = $true
            SIDHistory        = @($sid)
            DistinguishedName = 'CN=User2,DC=contoso,DC=com'
        }

        $objectsToProcess = @(
            [PSCustomObject]@{
                Object      = $object
                QueryServer = 'dc1.contoso.com'
            }
        )

        Mock Set-ADObject {}
        Mock Get-ADObject {
            [PSCustomObject]@{
                SIDHistory = @()
            }
        }

        Remove-ADSIDHistory -ObjectsToProcess $objectsToProcess -Export $export -RemoveLimitSID 5

        $currentRun = $export.CurrentRun[0]
        $currentRun.SIDBeforeTargetedCount | Should -Be 1
        $currentRun.SIDAfterTargetedCount | Should -Be 0
    }
}
