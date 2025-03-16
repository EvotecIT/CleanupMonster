function New-EmailBodyComputers {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun
    )

    Write-Color -Text "[i] ", "Generating email body" -Color Yellow, White

    [Array] $DisabledObjects = $CurrentRun | Where-Object { $_.Action -eq 'Disable' }
    [Array] $DeletedObjects = $CurrentRun | Where-Object { $_.Action -eq 'Delete' }

    $EmailBody = EmailBody -EmailBody {
        EmailText -Text "Hello,"

        EmailText -LineBreak

        EmailText -Text "This is an automated email from Automations run on ", $Env:COMPUTERNAME, " on ", (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), " by ", $Env:UserName -Color None, Green, None, Green, None, Green -FontWeight normal, bold, normal, bold, normal, bold

        EmailText -LineBreak

        EmailText -Text "Following is a summary for the computer object cleanup:" -FontWeight bold
        EmailList {
            EmailListItem -Text "Objects actioned: ", $Output.CurrentRun.Count -Color None, Green -FontWeight normal, bold
            EmailListItem -Text "Objects deleted: ", $DeletedObjects.Count -Color None, Salmon -FontWeight normal, bold
            EmailListItem -Text "Objects disabled: ", $DisabledObjects.Count -Color None, Orange -FontWeight normal, bold
        }

        EmailText -Text "Following objects were actioned:" -LineBreak -FontWeight bold -Color Salmon
        EmailTable -DataTable $Output.CurrentRun -HideFooter {
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Delete' -BackgroundColor PinkLace -Inline
            New-HTMLTableCondition -Name 'Action' -ComparisonType string -Value 'Disable' -BackgroundColor EnergyYellow -Inline
            New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'True' -BackgroundColor LightGreen -Inline
            New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'False' -BackgroundColor Salmon -Inline
            New-HTMLTableCondition -Name 'ActionStatus' -ComparisonType string -Value 'Whatif' -BackgroundColor LightBlue -Inline
        }

        EmailText -LineBreak

        EmailText -Text "Regards,"
        EmailText -Text "Automations Team" -FontWeight bold
    }

    Write-Color -Text "[i] ", "Email body generated" -Color Yellow, White

    $EmailBody
}