$ModuleManifest = Get-ChildItem -Path $PSScriptRoot -Filter '*.psd1' -File -ErrorAction Stop
if ($ModuleManifest.Count -ne 1) {
    throw "Expected exactly one module manifest in $PSScriptRoot."
}

$ModuleInfo = Import-PowerShellDataFile -Path $ModuleManifest.FullName
$PesterVersion = '5.7.1'

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -EQ $PesterVersion)) {
    Install-Module -Name Pester -RequiredVersion $PesterVersion -Repository PSGallery -Force -SkipPublisherCheck -AllowClobber -Scope CurrentUser
}

Import-Module Pester -RequiredVersion $PesterVersion -Force -ErrorAction Stop

Write-Host "ModuleName: $($ModuleManifest.BaseName) Version: $($ModuleInfo.ModuleVersion)"
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)"

$Configuration = [PesterConfiguration]::Default
$Configuration.Run.Path = "$PSScriptRoot\Tests"
$Configuration.Run.Exit = $false
$Configuration.Run.PassThru = $true
$Configuration.Should.ErrorAction = 'Continue'
$Configuration.CodeCoverage.Enabled = $false
$Configuration.Output.Verbosity = 'Detailed'

$Result = Invoke-Pester -Configuration $Configuration
if ($Result.FailedCount -gt 0) {
    throw "$($Result.FailedCount) tests failed."
}
