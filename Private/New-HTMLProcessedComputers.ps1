function New-HTMLProcessedComputers {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Report,
        [string] $FilePath,
        [switch] $Online,
        [switch] $ShowHTML,
        [string] $LogFile
    )

    New-HTML {
        New-HTMLTabStyle -BorderRadius 0px -TextTransform capitalize -BackgroundColorActive SlateGrey
        New-HTMLSectionStyle -BorderRadius 0px -HeaderBackGroundColor Grey -RemoveShadow
        New-HTMLPanelStyle -BorderRadius 0px
        New-HTMLTableOption -DataStore JavaScript -BoolAsString -ArrayJoinString ', ' -ArrayJoin

        New-HTMLTab -Name 'Computers Pending Deletion' {
            New-HTMLTable -DataTable $Report.ReportPendingDeletion
        }
        New-HTMLTab -Name 'Computers Disabled in Last Run' {
            New-HTMLTable -DataTable $Report.ReportDisabled
        }
        New-HTMLTab -Name 'Computers Deleted in Last Run' {
            New-HTMLTable -DataTable $Report.ReportDeleted
        }
        if ($LogFile -and (Test-Path -LiteralPath $LogFile)) {
            $LogContent = Get-Content -Raw -LiteralPath $LogFile
            New-HTMLTab -Name 'Log' {
                New-HTMLCodeBlock -Code $LogContent -Style generic
            }
        }
    } -FilePath $FilePath -Online:$Online.IsPresent -ShowHTML:$ShowHTML.IsPresent
}