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
}
