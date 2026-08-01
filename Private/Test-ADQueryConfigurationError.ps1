function Test-ADQueryConfigurationError {
    <#
    .SYNOPSIS
    Determines whether an AD query error is independent of the selected server.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $Message = [string] $ErrorRecord.Exception.Message
    $Message -like '*distinguishedName must belong to one of the following partition*' -or
        $Message -like '*The search filter cannot be recognized*' -or
        $Message -like '*The supplied distinguishedName must belong*'
}
