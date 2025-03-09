function New-HTMLProcessedSIDHistory {
    [CmdletBinding()]
    param(
        $Export,
        [System.Collections.IDictionary] $ForestInformation,
        [System.Collections.IDictionary] $Output,
        [string] $FilePath,
        [switch] $HideHTML,
        [switch] $Online
    )
    New-HTML {
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLTableOption -DataStore JavaScript -ArrayJoin -ArrayJoinString ", " -BoolAsString
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey

        New-HTMLHeader {
            New-HTMLSection -Invisible {
                New-HTMLSection -Invisible {
                    New-HTMLSection {
                        New-HTMLText -Text "Report generated on $(Get-Date)" -Color Blue
                    } -JustifyContent flex-start -Invisible
                    New-HTMLSection {
                        New-HTMLText -Text "Cleanup Monster - $($Export['Version'])" -Color Blue
                    } -JustifyContent flex-end -Invisible
                }
            }

            New-HTMLText -Text "Overview of SID History in the forest ", $($ForestInformation.Forest) -Color None, None -FontSize 14pt -FontWeight normal, bold -Alignment center

            New-HTMLSection -HeaderText "SID History Report for $($ForestInformation.Forest)" {
                New-HTMLPanel {
                    New-HTMLText -Text @(
                        "The following table lists all objects in the forest that have SID history values. ",
                        "The table is grouped by domain and shows the number of objects in each domain that have SID history values."
                    ) -FontSize 10pt

                    New-HTMLList {
                        New-HTMLListItem -Text "$($Output.All.Count)", " objects with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.TotalUsers)", "  users with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.TotalGroups)", "  groups with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.TotalComputers)", "  computers with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.EnabledObjects)", "  enabled objects with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.DisabledObjects)", "  disabled objects with SID history values" -Color Salmon, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Keys.Count - 2)", "  different domains with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                    } -LineBreak -FontSize 10pt

                    New-HTMLText -Text @(
                        "The following table lists all trusts in the forest and their respective trust type.",
                        "The trust type can be either external or forest trust."
                    ) -FontSize 10pt

                    New-HTMLText -Text "The following statistics provide insights into the SID history categories:" -FontSize 10pt

                    New-HTMLList {
                        # Add statistics for the three SID history categories
                        New-HTMLListItem -Text "$($Output.Statistics.InternalSIDs)", " SID history values from internal forest domains" -Color ForestGreen, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.ExternalSIDs)", " SID history values from external trusted domains" -Color DodgerBlue, None -FontWeight bold, normal
                        New-HTMLListItem -Text "$($Output.Statistics.UnknownSIDs)", " SID history values from unknown domains (deleted or broken trusts)" -Color Crimson, None -FontWeight bold, normal
                    } -FontSize 10pt
                }
                New-HTMLPanel {
                    New-HTMLText -Text "The following table lists all domains in the forest and their respective domain SID values." -FontSize 10pt
                    New-HTMLList {
                        foreach ($SID in $Output.DomainSIDs.Keys) {
                            $DomainSID = $Output.DomainSIDs[$SID]
                            New-HTMLListItem -Text "Domain ", $($DomainSID.Domain), ", SID: ", $($DomainSID.SID), ", Type: ", $($DomainSID.Type) -Color None, BlueViolet, None, BlueViolet, None, BlueViolet -FontWeight normal, bold, normal, bold, normal, bold
                        }
                    } -FontSize 10pt
                }
            }

        }
        [Array] $DomainNames = foreach ($Key in $Output.Keys) {
            if ($Key -in @('Statistics', 'Trusts', 'DomainSIDs', 'DuplicateSIDs')) {
                continue
            }
            $Key
        }


        New-HTMLTab -Name 'Current Run' {
            New-HTMLSection -HeaderText "SID History Report" {
                New-HTMLPanel {
                    New-HTMLText -Text "The following table lists all objects in the forest that have SID history values." -FontSize 10pt
                }
            }

            [Array] $ReportData = foreach ($Item in $Export.CurrentRun) {
                $Object = $Item.Object
                [PSCustomObject]@{
                    Name               = $Object.Name
                    Domain             = $Object.Domain
                    ObjectClass        = $Object.ObjectClass
                    Enabled            = $Object.Enabled
                    SIDHistoryCount    = $Object.SIDHistory.Count
                    SIDHistory         = $Object.SIDHistory -join ", "
                    OrganizationalUnit = $Object.OrganizationalUnit
                    LastLogon          = $Object.LastLogon
                    WhenChanged        = $Object.WhenChanged
                    DomainType         = $Item.DomainType
                }
            }

            New-HTMLTable -DataTable $ReportData -Filtering {

            } -ScrollX
        }
        New-HTMLTab -Name 'History' {
            New-HTMLSection -HeaderText "SID History Report" {
                New-HTMLPanel {
                    New-HTMLText -Text "The following table lists all objects in the forest that have SID history values." -FontSize 10pt
                }
            }
            New-HTMLTable -DataTable $Export.History -Filtering {

            } -ScrollX
        }
        New-HTMLTab -Name 'Overview' {
            foreach ($Domain in $DomainNames) {
                [Array] $Objects = $Output[$Domain]
                $EnabledObjects = $Objects | Where-Object { $_.Enabled }
                $DisabledObjects = $Objects | Where-Object { -not $_.Enabled }
                $Types = $Objects | Group-Object -Property ObjectClass -NoElement


                if ($Domain -eq 'All') {
                    $Name = 'All'
                } else {
                    if ($Output.DomainSIDs[$Domain]) {
                        $DomainName = $Output.DomainSIDs[$Domain].Domain
                        $DomainType = $Output.DomainSIDs[$Domain].Type
                        #$Name = "$Domain [$DomainName] ($($Objects.Count))"
                        $Name = "$DomainName ($($Objects.Count))"
                    } else {
                        $Name = "$Domain ($($Objects.Count))"
                    }
                }

                New-HTMLTab -Name $Name {
                    New-HTMLSection -HeaderText "Domain $Domain" {
                        New-HTMLPanel -Invisible {
                            New-HTMLText -Text "Overview for ", $Domain -Color Blue, BattleshipGrey -FontSize 10pt
                            New-HTMLList {
                                New-HTMLListItem -Text "$($Objects.Count)", " objects with SID history values" -Color BlueViolet, None -FontWeight bold, normal
                                New-HTMLListItem -Text "$($EnabledObjects.Count)", " enabled objects with SID history values" -Color Green, None -FontWeight bold, normal
                                New-HTMLListItem -Text "$($DisabledObjects.Count)", " disabled objects with SID history values" -Color Salmon, None -FontWeight bold, normal

                                # Calculate SID history categories for this domain
                                $InternalSIDsForDomain = ($Objects | ForEach-Object { $_.InternalCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                                $ExternalSIDsForDomain = ($Objects | ForEach-Object { $_.ExternalCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                                $UnknownSIDsForDomain = ($Objects | ForEach-Object { $_.UnknownCount }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

                                New-HTMLListItem -Text "$InternalSIDsForDomain", " SID history values from internal forest domains" -Color ForestGreen, None -FontWeight bold, normal
                                New-HTMLListItem -Text "$ExternalSIDsForDomain", " SID history values from external trusted domains" -Color DodgerBlue, None -FontWeight bold, normal
                                New-HTMLListItem -Text "$UnknownSIDsForDomain", " SID history values from unknown domains" -Color Crimson, None -FontWeight bold, normal

                                New-HTMLListItem -Text "Object types:" {
                                    New-HTMLList {
                                        foreach ($Type in $Types) {
                                            New-HTMLListItem -Text "$($Type.Count)", " ", $Type.Name, " objects with SID history values" -Color BlueViolet, None, BlueViolet, None -FontWeight bold, normal, bold, normal
                                        }
                                    }
                                } -FontSize 10pt
                            } -FontSize 10pt
                        }
                        New-HTMLPanel -Invisible {
                            New-HTMLText -Text 'Explanation to table columns:' -FontSize 10pt
                            New-HTMLList {
                                New-HTMLListItem -Text "Domain", " - ", "this column shows the domain of the object" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "ObjectClass", " - ", "this column shows the object class of the object (user, device, group)" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "Internal", " - ", "this column shows SIDs from domains within the current forest" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "External", " - ", "this column shows SIDs from domains that are trusted by the current forest" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "Unknown", " - ", "this column shows SIDs from domains that no longer exist or have broken trusts" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "Enabled", " - ", "this column shows if the object is enabled" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "SIDHistory", " - ", "this column shows the SID history values of the object" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "Domains", " - ", "this column shows the domains of the SID history values" -FontWeight bold, normal, normal
                                New-HTMLListItem -Text "DomainsExpanded", " - ", "this column shows the expanded domains of the SID history values (if possible), including SID if not possible to expand" -FontWeight bold, normal, normal
                            } -FontSize 10pt
                        }
                    }
                    New-HTMLTable -DataTable $Objects -Filtering {
                        New-HTMLTableCondition -Name 'Enabled' -ComparisonType bool -Operator eq -Value $true -BackgroundColor MintGreen -FailBackgroundColor Salmon
                        New-HTMLTableCondition -Name 'InternalCount' -ComparisonType number -Operator gt -Value 0 -BackgroundColor ForestGreen
                        New-HTMLTableCondition -Name 'ExternalCount' -ComparisonType number -Operator gt -Value 0 -BackgroundColor DodgerBlue
                        New-HTMLTableCondition -Name 'UnknownCount' -ComparisonType number -Operator gt -Value 0 -BackgroundColor Crimson
                    } -ScrollX
                } -TextTransform uppercase
            }
        }
    } -FilePath $FilePath -ShowHTML:(-not $HideHTML) -Online:$Online.IsPresent


}