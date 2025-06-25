function New-EmailBodySidHistory {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Export
    )

    $EmailBody = EmailBody -EmailBody {
        EmailText -Text "Hello,"

        EmailText -LineBreak

        EmailText -Text "This is an automated email from Automations run on ", $Env:COMPUTERNAME, " on ", (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), " by ", $Env:UserName -Color None, Green, None, Green, None, Green -FontWeight normal, bold, normal, bold, normal, bold

        EmailText -LineBreak

        New-HTMLText -Text "The following table lists all actions that were taken on given objects while removing SID History. The following statistics provide insights into processed SID history in the forest:" -FontSize 10pt

        $Enabled = $Export.CurrentRun | Where-Object { $_.Enabled }
        $Disabled = $Export.CurrentRun | Where-Object { -not $_.Enabled }

        EmailList {
            EmailListItem -Text "$($Enabled.Count)", " enabled objects" -FontWeight normal, bold
            EmailListItem -Text "$($Disabled.Count)", " disabled objects" -FontWeight normal, bold
            EmailListItem -Text "Processed ", $($Export.ProcessedObjects), " total objects" -FontWeight normal, bold, normal
            EmailListItem -Text "Processed ", $($Export.ProcessedSIDs), " total SID history values" -FontWeight normal, bold, normal
        } -FontSize 10pt

        EmailText -Text "Following objects were actioned:" -LineBreak -FontWeight bold -Color Salmon

        EmailTable -DataTable $Export.CurrentRun {
            EmailTableCondition -Name 'Enabled' -ComparisonType bool -Operator eq -Value $true -BackgroundColor MintGreen -FailBackgroundColor Salmon -Inline
            EmailTableCondition -Name 'SIDBeforeCount' -ComparisonType number -Operator gt -Value 0 -BackgroundColor LightCoral -FailBackgroundColor LightGreen -Inline
            EmailTableCondition -Name 'SIDAfterCount' -ComparisonType number -Operator eq -Value 0 -BackgroundColor LightGreen -FailBackgroundColor Salmon -Inline

            EmailTableCondition -Name 'Action' -ComparisonType string -Value 'RemoveAll' -BackgroundColor LightPink -Inline
            EmailTableCondition -Name 'Action' -ComparisonType string -Value 'RemovePerSID' -BackgroundColor LightCoral -Inline

            EmailTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Success' -BackgroundColor LightGreen -Inline
            EmailTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Failed' -BackgroundColor Salmon -Inline
            EmailTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'WhatIf' -BackgroundColor LightBlue -Inline
        } -HideFooter -PrettifyObject -WarningAction SilentlyContinue

        EmailText -LineBreak

        EmailText -Text "Regards,"
        EmailText -Text "Automations Team" -FontWeight bold
    }
    $EmailBody
}