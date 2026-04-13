function New-EmailBodyCloudDevices {
    [CmdletBinding()]
    param(
        [Array] $CurrentRun
    )

    Write-Color -Text '[i] ', 'Generating email body for cloud devices' -Color Yellow, White

    [Array] $retiredDevices = $CurrentRun | Where-Object { $_.Action -eq 'Retire' }
    [Array] $disabledDevices = $CurrentRun | Where-Object { $_.Action -eq 'Disable' }
    [Array] $deletedDevices = $CurrentRun | Where-Object { $_.Action -eq 'Delete' }

    $emailBody = EmailBody -EmailBody {
        EmailText -Text 'Hello,'
        EmailText -LineBreak
        EmailText -Text 'This is an automated email from CleanupMonster for cloud device lifecycle cleanup.' -FontWeight bold
        EmailText -LineBreak
        EmailList {
            EmailListItem -Text 'Objects actioned: ', $CurrentRun.Count -Color None, Green -FontWeight normal, bold
            EmailListItem -Text 'Objects retired: ', $retiredDevices.Count -Color None, Orange -FontWeight normal, bold
            EmailListItem -Text 'Objects disabled: ', $disabledDevices.Count -Color None, Orange -FontWeight normal, bold
            EmailListItem -Text 'Objects deleted: ', $deletedDevices.Count -Color None, Salmon -FontWeight normal, bold
        }
        EmailTable -DataTable $CurrentRun -HideFooter
        EmailText -LineBreak
        EmailText -Text 'Regards,'
        EmailText -Text 'Automations Team' -FontWeight bold
    }

    $emailBody
}
