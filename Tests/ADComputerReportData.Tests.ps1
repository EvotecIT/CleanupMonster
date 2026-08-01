BeforeAll {
    . "$PSScriptRoot\TestHelpers.ps1"
    . (Get-CleanupMonsterPath 'Private/Export-ADComputerReportData.ps1')
    . (Get-CleanupMonsterPath 'Private/Merge-ADComputerHTMLReportData.ps1')

    # PSSharedGoods is an external module boundary and is not installed in the
    # source-test CI job. This fake preserves the formatting contract exercised
    # by the report serializer; a generated report is validated separately.
    function ConvertTo-PrettyObject {
        param(
            [Array] $Object,
            [string[]] $PropertyName,
            [switch] $Force,
            [switch] $BoolAsString,
            [switch] $ArrayJoin,
            [string] $ArrayJoinString,
            [AllowEmptyString()]
            [string] $DateTimeFormat,
            [System.Collections.IDictionary] $NewLineFormat,
            [System.Collections.IDictionary] $NewLineFormatProperty
        )

        foreach ($Item in $Object) {
            $Converted = [ordered] @{}
            foreach ($Property in $PropertyName) {
                $Value = $Item.$Property
                if ($null -eq $Value) {
                    $Converted[$Property] = ''
                } elseif ($Value -is [DateTime]) {
                    $Converted[$Property] = $Value.ToString($DateTimeFormat)
                } elseif ($Value -is [bool] -and $BoolAsString) {
                    $Converted[$Property] = [string] $Value
                } elseif ($Value -is [System.Collections.IList] -and $ArrayJoin) {
                    $Converted[$Property] = $Value -join $ArrayJoinString
                } elseif ($Value -is [string]) {
                    $Converted[$Property] = $Value.Replace([System.Environment]::NewLine, $NewLineFormat.NewLineCarriage).Replace("`n", $NewLineFormat.NewLine).Replace("`r", $NewLineFormat.Carriage)
                } else {
                    $Converted[$Property] = $Value
                }
            }
            [PSCustomObject] $Converted
        }
    }
}

Describe 'AD computer report serialization' {
    It 'writes every row across bounded chunks without internal-only properties' {
        $Rows = 1..5 | ForEach-Object {
            [PSCustomObject] [ordered] @{
                SamAccountName             = "PC$_`$"
                Description                = if ($_ -eq 3) { '<retired>' } else { "Computer $_" }
                Enabled                    = $true
                ServicePrincipalName       = @("HOST/PC$_", "WSMAN/PC$_")
                WhenCreated                = [DateTime] '2024-01-02T03:04:05'
                TimeOnPendingList           = 10
                TimeToLeavePendingList      = 20
                DistinguishedNameAfterMove = 'OU=Moved,DC=contoso,DC=com'
            }
        }
        $DataPath = Join-Path $TestDrive 'computers.json'

        $Result = Export-ADComputerReportData -Computers $Rows -FilePath $DataPath -ChunkSize 2
        $Parsed = Get-Content -LiteralPath $DataPath -Raw | ConvertFrom-Json

        $Result.Count | Should -Be 5
        $Parsed | Should -HaveCount 5
        $Parsed[0].SamAccountName | Should -Be 'PC1$'
        $Parsed[4].SamAccountName | Should -Be 'PC5$'
        $Parsed[0].Enabled | Should -Be 'True'
        $Parsed[0].ServicePrincipalName | Should -Be 'HOST/PC1, WSMAN/PC1'
        [string] $Parsed[0].WhenCreated | Should -Be $Rows[0].WhenCreated.ToString('')
        $Parsed[2].Description | Should -BeIn @('<retired>', '&lt;retired&gt;')
        $Parsed[0].PSObject.Properties.Name | Should -Not -Contain 'TimeOnPendingList'
        (Get-Content -LiteralPath $DataPath -Raw) | Should -Not -Match '"Description":"<retired>"'
    }

    It 'writes a valid empty JSON array when no domain returns computers' {
        $DataPath = Join-Path $TestDrive 'empty-computers.json'

        $Result = Export-ADComputerReportData -Computers @() -FilePath $DataPath

        $Result.Count | Should -Be 0
        $Result.Sample | Should -BeNullOrEmpty
        Get-Content -LiteralPath $DataPath -Raw | Should -Be '[]'
    }

    It 'preserves the JavaScript-store newline conversion used by PSWriteHTML' {
        $Rows = @(
            [PSCustomObject] [ordered] @{
                SamAccountName = 'PC1$'
                Description    = "First line`r`nSecond line"
            }
        )
        $DataPath = Join-Path $TestDrive 'multiline-computers.json'

        Export-ADComputerReportData -Computers $Rows -FilePath $DataPath | Out-Null
        $Parsed = Get-Content -LiteralPath $DataPath -Raw | ConvertFrom-Json

        $Parsed[0].Description | Should -BeIn @('First line<br>Second line', 'First line&lt;br&gt;Second line')
    }

    It 'streams the complete JSON array into one self-contained HTML file' {
        $StagingPath = Join-Path $TestDrive 'staging.html'
        $DataPath = Join-Path $TestDrive 'computers.json'
        $OutputPath = Join-Path $TestDrive 'report.html'
        Set-Content -LiteralPath $StagingPath -Value '<html><script>var CleanupMonsterADComputers = [{"SamAccountName":"sample$"}];</script><body>report</body></html>' -Encoding UTF8
        Set-Content -LiteralPath $DataPath -Value '[{"SamAccountName":"PC1$"},{"SamAccountName":"PC2$"}]' -Encoding UTF8

        Merge-ADComputerHTMLReportData -StagingHtmlPath $StagingPath -DataFilePath $DataPath -OutputPath $OutputPath -DataStoreID CleanupMonsterADComputers
        $Html = Get-Content -LiteralPath $OutputPath -Raw

        $Html | Should -Match 'var CleanupMonsterADComputers = \[{"SamAccountName":"PC1\$"},{"SamAccountName":"PC2\$"}\]\s*;'
        $Html | Should -Not -Match 'sample\$'
        $Html | Should -Match '<body>report</body>'
    }

    It 'does not terminate the sample assignment at a delimiter inside JSON text' {
        $StagingPath = Join-Path $TestDrive 'delimiter-staging.html'
        $DataPath = Join-Path $TestDrive 'delimiter-computers.json'
        $OutputPath = Join-Path $TestDrive 'delimiter-report.html'
        $SampleJson = '[{"SamAccountName":"sample$","Description":"contains ]; delimiter and var CleanupMonsterADComputers = [ plus \\server and \"quote\""}]'
        $ReplacementJson = '[{"SamAccountName":"PC1$","Description":"also contains ]; delimiter and var CleanupMonsterADComputers = [ plus \\server and \"quote\""}]'
        Set-Content -LiteralPath $StagingPath -Value "<html><script>var CleanupMonsterADComputers = $SampleJson;</script><body>report</body></html>" -Encoding UTF8
        Set-Content -LiteralPath $DataPath -Value $ReplacementJson -Encoding UTF8

        Merge-ADComputerHTMLReportData -StagingHtmlPath $StagingPath -DataFilePath $DataPath -OutputPath $OutputPath -DataStoreID CleanupMonsterADComputers
        $Html = Get-Content -LiteralPath $OutputPath -Raw

        $Html | Should -Match (([regex]::Escape("var CleanupMonsterADComputers = $ReplacementJson")) + '\s*;')
        $Html | Should -Not -Match 'sample\$'
        $Html | Should -Match '<body>report</body>'
    }
}
