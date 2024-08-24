function New-HTMLProcessedComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [System.Collections.IDictionary] $MoveOnlyIf,
        [Array] $ComputersToProcess,
        [string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile,
        [switch] $Disable,
        [switch] $Delete,
        [switch] $Move,
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

                    [Array] $ListMoved = $($($Export.CurrentRun | Where-Object { $_.Action -eq 'Move' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Move' -Text "Computers moved: $($ListMoved.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
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
                        New-HTMLToast -TextHeader 'Total History' -Text "Actions (disable & move & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible

                    [Array] $ListDisabled = $($($Export.History | Where-Object { $_.Action -eq 'Disable' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disabled History' -Text "Computers disabled so far: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible

                    [Array] $ListMoved = $($($Export.History | Where-Object { $_.Action -eq 'Move' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Moved History' -Text "Computers moved so far: $($ListMoved.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible

                    [Array] $ListDeleted = $($($Export.History | Where-Object { $_.Action -eq 'Delete' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Deleted History' -Text "Computers deleted so far: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible

                } -Invisible
                New-HTMLTable -DataTable $Export.History -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Move' -BackgroundColor Yellow
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue -AllProperties
            }
            New-HTMLTab -Name 'Devices Pending' {
                New-HTMLTable -DataTable $Export.PendingDeletion.Values -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Move' -BackgroundColor Yellow
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue -AllProperties
            }
        }
        New-HTMLTab -Name 'Devices' {
            New-HTMLSection {
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'Total' -Text "Computers Total: $($ComputersToProcess.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To disable' -Text "Computers to be disabled: $($Export.Statistics.ToDisable)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To move' -Text "Computers to be moved: $($Export.Statistics.ToMove)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To delete' -Text "Computers to be deleted: $($Export.Statistics.ToDelete)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                } -Invisible
            } -Invisible
            New-HTMLSection -HeaderText 'General statistics' -CanCollapse {
                New-HTMLPanel {
                    New-HTMLChart {
                        New-ChartPie -Name 'To be disabled' -Value $Export.Statistics.ToDisable
                        New-ChartPie -Name 'To be moved' -Value $Export.Statistics.ToMove
                        New-ChartPie -Name 'To be deleted' -Value $Export.Statistics.ToDelete
                    } -Title "Computers to be disabled or deleted"
                }
                if ($Export.Statistics.ToDisableComputerWorkstation -or $Export.Statistics.ToDisableComputerServer -or $Export.Statistics.ToDisableComputerUnknown) {
                    New-HTMLPanel {
                        New-HTMLChart {
                            New-ChartPie -Name "Disable workstations" -Value $Export.Statistics.ToDisableComputerWorkstation
                            New-ChartPie -Name "Disable servers" -Value $Export.Statistics.ToDisableComputerServer
                            New-ChartPie -Name "Disable unknown" -Value $Export.Statistics.ToDisableComputerUnknown
                        } -Title "Computers to be disabled by type"
                    }
                }
                if ($Export.Statistics.ToDeleteComputerWorkstation -or $Export.Statistics.ToDeleteComputerServer -or $Export.Statistics.ToDeleteComputerUnknown) {
                    New-HTMLPanel {
                        New-HTMLChart {
                            New-ChartPie -Name "Delete workstations" -Value $Export.Statistics.ToDeleteComputerWorkstation
                            New-ChartPie -Name "Delete servers" -Value $Export.Statistics.ToDeleteComputerServer
                            New-ChartPie -Name "Delete unknown" -Value $Export.Statistics.ToDeleteComputerUnknown
                        } -Title "Computers to be deleted by type"
                    }
                }
            }
            New-HTMLText -LineBreak
            New-HTMLHeading -Heading h3 -HeadingText "Full list of computers that will be processed if there are no limits to processing. "
            New-HTMLText -LineBreak
            New-HTMLSection -Invisible {
                New-HTMLPanel {
                    if ($Disable) {
                        New-HTMLText -Text "Computers will be disabled (and moved) only if: " -FontWeight bold
                        New-HTMLList {
                            foreach ($Key in $DisableOnlyIf.Keys) {
                                $newHTMLListItemSplat = @{
                                    Text       = @(
                                        if ($null -eq $DisableOnlyIf[$Key] -or $DisableOnlyIf[$Key].Count -eq 0) {
                                            $($Key), " is ", 'Not Set'
                                            $ColorInUse = 'Cinnabar'
                                        } else {
                                            if ($Key -in 'LastLogonDateMoreThan', 'LastLogonDateOlderThan') {
                                                $($Key), " is ", $($DisableOnlyIf[$Key]), " or ", "Never logged on"
                                            } elseif ($Key -in 'PasswordLastSetMoreThan', 'PasswordLastSetOlderThan') {
                                                $($Key), " is ", $($DisableOnlyIf[$Key]), " or ", "Never changed"
                                            } elseif ($Key -in 'LastSeenAzureMoreThan', 'LastSeenIntuneMoreThan', 'LastSyncAzureMoreThan', 'LastContactJamfMoreThan') {
                                                $($Key), " is ", $($DisableOnlyIf[$Key]), " or ", "Never synced/seen"
                                            } elseif ($Key -in 'MoveTargetOrganizationalUnit') {
                                                if ($DisableOnlyIf[$Key] -is [string]) {
                                                    $($Key), " is ", $MoveOnlyIf[$Key]
                                                } elseif ($DisableOnlyIf[$Key] -is [System.Collections.IDictionary]) {
                                                    $Key
                                                }
                                            } else {
                                                $($Key), " is ", $($DisableOnlyIf[$Key])
                                            }
                                            $ColorInUse = 'Apple'
                                        }
                                    )
                                    FontWeight = 'bold', 'normal', 'bold', 'normal', 'bold'
                                    Color      = $ColorInUse, 'None', 'CornflowerBlue', 'None', 'CornflowerBlue'

                                }
                                if ($Key -eq 'MoveTargetOrganizationalUnit') {
                                    $newHTMLListItemSplat.NestedListItems = {
                                        New-HTMLList {
                                            foreach ($MoveKey in $DisableOnlyIf[$Key].Keys) {
                                                New-HTMLListItem -Text @(
                                                    $MoveKey, " to ", $DisableOnlyIf[$Key][$MoveKey]
                                                ) -FontWeight 'bold', 'normal', 'bold', 'normal', 'bold' -Color $ColorInUse, 'None', 'CornflowerBlue', 'None', 'CornflowerBlue'
                                            }
                                        }
                                    }
                                }
                                New-HTMLListItem @newHTMLListItemSplat
                            }
                        }
                    } else {
                        New-HTMLText -Text "Computers will not be disabled, as the disable functionality was not enabled. " -FontWeight bold
                    }
                }
                New-HTMLPanel {
                    if ($Move) {
                        New-HTMLText -Text "Computers will be moved only if: " -FontWeight bold
                        New-HTMLList {
                            foreach ($Key in $MoveOnlyIf.Keys) {
                                $newHTMLListItemSplat = @{
                                    Text       = @(
                                        if ($null -eq $MoveOnlyIf[$Key] -or $MoveOnlyIf[$Key].Count -eq 0) {
                                            $($Key), " is ", 'Not Set'
                                            $ColorInUse = 'Cinnabar'
                                        } else {
                                            if ($Key -in 'LastLogonDateMoreThan', 'LastLogonDateOlderThan') {
                                                $($Key), " is ", $($MoveOnlyIf[$Key]), " or ", "Never logged on"
                                            } elseif ($Key -in 'PasswordLastSetMoreThan', 'PasswordLastSetOlderThan') {
                                                $($Key), " is ", $($MoveOnlyIf[$Key]), " or ", "Never changed"
                                            } elseif ($Key -in 'LastSeenAzureMoreThan', 'LastSeenIntuneMoreThan', 'LastSyncAzureMoreThan', 'LastContactJamfMoreThan') {
                                                $($Key), " is ", $($MoveOnlyIf[$Key]), " or ", "Never synced/seen"
                                            } elseif ($Key -in 'TargetOrganizationalUnit') {
                                                if ($MoveOnlyIf[$Key] -is [string]) {
                                                    $($Key), " is ", $MoveOnlyIf[$Key]
                                                } elseif ($MoveOnlyIf[$Key] -is [System.Collections.IDictionary]) {
                                                    $Key
                                                }
                                            } else {
                                                $($Key), " is ", $($MoveOnlyIf[$Key])
                                            }
                                            $ColorInUse = 'Apple'
                                        }
                                    )
                                    FontWeight = 'bold', 'normal', 'bold', 'normal', 'bold'
                                    Color      = $ColorInUse, 'None', 'CornflowerBlue', 'None', 'CornflowerBlue'
                                }
                                if ($Key -eq 'TargetOrganizationalUnit') {
                                    $newHTMLListItemSplat.NestedListItems = {
                                        New-HTMLList {
                                            foreach ($MoveKey in $MoveOnlyIf[$Key].Keys) {
                                                New-HTMLListItem -Text @(
                                                    $MoveKey, " to ", $MoveOnlyIf[$Key][$MoveKey]
                                                ) -FontWeight 'bold', 'normal', 'bold', 'normal', 'bold' -Color $ColorInUse, 'None', 'CornflowerBlue', 'None', 'CornflowerBlue'
                                            }
                                        }
                                    }
                                }
                                New-HTMLListItem @newHTMLListItemSplat
                            }
                        }
                    } else {
                        New-HTMLText -Text "Computers will not be moved, as the move functionality was not enabled. " -FontWeight bold
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
                                        $ColorInUse = 'Cinnabar'
                                    } else {
                                        if ($Key -in 'LastLogonDateMoreThan', 'LastLogonDateOlderThan') {
                                            $($Key), " is ", $($DeleteOnlyIf[$Key]), " or ", "Never logged on"
                                        } elseif ($Key -in 'PasswordLastSetMoreThan', 'PasswordLastSetOlderThan') {
                                            $($Key), " is ", $($DeleteOnlyIf[$Key]), " or ", "Never changed"
                                        } elseif ($Key -in 'LastSeenAzureMoreThan', 'LastSeenIntuneMoreThan', 'LastSyncAzureMoreThan', 'LastContactJamfMoreThan') {
                                            $($Key), " is ", $($DeleteOnlyIf[$Key]), " or ", "Never synced/seen"
                                        } else {
                                            $($Key), " is ", $($DeleteOnlyIf[$Key])
                                        }
                                        $ColorInUse = 'Apple'
                                    }
                                ) -FontWeight bold, normal, bold, normal, bold -Color $ColorInUse, None, CornflowerBlue, None, CornflowerBlue
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
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'ExcludedByFilter' -BackgroundColor LightBlue
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'ExcludedBySetting' -BackgroundColor LightPink
            } -WarningAction SilentlyContinue
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