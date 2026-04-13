function New-HTMLProcessedCloudDevices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Export,

        [Parameter(Mandatory)]
        [Array] $Devices,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $RetireOnlyIf,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $DisableOnlyIf,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $DeleteOnlyIf,

        [Parameter(Mandatory)]
        [string] $FilePath,

        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile
    )

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey -BackgroundColor BlizzardBlue
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection { New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue } -JustifyContent flex-start -Invisible
                New-HTMLSection { New-HTMLText -Text "Cleanup Monster - $($Export.Version)" -Color Blue } -JustifyContent flex-end -Invisible
            }
        }

        New-HTMLTab -Name 'Current Run' {
            New-HTMLSection {
                New-HTMLPanel { New-HTMLToast -TextHeader 'Matched' -Text "Matched records actioned: $(@($Export.CurrentRun | Where-Object { $_.RecordState -eq 'Matched' }).Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Entra only' -Text "Entra-only records actioned: $(@($Export.CurrentRun | Where-Object { $_.RecordState -eq 'EntraOnly' }).Count)" -BarColorLeft CornflowerBlue -IconSolid info-circle -IconColor CornflowerBlue } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Intune only' -Text "Intune-only records actioned: $(@($Export.CurrentRun | Where-Object { $_.RecordState -eq 'IntuneOnly' }).Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel } -Invisible
            } -Invisible
            New-HTMLTable -DataTable $Export.CurrentRun -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Retire' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor Yellow
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'WhatIf' -BackgroundColor LightBlue
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'ReportOnly' -BackgroundColor Lavender
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'EntraOnly' -BackgroundColor AliceBlue
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'IntuneOnly' -BackgroundColor Cornsilk
            } -WarningAction SilentlyContinue
        }

        New-HTMLTab -Name 'History' {
            New-HTMLTable -DataTable $Export.History -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Retire' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor Yellow
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'EntraOnly' -BackgroundColor AliceBlue
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'IntuneOnly' -BackgroundColor Cornsilk
            } -WarningAction SilentlyContinue
        }

        New-HTMLTab -Name 'Pending Actions' {
            New-HTMLTable -DataTable $Export.PendingActions.Values -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'EntraOnly' -BackgroundColor AliceBlue
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'IntuneOnly' -BackgroundColor Cornsilk
            } -WarningAction SilentlyContinue
        }

        New-HTMLTab -Name 'Devices' {
            New-HTMLSection {
                New-HTMLPanel { New-HTMLToast -TextHeader 'Total' -Text "Devices discovered: $($Devices.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Current Run' -Text "Actions this run: $($Export.CurrentRun.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Pending' -Text "Pending actions: $($Export.PendingActions.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Matched' -Text "Matched records: $(@($Devices | Where-Object { $_.RecordState -eq 'Matched' }).Count)" -BarColorLeft SeaGreen -IconSolid info-circle -IconColor SeaGreen } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Entra only' -Text "Entra-only records: $(@($Devices | Where-Object { $_.RecordState -eq 'EntraOnly' }).Count)" -BarColorLeft CornflowerBlue -IconSolid info-circle -IconColor CornflowerBlue } -Invisible
                New-HTMLPanel { New-HTMLToast -TextHeader 'Intune only' -Text "Intune-only records: $(@($Devices | Where-Object { $_.RecordState -eq 'IntuneOnly' }).Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel } -Invisible
            } -Invisible

            New-HTMLSection -HeaderText 'Rules' {
                New-HTMLPanel {
                    New-HTMLText -Text 'Retire rules' -FontWeight bold
                    New-HTMLTable -DataTable @([PSCustomObject] $RetireOnlyIf)
                }
                New-HTMLPanel {
                    New-HTMLText -Text 'Disable rules' -FontWeight bold
                    New-HTMLTable -DataTable @([PSCustomObject] $DisableOnlyIf)
                }
                New-HTMLPanel {
                    New-HTMLText -Text 'Delete rules' -FontWeight bold
                    New-HTMLTable -DataTable @([PSCustomObject] $DeleteOnlyIf)
                }
            }

            New-HTMLTable -DataTable $Devices -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'Matched' -BackgroundColor Honeydew
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'EntraOnly' -BackgroundColor AliceBlue
                New-HTMLTableCondition -Name 'RecordState' -ComparisonType string -Value 'IntuneOnly' -BackgroundColor Cornsilk
            } -WarningAction SilentlyContinue
        }

        try {
            if ($LogFile -and (Test-Path -LiteralPath $LogFile -ErrorAction Stop)) {
                $logContent = Get-Content -Raw -LiteralPath $LogFile -ErrorAction Stop
                New-HTMLTab -Name 'Log' {
                    New-HTMLCodeBlock -Code $logContent -Style generic
                }
            }
        } catch {
            Write-Color -Text '[e] ', "Couldn't read the log file. Skipping adding log to HTML. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    } -FilePath $FilePath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent
}
