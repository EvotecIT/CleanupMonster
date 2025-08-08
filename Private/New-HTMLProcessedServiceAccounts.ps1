function New-HTMLProcessedServiceAccounts {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [Array] $AccountsToProcess,
        [string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile,
        [switch] $Disable,
        [switch] $Delete,
        [switch] $ReportOnly
    )

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey -BackgroundColor BlizzardBlue
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection {
                    New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                } -JustifyContent flex-start -Invisible
                New-HTMLSection {
                    New-HTMLText -Text "Cleanup Monster - $($Export['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }

        if (-not $ReportOnly) {
            New-HTMLTab -Name 'Service Accounts Current Run' {
                New-HTMLSection {
                    [Array] $ListAll = $Export.CurrentRun
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Total in this run' -Text "Actions (disable & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible

                    [Array] $ListDisabled = $Export.CurrentRun | Where-Object { $_.Action -eq 'Disable' }
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disable' -Text "Accounts disabled: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible

                    [Array] $ListDeleted = $Export.CurrentRun | Where-Object { $_.Action -eq 'Delete' }
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Delete' -Text "Accounts deleted: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible
                } -Invisible

                New-HTMLTable -DataTable $Export.CurrentRun -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'WhatIf' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue
            }

            New-HTMLTab -Name 'Service Accounts History' {
                New-HTMLSection {
                    [Array] $ListAll = $Export.History
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Total History' -Text "Actions (disable & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible

                    [Array] $ListDisabled = $Export.History | Where-Object { $_.Action -eq 'Disable' }
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disabled History' -Text "Accounts disabled so far: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible

                    [Array] $ListDeleted = $Export.History | Where-Object { $_.Action -eq 'Delete' }
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Deleted History' -Text "Accounts deleted so far: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible
                } -Invisible
                New-HTMLTable -DataTable $Export.History -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'WhatIf' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue -AllProperties
            }
        }

        New-HTMLPanel {
            if ($Disable) {
                New-HTMLText -Text "Service accounts will be disabled only if: " -FontWeight bold
                New-HTMLList {
                    foreach ($Key in $DisableOnlyIf.Keys) {
                        New-HTMLListItem -Text @(
                            if ($null -eq $DisableOnlyIf[$Key]) {
                                $($Key), " is ", 'Not Set'
                                $ColorInUse = 'Cinnabar'
                            } else {
                                $($Key), " is ", $($DisableOnlyIf[$Key])
                                $ColorInUse = 'Apple'
                            }
                        ) -FontWeight bold, normal, bold -Color $ColorInUse, None, CornflowerBlue
                    }
                }
            } else {
                New-HTMLText -Text "Service accounts will not be disabled, as the disable functionality was not enabled." -FontWeight bold
            }
        }

        New-HTMLPanel {
            if ($Delete) {
                New-HTMLText -Text "Service accounts will be deleted only if: " -FontWeight bold
                New-HTMLList {
                    foreach ($Key in $DeleteOnlyIf.Keys) {
                        New-HTMLListItem -Text @(
                            if ($null -eq $DeleteOnlyIf[$Key]) {
                                $($Key), " is ", 'Not Set'
                                $ColorInUse = 'Cinnabar'
                            } else {
                                $($Key), " is ", $($DeleteOnlyIf[$Key])
                                $ColorInUse = 'Apple'
                            }
                        ) -FontWeight bold, normal, bold -Color $ColorInUse, None, CornflowerBlue
                    }
                }
            } else {
                New-HTMLText -Text "Service accounts will not be deleted, as the delete functionality was not enabled." -FontWeight bold
            }
        }

        if ($AccountsToProcess) {
            New-HTMLTable -DataTable $AccountsToProcess -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'WhatIf' -BackgroundColor LightBlue
            } -WarningAction SilentlyContinue -ExcludeProperty 'TimeOnPendingList', 'TimeToLeavePendingList'
        }

        try {
            if ($LogFile -and (Test-Path -LiteralPath $LogFile -ErrorAction Stop)) {
                $LogContent = Get-Content -Raw -LiteralPath $LogFile -ErrorAction Stop
                New-HTMLTab -Name 'Log' {
                    New-HTMLCodeBlock -Code $LogContent -Style generic
                }
            }
        } catch {
            Write-Color -Text "[e] ", "Couldn't read the log file. Skipping adding log to HTML. Error: $($_.Exception.Message)" -Color Yellow, Red
        }
    } -FilePath $FilePath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent
}

