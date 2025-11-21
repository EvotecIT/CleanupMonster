function New-HTMLProcessedServiceAccounts {
    <#
    .SYNOPSIS
    Creates HTML report for processed service accounts.

    .DESCRIPTION
    This function generates a comprehensive HTML report showing all processed service accounts,
    their actions, statistics, and other relevant information.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export,
        [string] $FilePath,
        [bool] $Online,
        [bool] $ShowHTML,
        [string] $LogFile,
        [Array] $ServiceAccountsToProcess,
        [System.Collections.IDictionary] $DisableOnlyIf,
        [System.Collections.IDictionary] $DeleteOnlyIf,
        [bool] $Delete,
        [bool] $Disable,
        [bool] $ReportOnly
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
                    [Array] $ListAll = $($Export.CurrentRun)
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Total in this run' -Text "Actions (disable & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible

                    [Array] $ListDisabled = $($($Export.CurrentRun | Where-Object { $_.Action -eq 'Disable' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disable' -Text "Service accounts disabled: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible

                    [Array] $ListDeleted = $($($Export.CurrentRun | Where-Object { $_.Action -eq 'Delete' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Delete' -Text "Service accounts deleted: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible
                } -Invisible
                New-HTMLTable -DataTable $Export.CurrentRun -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                    New-HTMLTableCondition -Name 'ProtectedFromAccidentalDeletion' -ComparisonType string -Value $false -BackgroundColor LightBlue -FailBackgroundColor Salmon
                } -WarningAction SilentlyContinue
            }
            New-HTMLTab -Name 'Service Accounts History' {
                New-HTMLSection {
                    [Array] $ListAll = $($Export.History)
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Total History' -Text "Actions (disable & delete): $($ListAll.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                    } -Invisible

                    [Array] $ListDisabled = $($($Export.History | Where-Object { $_.Action -eq 'Disable' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Disabled History' -Text "Service accounts disabled so far: $($ListDisabled.Count)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                    } -Invisible

                    [Array] $ListDeleted = $($($Export.History | Where-Object { $_.Action -eq 'Delete' }))
                    New-HTMLPanel {
                        New-HTMLToast -TextHeader 'Deleted History' -Text "Service accounts deleted so far: $($ListDeleted.Count)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                    } -Invisible

                } -Invisible
                New-HTMLTable -DataTable $Export.History -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                } -WarningAction SilentlyContinue -AllProperties
            }
            New-HTMLTab -Name 'Service Accounts Pending' {
                New-HTMLTable -DataTable $Export.PendingDeletion.Values -Filtering -ScrollX {
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                    New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon
                    New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue
                    New-HTMLTableCondition -Name 'ProtectedFromAccidentalDeletion' -ComparisonType string -Value $false -BackgroundColor LightBlue -FailBackgroundColor Salmon
                } -WarningAction SilentlyContinue -AllProperties
            }
        }

        New-HTMLTab -Name 'Service Accounts' {
            New-HTMLSection {
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'Total' -Text "Service Accounts Total: $($ServiceAccountsToProcess.Count)" -BarColorLeft MintGreen -IconSolid info-circle -IconColor MintGreen
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To disable' -Text "Service accounts to be disabled: $($Export.Statistics.ToDisable)" -BarColorLeft OrangePeel -IconSolid info-circle -IconColor OrangePeel
                } -Invisible
                New-HTMLPanel {
                    New-HTMLToast -TextHeader 'To delete' -Text "Service accounts to be deleted: $($Export.Statistics.ToDelete)" -BarColorLeft OrangeRed -IconSolid info-circle -IconColor OrangeRed
                } -Invisible
            } -Invisible

            New-HTMLSection -HeaderText 'General statistics' -CanCollapse {
                New-HTMLPanel {
                    New-HTMLChart {
                        New-ChartPie -Name 'To be disabled' -Value $Export.Statistics.ToDisable
                        New-ChartPie -Name 'To be deleted' -Value $Export.Statistics.ToDelete
                        New-ChartPie -Name 'No action required' -Value ($Export.Statistics.All - $Export.Statistics.ToDisable - $Export.Statistics.ToDelete)
                    } -Title "Service accounts by action required"
                }
                New-HTMLPanel {
                    New-HTMLChart {
                        New-ChartPie -Name 'MSA' -Value $Export.Statistics.TotalMSA
                        New-ChartPie -Name 'GMSA' -Value $Export.Statistics.TotalGMSA
                        if ($Export.Statistics.TotalUnknown -gt 0) {
                            New-ChartPie -Name 'Unknown' -Value $Export.Statistics.TotalUnknown
                        }
                    } -Title "Service accounts by type"
                }
                if ($Export.Statistics.ToDisableMSA -gt 0 -or $Export.Statistics.ToDisableGMSA -gt 0) {
                    New-HTMLPanel {
                        New-HTMLChart {
                            if ($Export.Statistics.ToDisableMSA -gt 0) {
                                New-ChartPie -Name "Disable MSA" -Value $Export.Statistics.ToDisableMSA
                            }
                            if ($Export.Statistics.ToDisableGMSA -gt 0) {
                                New-ChartPie -Name "Disable GMSA" -Value $Export.Statistics.ToDisableGMSA
                            }
                            if ($Export.Statistics.ToDisableUnknown -gt 0) {
                                New-ChartPie -Name "Disable Unknown" -Value $Export.Statistics.ToDisableUnknown
                            }
                        } -Title "Service accounts to be disabled by type"
                    }
                }
                if ($Export.Statistics.ToDeleteMSA -gt 0 -or $Export.Statistics.ToDeleteGMSA -gt 0) {
                    New-HTMLPanel {
                        New-HTMLChart {
                            if ($Export.Statistics.ToDeleteMSA -gt 0) {
                                New-ChartPie -Name "Delete MSA" -Value $Export.Statistics.ToDeleteMSA
                            }
                            if ($Export.Statistics.ToDeleteGMSA -gt 0) {
                                New-ChartPie -Name "Delete GMSA" -Value $Export.Statistics.ToDeleteGMSA
                            }
                            if ($Export.Statistics.ToDeleteUnknown -gt 0) {
                                New-ChartPie -Name "Delete Unknown" -Value $Export.Statistics.ToDeleteUnknown
                            }
                        } -Title "Service accounts to be deleted by type"
                    }
                }
            }

            New-HTMLSection -HeaderText 'Detailed password age statistics' -CanCollapse {
                if ($Export.Statistics.Delete.'PasswordLastChangedDays'.Keys.Count -gt 0) {
                    New-HTMLPanel {
                        New-HTMLChart {
                            foreach ($PasswordRange in $Export.Statistics.Delete.'PasswordLastChangedDays'.Keys) {
                                New-ChartPie -Name $PasswordRange -Value $Export.Statistics.Delete.'PasswordLastChangedDays'[$PasswordRange]
                            }
                        } -Title "Password age distribution - accounts to be deleted"
                    }
                }
                if ($Export.Statistics.Disable.'PasswordLastChangedDays'.Keys.Count -gt 0) {
                    New-HTMLPanel {
                        New-HTMLChart {
                            foreach ($PasswordRange in $Export.Statistics.Disable.'PasswordLastChangedDays'.Keys) {
                                New-ChartPie -Name $PasswordRange -Value $Export.Statistics.Disable.'PasswordLastChangedDays'[$PasswordRange]
                            }
                        } -Title "Password age distribution - accounts to be disabled"
                    }
                }
            }

            New-HTMLTable -DataTable $ServiceAccountsToProcess -Filtering -ScrollX {
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'ExcludedByFilter' -BackgroundColor LightGray
                New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'ExcludedBySetting' -BackgroundColor LightBlue
                New-HTMLTableCondition -Name 'Enabled' -ComparisonType bool -Operator eq -Value $true -BackgroundColor LightGreen
                New-HTMLTableCondition -Name 'Enabled' -ComparisonType bool -Operator eq -Value $false -BackgroundColor LightCoral
                New-HTMLTableCondition -Name 'ServiceAccountType' -ComparisonType string -Value 'MSA' -BackgroundColor LightCyan
                New-HTMLTableCondition -Name 'ServiceAccountType' -ComparisonType string -Value 'GMSA' -BackgroundColor LightYellow
            } -WarningAction SilentlyContinue
        }

        New-HTMLTab -Name 'Configuration' {
            New-HTMLSection -HeaderText 'Disable Configuration' -CanCollapse {
                if ($Disable) {
                    New-HTMLContainer {
                        foreach ($Key in $DisableOnlyIf.Keys) {
                            if ($null -ne $DisableOnlyIf[$Key] -and $DisableOnlyIf[$Key] -ne '') {
                                New-HTMLPanel {
                                    New-HTMLText -Text "$Key`: " -FontWeight bold
                                    New-HTMLText -Text "$($DisableOnlyIf[$Key])"
                                } -BorderRadius 0px
                            }
                        }
                    }
                } else {
                    New-HTMLText -Text "Disable operation is not enabled." -Color Red
                }
            }
            New-HTMLSection -HeaderText 'Delete Configuration' -CanCollapse {
                if ($Delete) {
                    New-HTMLContainer {
                        foreach ($Key in $DeleteOnlyIf.Keys) {
                            if ($null -ne $DeleteOnlyIf[$Key] -and $DeleteOnlyIf[$Key] -ne '') {
                                New-HTMLPanel {
                                    New-HTMLText -Text "$Key`: " -FontWeight bold
                                    New-HTMLText -Text "$($DeleteOnlyIf[$Key])"
                                } -BorderRadius 0px
                            }
                        }
                    }
                } else {
                    New-HTMLText -Text "Delete operation is not enabled." -Color Red
                }
            }
        }
    } -TitleText "CleanupMonster - Service Accounts Report" -Online:$Online -FilePath $FilePath

    if ($ShowHTML) {
        try {
            Invoke-Item $FilePath
        } catch {
            Write-Color -Text "[w] ", "Couldn't open HTML report $FilePath. Error: $($_.Exception.Message)" -Color Yellow, DarkYellow
        }
    }
}
