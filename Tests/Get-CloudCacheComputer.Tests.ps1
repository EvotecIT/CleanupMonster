BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Get-ComputerLookupCandidates.ps1')
    . (Get-CleanupMonsterPath 'Private/Get-CloudCacheComputer.ps1')
}

Describe 'Cloud device lookup helpers' {
    It 'builds lookup candidates from AD and DNS names without duplicates' {
        $Candidates = Get-ComputerLookupCandidates -Name 'My-Computer-Name-Is' -DNSHostName 'My-Computer-Name-Is-Gokou340.contoso.com' -SamAccountName 'My-Computer-Name-Is$'

        $Candidates | Should -Be @(
            'My-Computer-Name-Is'
            'My-Computer-Name-Is-Gokou340.contoso.com'
            'My-Computer-Name-Is-Gokou340'
            'My-Computer-Name-Is$'
        )
    }

    It 'finds a cloud device by full DNSHostName when the AD name is truncated' {
        $Candidates = Get-ComputerLookupCandidates -Name 'My-Computer-Name-Is' -DNSHostName 'My-Computer-Name-Is-Gokou340' -SamAccountName 'My-Computer-Name-Is$'
        $Cache = [ordered] @{
            'My-Computer-Name-Is-Gokou340' = [PSCustomObject] @{
                LastSeen = 'matched-by-dns'
            }
        }

        $Device = Get-CloudCacheComputer -Cache $Cache -Candidates $Candidates

        $Device.LastSeen | Should -Be 'matched-by-dns'
    }

    It 'finds a cloud device by short host name when the AD DNS name is FQDN' {
        $Candidates = Get-ComputerLookupCandidates -Name 'My-Computer-Name-Is' -DNSHostName 'My-Computer-Name-Is-Gokou340.contoso.com' -SamAccountName 'My-Computer-Name-Is$'
        $Cache = [ordered] @{
            'My-Computer-Name-Is-Gokou340' = [PSCustomObject] @{
                LastSeen = 'matched-by-host'
            }
        }

        $Device = Get-CloudCacheComputer -Cache $Cache -Candidates $Candidates

        $Device.LastSeen | Should -Be 'matched-by-host'
    }

    It 'finds a cloud device by samAccountName without the trailing dollar sign' {
        $Candidates = Get-ComputerLookupCandidates -Name 'ShortName' -DNSHostName $null -SamAccountName 'LongComputerName$'
        $Cache = [ordered] @{
            'LongComputerName' = [PSCustomObject] @{
                LastSeen = 'matched-by-samaccount'
            }
        }

        $Device = Get-CloudCacheComputer -Cache $Cache -Candidates $Candidates

        $Device.LastSeen | Should -Be 'matched-by-samaccount'
    }

    It 'does not duplicate equivalent short-name candidates' {
        $Candidates = Get-ComputerLookupCandidates -Name 'Server01' -DNSHostName 'Server01.contoso.com' -SamAccountName 'Server01$'

        $Candidates | Should -Be @(
            'Server01'
            'Server01.contoso.com'
            'Server01$'
        )
    }
}
