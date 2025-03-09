function New-EmailBodySidHistory {
    [CmdletBinding()]
    param(

    )

    $EmailBody = EmailBody -EmailBody {
        EmailText -Text "Hello,"

        EmailText -LineBreak

        EmailText -Text "This is an automated email from Automations run on ", $Env:COMPUTERNAME, " on ", (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), " by ", $Env:UserName -Color None, Green, None, Green, None, Green -FontWeight normal, bold, normal, bold, normal, bold

        EmailText -LineBreak

        # EmailText -Text "Following is a summary for the computer object cleanup:" -FontWeight bold
        # EmailList {
        #     EmailListItem -Text "Objects actioned: ", $Output.CurrentRun.Count -Color None, Green -FontWeight normal, bold
        #     EmailListItem -Text "Objects deleted: ", $DeletedObjects.Count -Color None, Salmon -FontWeight normal, bold
        #     EmailListItem -Text "Objects disabled: ", $DisabledObjects.Count -Color None, Orange -FontWeight normal, bold
        # }

        # EmailText -Text "Following objects were actioned:" -LineBreak -FontWeight bold -Color Salmon
        # EmailTable -DataTable $Output.CurrentRun -HideFooter {
        #     New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackGroundColor PinkLace -Inline
        #     New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackGroundColor EnergyYellow -Inline
        #     New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackGroundColor LightGreen -Inline
        #     New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackGroundColor Salmon -Inline
        #     New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackGroundColor LightBlue -Inline
        # }

        EmailText -LineBreak

        EmailText -Text "Regards,"
        EmailText -Text "Automations Team" -FontWeight bold
    }
    $EmailBody
}