function New-HTMLProcessedComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [Array] $ComputersToProcess,
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
                    New-HTMLText -Text "Active Directory Cleanup - $($Export['Version'])" -Color Blue
                } -JustifyContent flex-end -Invisible
            }
        }
        if (-not $ReportOnly) {
            New-HTMLTab -Name 'Devices Current Run' {
                New-HTMLSection {
                    [Array] $ListAll = $($Export.CurrentRun)
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Total in this run' -Text "Actions (disable & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible
                    [Array] $ListDisabled = $($($Export.CurrentRun | Where-Object { $_.Action -eq 'Disable' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disable' -Text "Computers disabled: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible
                    [Array] $ListDeleted = $($($Export.CurrentRun | Where-Object { $_.Action -eq 'Delete' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Delete' -Text "Computers deleted: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible
                } -Invisible
                New-HTMLTable -DataTable $Export.CurrentRun -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue
            }
            New-HTMLTab -Name 'Devices History' {
                New-HTMLSection {
                    [Array] $ListAll = $($Export.History)
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Total History' -Text "Actions (disable & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible
                    [Array] $ListDisabled = $($($Export.History | Where-Object { $_.Action -eq 'Disable' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disabled History' -Text "Computers disabled so far: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible
                    [Array] $ListDeleted = $($($Export.History | Where-Object { $_.Action -eq 'Delete' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Deleted History' -Text "Computers deleted so far: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible
                } -Invisible
                New-HTMLTable -DataTable $Export.History -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue
            }
            New-HTMLTab -Name 'Devices Pending' {
                New-HTMLTable -DataTable $Export.PendingDeletion.Values -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue
            }
        }
        New-HTMLTab -Name 'Devices' {
            #New-HTMLText -Text @(
            #    "This is the list of computers that will be processed if there are no limits to processing. "
            #)
            New-HTMLSection {
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'Total' -Text "Actions (disable & delete): $($ComputersToProcess.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To disable' -Text "Computers to be disabled: $($($ComputersToProcess | Where-Object { $_.Action -eq 'Disable' }).Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To delete' -Text "Computers to be deleted: $($($ComputersToProcess | Where-Object { $_.Action -eq 'Delete' }).Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                } -Invisible
            } -Invisible
            New-HTMLText -LineBreak
            New-HTMLHeading -Heading h3 -HeadingText "Full list of computers that will be processed if there are no limits to processing. "
            New-HTMLText -LineBreak
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    if ($Disable) {
                        New-HTMLText -Text "Computers will be disabled only if: " -FontWeight bold
                        New-HTMLList {
                            foreach ($Key in $DisableOnlyIf.Keys) {
                                New-HTMLListItem -Text @(
                                    if ($null -eq $DisableOnlyIf[$Key] -or $DisableOnlyIf[$Key].Count -eq 0) {
                                        $($Key), " is ", 'Not Set'
                                    } else {
                                        $($Key), " is ", $($DisableOnlyIf[$Key])
                                    }
                                ) -FontWeight bold, normal, bold -Color None, None, CornflowerBlue
                            }
                        }
                    } else {
                        New-HTMLText -Text "Computers will not be disabled, as the disable functionality was not enabled. " -FontWeight bold
                    }
                }
                New-HTMLPanel {
                    if ($Delete) {
                        New-HTMLText -Text "Computers will be deleted only if: " -FontWeight bold
                        New-HTMLList {
                            foreach ($Key in $DeleteOnlyIf.Keys) {
                                New-HTMLListItem -Text @(
                                    if ($null -eq $DeleteOnlyIf[$Key] -or $DeleteOnlyIf[$Key].Count -eq 0) {
                                        $($Key), " is ", 'Not Set'
                                    } else {
                                        $($Key), " is ", $($DeleteOnlyIf[$Key])
                                    }
                                ) -FontWeight bold, normal, bold -Color None, None, CornflowerBlue
                            }
                        }
                    } else {
                        New-HTMLText -Text "Computers will not be deleted, as the delete functionality was not enabled. " -FontWeight bold
                    }
                }
            }

            New-HTMLTable -DataTable $ComputersToProcess -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
            } -WarningAction SilentlyContinue
        }
        if ($LogFile -and (Test-Path -LiteralPath $LogFile)) {
            $LogContent = Get-Content -Raw -LiteralPath $LogFile
            New-HTMLTab -Name 'Log' {
                New-HTMLCodeBlock -Code $LogContent -Style generic
            }
        }
    } -FilePath $FilePath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent
}