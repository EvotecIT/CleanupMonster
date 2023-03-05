function New-HTMLProcessedComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export,
        [string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile
    )

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "Active Directory Cleanup - $($Export['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        New-HTMLTab -Name 'Devices Current Run' {
            New-HTMLTable -DataTable $Export.CurrentRun -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'WhatIf' -ComparisonType string -Value 'True' -BackgroundColor LightYellow -FailBackgroundColor LightBlue
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
            }
        }
        New-HTMLTab -Name 'Devices History' {
            New-HTMLTable -DataTable $Export.History -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'WhatIf' -ComparisonType string -Value 'True' -BackgroundColor LightYellow -FailBackgroundColor LightBlue
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
            }
        }
        New-HTMLTab -Name 'Devices Pending' {
            New-HTMLTable -DataTable $Export.PendingDeletion -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'WhatIf' -ComparisonType string -Value 'True' -BackgroundColor LightYellow -FailBackgroundColor LightBlue
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
            }
        }
        if ($LogFile -and (Test-Path -LiteralPath $LogFile)) {
            $LogContent = Get-Content -Raw -LiteralPath $LogFile
            New-HTMLTab -Name 'Log' {
                New-HTMLCodeBlock -Code $LogContent -Style generic
            }
        }
    } -FilePath $FilePath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent
}