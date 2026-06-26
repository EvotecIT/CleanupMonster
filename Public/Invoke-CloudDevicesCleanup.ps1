function Invoke-CloudDevicesCleanup {
    <#
    .SYNOPSIS
    Cleans up stale Microsoft Entra registered cloud devices.

    .DESCRIPTION
    Handles staged cleanup for Microsoft Entra and Intune cloud device records.
    The default operating-system scope is iOS and Android because these are the
    intended mobile-device cleanup targets, but the scope can be changed with
    IncludeOperatingSystem and ExcludeOperatingSystem.

    The workflow supports three explicit stages:
    - Retire: retires stale Intune managed devices.
    - Disable: disables stale Microsoft Entra devices after matching criteria or pending-list age.
    - Delete: removes stale Microsoft Entra devices and, by default, eligible Intune records.
    - RemoveAutopilotIdentity: removes stale Windows Autopilot identities without deleting Entra or Intune records.

    The cmdlet keeps a datastore with PendingActions and History so staged actions
    can be reviewed over multiple runs. ReportOnly and WhatIf/action-specific
    WhatIf modes show candidates without mutating pending cleanup state.

    Blank activity timestamps are intentionally excluded from destructive actions by default.
    This follows Microsoft guidance for stale-device cleanup where activity timestamps can be empty
    even for active devices.
    Hybrid Azure AD joined, Azure AD joined, synchronized, non-registered, and unknown registration
    records are excluded from this cloud-device workflow; use Invoke-ADComputersCleanup for hybrid device lifecycle cleanup.

    .PARAMETER Retire
    Enables the Intune retire stage.

    .PARAMETER RetireLastSeenIntuneMoreThan
    Retire devices only when the Intune LastSeenDays value is greater than this number.
    Defaults to 120 days. Devices with blank Intune activity are not selected by this criterion.

    .PARAMETER RetireLastSeenEntraMoreThan
    Retire devices only when the Entra LastSeenDays value is greater than this number.
    Devices with blank Entra activity are not selected by this criterion.

    .PARAMETER RetireRegisteredMoreThan
    Retire devices only when the device registration/enrollment age is greater than this number of days.

    .PARAMETER RetireIncludeIntuneOnly
    Allows retire-stage processing of Intune-only orphan records.
    By default, orphan Intune records are discovered and reported but not actioned.

    .PARAMETER RetireLimit
    Maximum number of devices to retire in one run. 0 means unlimited. Default is 10.

    .PARAMETER Disable
    Enables the Microsoft Entra disable stage.

    .PARAMETER DisableLastSeenEntraMoreThan
    Disable devices only when the Entra LastSeenDays value is greater than this number.
    Entra-backed devices must have Enabled equal to $true; unknown enabled state is treated as unsafe.

    .PARAMETER DisableLastSeenIntuneMoreThan
    Disable devices only when the Intune LastSeenDays value is greater than this number.
    Devices with blank Intune activity are not selected by this criterion.

    .PARAMETER DisableRegisteredMoreThan
    Disable devices only when the device registration/enrollment age is greater than this number of days.

    .PARAMETER DisableListProcessedMoreThan
    Disable devices only after they were previously actioned and remained pending longer than this number of days.
    Defaults to 30 days.

    .PARAMETER DisableIncludeEntraOnly
    Allows disable-stage processing of Entra-only records.
    By default, Entra-only records are discovered and reported but not actioned.

    .PARAMETER DisableLimit
    Maximum number of devices to disable in one run. 0 means unlimited. Default is 10.

    .PARAMETER Delete
    Enables the final delete stage.

    .PARAMETER StageDisabledForDelete
    Adds already-disabled delete candidates to PendingActions without deleting them.
    Use this for daily automation where pre-disabled stale devices should wait the
    same DeleteListProcessedMoreThan grace period as devices disabled by CleanupMonster.

    .PARAMETER StageDisabledForDeleteLimit
    Maximum number of already-disabled devices to stage for later delete in one run.
    0 means unlimited. Default is 10.

    .PARAMETER DeleteLastSeenEntraMoreThan
    Delete devices only when the Entra LastSeenDays value is greater than this number.
    Entra-backed devices must have Enabled equal to $false; unknown enabled state is treated as unsafe.

    .PARAMETER DeleteLastSeenIntuneMoreThan
    Delete devices only when the Intune LastSeenDays value is greater than this number.
    Devices with blank Intune activity are not selected by this criterion.

    .PARAMETER DeleteRegisteredMoreThan
    Delete devices only when the device registration/enrollment age is greater than this number of days.

    .PARAMETER DeleteListProcessedMoreThan
    Delete devices only after they were previously actioned and remained pending longer than this number of days.
    Defaults to 30 days.

    .PARAMETER DeleteIncludeEntraOnly
    Allows delete-stage processing of Entra-only orphan records.

    .PARAMETER DeleteIncludeIntuneOnly
    Allows delete-stage processing of Intune-only orphan records.

    .PARAMETER DeleteLimit
    Maximum number of devices to delete in one run. 0 means unlimited. Default is 10.

    .PARAMETER DeleteRemoveIntuneRecord
    Controls whether delete-stage processing also removes eligible Intune managed-device records.
    Defaults to $true.

    .PARAMETER DeleteAutopilotIdentity
    Removes Windows Autopilot device identities before deleting Intune or Entra records.
    When enabled, Autopilot inventory must load successfully. If an onboarded device cannot
    have its Autopilot identity removed, the Intune and Entra record delete sub-actions are skipped.

    .PARAMETER RemoveAutopilotIdentity
    Removes selected Windows Autopilot device identities without deleting matching Intune or Entra records.
    Defaults to requiring a missing associated Intune managed-device id and a last-contact age greater than 90 days.

    .PARAMETER RemoveAutopilotIdentityLastContactMoreThan
    Removes Autopilot identities only when the Autopilot LastContacted age is greater than this number of days.
    Defaults to 90 days. Blank Autopilot last-contact values are excluded unless IncludeUnknownActivity is set.

    .PARAMETER RemoveAutopilotIdentityIntuneAssociationState
    Filters Autopilot identity removal by the Autopilot associated Intune managed-device id.
    Defaults to Missing.

    .PARAMETER RemoveAutopilotIdentityEntraAssociationState
    Filters Autopilot identity removal by the Autopilot associated Microsoft Entra device value.
    EqualsSerialNumber and NotEqualsSerialNumber compare the Autopilot resource/display name with the Autopilot serial number.

    .PARAMETER RemoveAutopilotIdentityLimit
    Maximum number of Autopilot identities to remove in one run. 0 means unlimited. Default is 10.

    .PARAMETER IncludeOperatingSystem
    Operating-system patterns to include when building cloud-device inventory.
    Defaults to iOS and Android patterns. Wildcards are supported.

    .PARAMETER IncludeJoinType
    Microsoft Entra join-type values to include when building cloud-device inventory.
    Defaults to AzureAD registered. Add AzureAD joined explicitly for Windows cloud-joined cleanup.

    .PARAMETER ExcludeOperatingSystem
    Operating-system patterns to exclude when building cloud-device inventory.
    Wildcards are supported.

    .PARAMETER IncludeOperatingSystemVersion
    Operating-system version patterns to include when building cloud-device inventory.

    .PARAMETER ExcludeOperatingSystemVersion
    Operating-system version patterns to exclude when building cloud-device inventory.

    .PARAMETER IncludeUnknownOperatingSystem
    Allows records with blank operating-system values to remain in inventory.

    .PARAMETER IncludeUnknownOperatingSystemVersion
    Allows records with blank operating-system-version values when version filters are set.

    .PARAMETER IncludeUnknownActivity
    Allows blank Entra and Intune activity timestamps to satisfy configured LastSeen*MoreThan filters.
    By default, unknown activity is treated as unsafe and excluded from destructive action selection.

    .PARAMETER IntuneLinkState
    Filters action candidates by the relationship between Microsoft Entra MDM metadata and Intune managed-device inventory.
    Broken means the Entra device claims Intune/MDM management but no matching Intune managed-device record exists.

    .PARAMETER AutopilotState
    Filters action candidates by Windows Autopilot inventory state: Any, Onboarded, or NotOnboarded.
    NotOnboarded only matches when Autopilot inventory was loaded successfully.

    .PARAMETER OwnerState
    Filters action candidates by owner presence: Any, WithOwner, or WithoutOwner.

    .PARAMETER ManagementState
    Filters action candidates by management state: Any, Managed, Unmanaged, Mdm, or NotMdm.

    .PARAMETER ComplianceState
    Filters action candidates by compliance state: Any, Compliant, NonCompliant, or Unknown.

    .PARAMETER EnabledState
    Filters action candidates by Microsoft Entra enabled state: Any, Enabled, Disabled, or Unknown.

    .PARAMETER IncludeManagementAgent
    Management-agent patterns to include for action candidates. Wildcards are supported.

    .PARAMETER ExcludeManagementAgent
    Management-agent patterns to exclude for action candidates. Wildcards are supported.

    .PARAMETER IncludeEnrollmentType
    Enrollment-type patterns to include for action candidates. Wildcards are supported.

    .PARAMETER ExcludeEnrollmentType
    Enrollment-type patterns to exclude for action candidates. Wildcards are supported.

    .PARAMETER IncludeDeviceRegistrationState
    Intune device-registration-state patterns to include for action candidates. Wildcards are supported.

    .PARAMETER ExcludeDeviceRegistrationState
    Intune device-registration-state patterns to exclude for action candidates. Wildcards are supported.

    .PARAMETER IncludeAutopilotGroupTag
    Autopilot group-tag patterns to include for action candidates. Wildcards are supported.

    .PARAMETER ExcludeAutopilotGroupTag
    Autopilot group-tag patterns to exclude for action candidates. Wildcards are supported.

    .PARAMETER Exclusions
    Device names, Entra object IDs, Intune managed-device IDs, or other supported identifiers to exclude from cleanup.

    .PARAMETER IncludeCompanyOwned
    Includes company-owned devices in candidate selection. By default company-owned devices are excluded from actions.

    .PARAMETER DataStorePath
    Path to the XML datastore that tracks PendingActions and History.
    Defaults to ProcessedCloudDevices.xml next to this function.

    .PARAMETER ReportOnly
    Generates inventory and reports without executing retire, disable, or delete actions and without writing updated cleanup state.
    Existing pending actions are still read so staged candidates can be reported accurately.

    .PARAMETER WhatIfRetire
    Previews retire actions only. Preview results are shown in the current report but are not stored as pending actions or history.

    .PARAMETER WhatIfDisable
    Previews disable actions only. Preview results are shown in the current report but are not stored as pending actions or history.

    .PARAMETER WhatIfStageDelete
    Previews staging already-disabled delete candidates without updating the pending-action datastore.

    .PARAMETER WhatIfDelete
    Previews delete actions only. Preview results are shown in the current report but are not stored as pending actions or history.

    .PARAMETER WhatIfRemoveAutopilotIdentity
    Previews standalone Autopilot identity removal only. Preview results are shown in the current report but are not stored in history.

    .PARAMETER LogPath
    Path to a log file. When omitted, file logging is not enabled.

    .PARAMETER LogMaximum
    Maximum number of rotated log files to keep. Default is 5.

    .PARAMETER LogShowTime
    Includes timestamps in log output.

    .PARAMETER LogTimeFormat
    Date/time format used when LogShowTime is enabled.

    .PARAMETER Suppress
    Suppresses returning the export object to the pipeline.

    .PARAMETER ShowHTML
    Opens the generated HTML report after the run.

    .PARAMETER Online
    Uses CDN-hosted CSS and JavaScript assets for the HTML report, reducing report file size.

    .PARAMETER ReportPath
    Path where the HTML report is written.
    Defaults to ProcessedCloudDevices.html next to this function.

    .PARAMETER SafetyEntraLimit
    Stops processing if the Entra inventory count is below this value.
    Use this as a guard against partial Graph inventory responses.

    .PARAMETER SafetyIntuneLimit
    Stops processing if the Intune inventory count is below this value.
    Use this as a guard against partial Graph inventory responses.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -ReportOnly -ShowHTML

    Builds a report of Intune retire candidates using the default stale threshold without changing devices or cleanup state.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -Disable -Delete -RetireLastSeenIntuneMoreThan 120 -DisableListProcessedMoreThan 30 -DeleteListProcessedMoreThan 30

    Runs the full staged workflow: retire stale Intune devices, disable pending devices after 30 days, and delete pending devices after 30 days.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Retire -Disable -Delete -WhatIf -SafetyEntraLimit 1000 -SafetyIntuneLimit 1000 -ReportPath C:\Reports\CloudDevices.html -ShowHTML

    Previews all enabled stages, requires minimum inventory counts, writes an HTML report, and opens it for review.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Delete -DeleteIncludeIntuneOnly -DeleteRemoveIntuneRecord $true -DeleteLastSeenIntuneMoreThan 180 -WhatIfDelete

    Previews cleanup of stale Intune-only orphan records without deleting anything or updating the pending-action datastore.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -RemoveAutopilotIdentity -IncludeJoinType 'AzureAD joined','AzureAD registered' -IncludeOperatingSystem '*' -IncludeUnknownOperatingSystem -RemoveAutopilotIdentityIntuneAssociationState Missing -RemoveAutopilotIdentityLastContactMoreThan 90 -WhatIfRemoveAutopilotIdentity -ShowHTML

    Previews removing stale Windows Autopilot identities whose associated Intune managed-device id is missing.

    .EXAMPLE
    Invoke-CloudDevicesCleanup -Disable -DisableIncludeEntraOnly -DisableListProcessedMoreThan $null -IntuneLinkState Broken -DisableLastSeenEntraMoreThan 90 -IncludeJoinType 'AzureAD joined','AzureAD registered' -IncludeOperatingSystem '*' -IncludeUnknownOperatingSystem -WhatIfDisable -ShowHTML

    Previews disabling Entra devices older than 90 days that claim Intune/MDM management but have no matching Intune managed-device record.

    .EXAMPLE
    $cloudCleanup = Invoke-CloudDevicesCleanup -Disable -DisableLastSeenEntraMoreThan 180 -IncludeOperatingSystem 'Android*' -ExcludeOperatingSystem '*Dedicated*' -Confirm
    $cloudCleanup.CurrentRun | Format-Table Name, Action, ActionStatus, ActionDate

    Disables matching Android Entra-backed devices after confirmation and reviews the current run.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch] $Retire,
        [nullable[int]] $RetireLastSeenIntuneMoreThan = 120,
        [nullable[int]] $RetireLastSeenEntraMoreThan,
        [nullable[int]] $RetireRegisteredMoreThan,
        [switch] $RetireIncludeIntuneOnly,
        [int] $RetireLimit = 10,

        [switch] $Disable,
        [nullable[int]] $DisableLastSeenEntraMoreThan,
        [nullable[int]] $DisableLastSeenIntuneMoreThan,
        [nullable[int]] $DisableRegisteredMoreThan,
        [nullable[int]] $DisableListProcessedMoreThan = 30,
        [switch] $DisableIncludeEntraOnly,
        [int] $DisableLimit = 10,

        [switch] $StageDisabledForDelete,
        [int] $StageDisabledForDeleteLimit = 10,

        [switch] $Delete,
        [nullable[int]] $DeleteLastSeenEntraMoreThan,
        [nullable[int]] $DeleteLastSeenIntuneMoreThan,
        [nullable[int]] $DeleteRegisteredMoreThan,
        [nullable[int]] $DeleteListProcessedMoreThan = 30,
        [switch] $DeleteIncludeEntraOnly,
        [switch] $DeleteIncludeIntuneOnly,
        [int] $DeleteLimit = 10,
        [bool] $DeleteRemoveIntuneRecord = $true,
        [switch] $DeleteAutopilotIdentity,

        [switch] $RemoveAutopilotIdentity,
        [nullable[int]] $RemoveAutopilotIdentityLastContactMoreThan = 90,
        [ValidateSet('Any', 'Missing', 'Present')]
        [string] $RemoveAutopilotIdentityIntuneAssociationState = 'Missing',
        [ValidateSet('Any', 'Missing', 'Present', 'EqualsSerialNumber', 'NotEqualsSerialNumber')]
        [string] $RemoveAutopilotIdentityEntraAssociationState = 'Any',
        [int] $RemoveAutopilotIdentityLimit = 10,

        [ValidateSet('Hybrid AzureAD', 'AzureAD joined', 'AzureAD registered', 'Not available')]
        [string[]] $IncludeJoinType = @('AzureAD registered'),
        [Array] $IncludeOperatingSystem = @('iOS*', 'Android*'),
        [Array] $ExcludeOperatingSystem = @(),
        [Array] $IncludeOperatingSystemVersion = @(),
        [Array] $ExcludeOperatingSystemVersion = @(),
        [switch] $IncludeUnknownOperatingSystem,
        [switch] $IncludeUnknownOperatingSystemVersion,
        [switch] $IncludeUnknownActivity,
        [ValidateSet('Any', 'Healthy', 'Broken', 'NotClaimed', 'IntuneOnly')]
        [string] $IntuneLinkState = 'Any',
        [ValidateSet('Any', 'Onboarded', 'NotOnboarded')]
        [string] $AutopilotState = 'Any',
        [ValidateSet('Any', 'WithOwner', 'WithoutOwner')]
        [string] $OwnerState = 'Any',
        [ValidateSet('Any', 'Managed', 'Unmanaged', 'Mdm', 'NotMdm')]
        [string] $ManagementState = 'Any',
        [ValidateSet('Any', 'Compliant', 'NonCompliant', 'Unknown')]
        [string] $ComplianceState = 'Any',
        [ValidateSet('Any', 'Enabled', 'Disabled', 'Unknown')]
        [string] $EnabledState = 'Any',
        [Array] $IncludeManagementAgent = @(),
        [Array] $ExcludeManagementAgent = @(),
        [Array] $IncludeEnrollmentType = @(),
        [Array] $ExcludeEnrollmentType = @(),
        [Array] $IncludeDeviceRegistrationState = @(),
        [Array] $ExcludeDeviceRegistrationState = @(),
        [Array] $IncludeAutopilotGroupTag = @(),
        [Array] $ExcludeAutopilotGroupTag = @(),
        [Array] $Exclusions = @(),
        [switch] $IncludeCompanyOwned,

        [string] $DataStorePath,
        [switch] $ReportOnly,
        [switch] $WhatIfRetire,
        [switch] $WhatIfDisable,
        [switch] $WhatIfStageDelete,
        [switch] $WhatIfDelete,
        [switch] $WhatIfRemoveAutopilotIdentity,
        [string] $LogPath,
        [int] $LogMaximum = 5,
        [switch] $LogShowTime,
        [string] $LogTimeFormat,
        [switch] $Suppress,
        [switch] $ShowHTML,
        [switch] $Online,
        [string] $ReportPath,
        [nullable[int]] $SafetyEntraLimit,
        [nullable[int]] $SafetyIntuneLimit
    )

    if ($WhatIfPreference) {
        if (-not $PSBoundParameters.ContainsKey('WhatIfRetire')) {
            $WhatIfRetire = $true
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIfDisable')) {
            $WhatIfDisable = $true
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIfStageDelete')) {
            $WhatIfStageDelete = $true
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIfDelete')) {
            $WhatIfDelete = $true
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIfRemoveAutopilotIdentity')) {
            $WhatIfRemoveAutopilotIdentity = $true
        }
    }

    if ($RemoveAutopilotIdentity -and -not $PSBoundParameters.ContainsKey('IncludeOperatingSystem')) {
        $IncludeOperatingSystem = @($IncludeOperatingSystem + 'Windows*') | Select-Object -Unique
    }
    if ($RemoveAutopilotIdentity -and -not $PSBoundParameters.ContainsKey('IncludeJoinType')) {
        $IncludeJoinType = @($IncludeJoinType + 'AzureAD joined') | Select-Object -Unique
    }

    Set-LoggingCapabilities -LogPath $LogPath -LogMaximum $LogMaximum -ShowTime:$LogShowTime -TimeFormat $LogTimeFormat -ScriptPath $MyInvocation.ScriptName

    if (-not $DataStorePath) {
        $DataStorePath = Join-Path -Path $MyInvocation.PSScriptRoot -ChildPath 'ProcessedCloudDevices.xml'
    }
    if (-not $ReportPath) {
        $ReportPath = Join-Path -Path $MyInvocation.PSScriptRoot -ChildPath 'ProcessedCloudDevices.html'
    }

    Set-ReportingCapabilities -ReportPath $ReportPath -ReportMaximum 0 -ScriptPath $MyInvocation.ScriptName

    Write-Color -Text '[i] ', 'Started process of cleaning up stale cloud devices' -Color Yellow, White
    Write-Color -Text '[i] ', 'Executed by: ', $Env:USERNAME -Color Yellow, White, Green

    if (-not (Assert-CloudDeviceCleanupSettings)) {
        return
    }

    $processStageDisabledForDelete = $StageDisabledForDelete.IsPresent
    if ($processStageDisabledForDelete -and $null -eq $DeleteLastSeenEntraMoreThan -and $null -eq $DeleteLastSeenIntuneMoreThan -and $null -eq $DeleteRegisteredMoreThan) {
        Write-Color -Text '[e] ', 'StageDisabledForDelete requires at least one stale delete filter: DeleteLastSeenEntraMoreThan, DeleteLastSeenIntuneMoreThan, or DeleteRegisteredMoreThan.' -Color Yellow, Red
        $processStageDisabledForDelete = $false
    }

    if (-not $Retire -and -not $Disable -and -not $processStageDisabledForDelete -and -not $Delete -and -not $RemoveAutopilotIdentity) {
        Write-Color -Text '[i] ', 'No action can be taken. You need to enable Retire, Disable, StageDisabledForDelete, Delete or RemoveAutopilotIdentity.' -Color Yellow, Red
        return
    }

    $confirmActions = $PSBoundParameters.ContainsKey('Confirm') -and [bool] $PSBoundParameters['Confirm']

    $retireOnlyIf = [ordered] @{
        LastSeenIntuneMoreThan = $RetireLastSeenIntuneMoreThan
        LastSeenEntraMoreThan  = $RetireLastSeenEntraMoreThan
        RegisteredMoreThan     = $RetireRegisteredMoreThan
        IncludeUnknownActivity = $IncludeUnknownActivity.IsPresent
        ExcludeCompanyOwned    = -not $IncludeCompanyOwned
        IntuneLinkState        = $IntuneLinkState
        IncludeIntuneOnly      = $RetireIncludeIntuneOnly.IsPresent
        AutopilotState         = $AutopilotState
        OwnerState             = $OwnerState
        ManagementState        = $ManagementState
        ComplianceState        = $ComplianceState
        EnabledState           = $EnabledState
        IncludeManagementAgent = $IncludeManagementAgent
        ExcludeManagementAgent = $ExcludeManagementAgent
        IncludeEnrollmentType  = $IncludeEnrollmentType
        ExcludeEnrollmentType  = $ExcludeEnrollmentType
        IncludeDeviceRegistrationState = $IncludeDeviceRegistrationState
        ExcludeDeviceRegistrationState = $ExcludeDeviceRegistrationState
        IncludeAutopilotGroupTag = $IncludeAutopilotGroupTag
        ExcludeAutopilotGroupTag = $ExcludeAutopilotGroupTag
    }

    $disableOnlyIf = [ordered] @{
        LastSeenEntraMoreThan  = $DisableLastSeenEntraMoreThan
        LastSeenIntuneMoreThan = $DisableLastSeenIntuneMoreThan
        RegisteredMoreThan     = $DisableRegisteredMoreThan
        ListProcessedMoreThan  = $DisableListProcessedMoreThan
        IncludeUnknownActivity = $IncludeUnknownActivity.IsPresent
        ExcludeCompanyOwned    = -not $IncludeCompanyOwned
        IntuneLinkState        = $IntuneLinkState
        IncludeEntraOnly       = $DisableIncludeEntraOnly.IsPresent
        AutopilotState         = $AutopilotState
        OwnerState             = $OwnerState
        ManagementState        = $ManagementState
        ComplianceState        = $ComplianceState
        EnabledState           = $EnabledState
        IncludeManagementAgent = $IncludeManagementAgent
        ExcludeManagementAgent = $ExcludeManagementAgent
        IncludeEnrollmentType  = $IncludeEnrollmentType
        ExcludeEnrollmentType  = $ExcludeEnrollmentType
        IncludeDeviceRegistrationState = $IncludeDeviceRegistrationState
        ExcludeDeviceRegistrationState = $ExcludeDeviceRegistrationState
        IncludeAutopilotGroupTag = $IncludeAutopilotGroupTag
        ExcludeAutopilotGroupTag = $ExcludeAutopilotGroupTag
    }

    $deleteOnlyIf = [ordered] @{
        LastSeenEntraMoreThan  = $DeleteLastSeenEntraMoreThan
        LastSeenIntuneMoreThan = $DeleteLastSeenIntuneMoreThan
        RegisteredMoreThan     = $DeleteRegisteredMoreThan
        ListProcessedMoreThan  = $DeleteListProcessedMoreThan
        IncludeUnknownActivity = $IncludeUnknownActivity.IsPresent
        ExcludeCompanyOwned    = -not $IncludeCompanyOwned
        IntuneLinkState        = $IntuneLinkState
        IncludeEntraOnly       = $DeleteIncludeEntraOnly.IsPresent
        IncludeIntuneOnly      = $DeleteIncludeIntuneOnly.IsPresent
        AutopilotState         = $AutopilotState
        OwnerState             = $OwnerState
        ManagementState        = $ManagementState
        ComplianceState        = $ComplianceState
        EnabledState           = $EnabledState
        IncludeManagementAgent = $IncludeManagementAgent
        ExcludeManagementAgent = $ExcludeManagementAgent
        IncludeEnrollmentType  = $IncludeEnrollmentType
        ExcludeEnrollmentType  = $ExcludeEnrollmentType
        IncludeDeviceRegistrationState = $IncludeDeviceRegistrationState
        ExcludeDeviceRegistrationState = $ExcludeDeviceRegistrationState
        IncludeAutopilotGroupTag = $IncludeAutopilotGroupTag
        ExcludeAutopilotGroupTag = $ExcludeAutopilotGroupTag
    }

    $removeAutopilotIdentityOnlyIf = [ordered] @{
        AutopilotLastContactMoreThan = $RemoveAutopilotIdentityLastContactMoreThan
        IncludeUnknownActivity       = $IncludeUnknownActivity.IsPresent
        ExcludeCompanyOwned          = -not $IncludeCompanyOwned
        IntuneLinkState              = $IntuneLinkState
        AutopilotState               = 'Onboarded'
        AutopilotIntuneAssociationState = $RemoveAutopilotIdentityIntuneAssociationState
        AutopilotEntraAssociationState = $RemoveAutopilotIdentityEntraAssociationState
        OwnerState                   = $OwnerState
        ManagementState              = $ManagementState
        ComplianceState              = $ComplianceState
        EnabledState                 = $EnabledState
        IncludeManagementAgent       = $IncludeManagementAgent
        ExcludeManagementAgent       = $ExcludeManagementAgent
        IncludeEnrollmentType        = $IncludeEnrollmentType
        ExcludeEnrollmentType        = $ExcludeEnrollmentType
        IncludeDeviceRegistrationState = $IncludeDeviceRegistrationState
        ExcludeDeviceRegistrationState = $ExcludeDeviceRegistrationState
        IncludeAutopilotGroupTag     = $IncludeAutopilotGroupTag
        ExcludeAutopilotGroupTag     = $ExcludeAutopilotGroupTag
    }

    $stageDeleteOnlyIf = [ordered] @{}
    foreach ($key in $deleteOnlyIf.Keys) {
        $stageDeleteOnlyIf[$key] = $deleteOnlyIf[$key]
    }
    $stageDeleteOnlyIf.ListProcessedMoreThan = $null

    $export = [ordered] @{
        Version        = Get-GitHubVersion -Cmdlet 'Invoke-CloudDevicesCleanup' -RepositoryOwner 'evotecit' -RepositoryName 'CleanupMonster'
        CurrentRun     = @()
        History        = @()
        PendingActions = [ordered] @{}
    }

    $processedDevices = Import-CloudDevicesData -DataStorePath $DataStorePath -Export $export
    if ($processedDevices -eq $false) {
        return
    }

    $includeAutopilotInventory = $RemoveAutopilotIdentity -or $DeleteAutopilotIdentity -or $AutopilotState -ne 'Any' -or $OwnerState -ne 'Any' -or $IncludeAutopilotGroupTag.Count -gt 0 -or $ExcludeAutopilotGroupTag.Count -gt 0
    $allDevices = Get-InitialCloudDevices -SafetyEntraLimit $SafetyEntraLimit -SafetyIntuneLimit $SafetyIntuneLimit -IncludeJoinType $IncludeJoinType -IncludeOperatingSystem $IncludeOperatingSystem -ExcludeOperatingSystem $ExcludeOperatingSystem -IncludeOperatingSystemVersion $IncludeOperatingSystemVersion -ExcludeOperatingSystemVersion $ExcludeOperatingSystemVersion -IncludeUnknownOperatingSystem:$IncludeUnknownOperatingSystem -IncludeUnknownOperatingSystemVersion:$IncludeUnknownOperatingSystemVersion -Exclusions $Exclusions -IncludeAutopilotInventory:$includeAutopilotInventory
    if ($allDevices -eq $false) {
        return
    }

    $today = Get-Date
    $reportRetired = @()
    $reportDisabled = @()
    $reportStagedForDelete = @()
    $reportDeleted = @()
    $reportAutopilotIdentityRemoved = @()

    if ($Retire) {
        $devicesToRetire = @(Get-CloudDevicesToProcess -Type Retire -Devices $allDevices -ActionIf $retireOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be retired: ', $devicesToRetire.Count, '. Current retire limit: ', $(if ($RetireLimit -eq 0) { 'Unlimited' } else { $RetireLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processRetire = $devicesToRetire.Count -gt 0
        if ($processRetire -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfRetire)) {
            $processRetire = $PSCmdlet.ShouldProcess("$($devicesToRetire.Count) cloud device(s)", 'Retire')
        }
        if ($processRetire) {
            $reportRetired = @(Request-CloudDevicesRetire -Devices $devicesToRetire -ProcessedDevices $processedDevices -Today $today -RetireLimit $RetireLimit -ReportOnly:$ReportOnly -WhatIfRetire:$WhatIfRetire -WhatIf:$WhatIfPreference)
        }
    }

    if ($Disable) {
        $devicesToDisable = @(Get-CloudDevicesToProcess -Type Disable -Devices $allDevices -ActionIf $disableOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be disabled: ', $devicesToDisable.Count, '. Current disable limit: ', $(if ($DisableLimit -eq 0) { 'Unlimited' } else { $DisableLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processDisable = $devicesToDisable.Count -gt 0
        if ($processDisable -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfDisable)) {
            $processDisable = $PSCmdlet.ShouldProcess("$($devicesToDisable.Count) cloud device(s)", 'Disable')
        }
        if ($processDisable) {
            $reportDisabled = @(Request-CloudDevicesDisable -Devices $devicesToDisable -ProcessedDevices $processedDevices -Today $today -DisableLimit $DisableLimit -ReportOnly:$ReportOnly -WhatIfDisable:$WhatIfDisable -WhatIf:$WhatIfPreference)
        }
    }

    if ($processStageDisabledForDelete) {
        $devicesToStageForDelete = @(Get-CloudDevicesToProcess -Type Delete -Devices $allDevices -ActionIf $stageDeleteOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be staged for delete: ', $devicesToStageForDelete.Count, '. Current stage limit: ', $(if ($StageDisabledForDeleteLimit -eq 0) { 'Unlimited' } else { $StageDisabledForDeleteLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processStageDelete = $devicesToStageForDelete.Count -gt 0
        if ($processStageDelete -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfStageDelete)) {
            $processStageDelete = $PSCmdlet.ShouldProcess("$($devicesToStageForDelete.Count) cloud device(s)", 'Stage for delete')
        }
        if ($processStageDelete) {
            $reportStagedForDelete = @(Request-CloudDevicesStageDelete -Devices $devicesToStageForDelete -ProcessedDevices $processedDevices -Today $today -StageLimit $StageDisabledForDeleteLimit -ReportOnly:$ReportOnly -WhatIfStageDelete:$WhatIfStageDelete -WhatIf:$WhatIfPreference)
        }
    }

    if ($Delete) {
        $devicesToDelete = @(Get-CloudDevicesToProcess -Type Delete -Devices $allDevices -ActionIf $deleteOnlyIf -ProcessedDevices $processedDevices)
        Write-Color -Text '[i] ', 'Devices to be deleted: ', $devicesToDelete.Count, '. Current delete limit: ', $(if ($DeleteLimit -eq 0) { 'Unlimited' } else { $DeleteLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processDelete = $devicesToDelete.Count -gt 0
        if ($processDelete -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfDelete)) {
            $processDelete = $PSCmdlet.ShouldProcess("$($devicesToDelete.Count) cloud device(s)", 'Delete')
        }
        if ($processDelete) {
            $reportDeleted = @(Request-CloudDevicesDelete -Devices $devicesToDelete -ProcessedDevices $processedDevices -Today $today -DeleteLimit $DeleteLimit -DeleteRemoveIntuneRecord:$DeleteRemoveIntuneRecord -DeleteAutopilotIdentity:$DeleteAutopilotIdentity -ReportOnly:$ReportOnly -WhatIfDelete:$WhatIfDelete -WhatIf:$WhatIfPreference)
        }
    }

    if ($RemoveAutopilotIdentity) {
        $devicesToRemoveAutopilotIdentity = @(Get-CloudDevicesToProcess -Type RemoveAutopilotIdentity -Devices $allDevices -ActionIf $removeAutopilotIdentityOnlyIf -ProcessedDevices $processedDevices)
        $autopilotDeviceIdsHandledByDelete = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($deletedDevice in @($reportDeleted | Where-Object { $_.ActionStatus -in 'True', 'WhatIf', 'ReportOnly' })) {
            if (-not [string]::IsNullOrWhiteSpace([string] $deletedDevice.AutopilotDeviceId)) {
                $null = $autopilotDeviceIdsHandledByDelete.Add([string] $deletedDevice.AutopilotDeviceId)
            }
        }
        if ($autopilotDeviceIdsHandledByDelete.Count -gt 0) {
            $devicesToRemoveAutopilotIdentity = @($devicesToRemoveAutopilotIdentity | Where-Object {
                    [string]::IsNullOrWhiteSpace([string] $_.AutopilotDeviceId) -or -not $autopilotDeviceIdsHandledByDelete.Contains([string] $_.AutopilotDeviceId)
                })
        }
        Write-Color -Text '[i] ', 'Autopilot identities to be removed: ', $devicesToRemoveAutopilotIdentity.Count, '. Current remove limit: ', $(if ($RemoveAutopilotIdentityLimit -eq 0) { 'Unlimited' } else { $RemoveAutopilotIdentityLimit }) -Color Yellow, Cyan, Green, Cyan, Yellow

        $processRemoveAutopilotIdentity = $devicesToRemoveAutopilotIdentity.Count -gt 0
        if ($processRemoveAutopilotIdentity -and $confirmActions -and -not ($ReportOnly -or $WhatIfPreference -or $WhatIfRemoveAutopilotIdentity)) {
            $processRemoveAutopilotIdentity = $PSCmdlet.ShouldProcess("$($devicesToRemoveAutopilotIdentity.Count) Windows Autopilot device identity(s)", 'Remove Autopilot identity')
        }
        if ($processRemoveAutopilotIdentity) {
            $reportAutopilotIdentityRemoved = @(Request-CloudDevicesRemoveAutopilotIdentity -Devices $devicesToRemoveAutopilotIdentity -Today $today -RemoveAutopilotIdentityLimit $RemoveAutopilotIdentityLimit -ReportOnly:$ReportOnly -WhatIfRemoveAutopilotIdentity:$WhatIfRemoveAutopilotIdentity -GlobalWhatIf:$WhatIfPreference)
        }
    }

    $export.PendingActions = $processedDevices
    $export.CurrentRun = @(
        if ($reportRetired.Count -gt 0) { $reportRetired }
        if ($reportDisabled.Count -gt 0) { $reportDisabled }
        if ($reportStagedForDelete.Count -gt 0) { $reportStagedForDelete }
        if ($reportDeleted.Count -gt 0) { $reportDeleted }
        if ($reportAutopilotIdentityRemoved.Count -gt 0) { $reportAutopilotIdentityRemoved }
    )
    $persistedRun = @()
    if ($reportRetired.Count -gt 0) {
        $persistedRun += @($reportRetired | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    if ($reportDisabled.Count -gt 0) {
        $persistedRun += @($reportDisabled | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    if ($reportStagedForDelete.Count -gt 0) {
        $persistedRun += @($reportStagedForDelete | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    if ($reportDeleted.Count -gt 0) {
        $persistedRun += @($reportDeleted | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    if ($reportAutopilotIdentityRemoved.Count -gt 0) {
        $persistedRun += @($reportAutopilotIdentityRemoved | Where-Object { $_.ActionStatus -notin 'WhatIf', 'ReportOnly' })
    }
    $export.History = @(
        if ($export.History) { $export.History }
        if ($persistedRun.Count -gt 0) { $persistedRun }
    )

    if (-not $ReportOnly) {
        try {
            $export | Export-Clixml -LiteralPath $DataStorePath -Encoding Unicode -WhatIf:$false -ErrorAction Stop
        } catch {
            Write-Color -Text '[-] Exporting processed cloud device list failed. Error: ', $_.Exception.Message -Color Yellow, Red
        }
    }

    New-HTMLProcessedCloudDevices -Export $export -Devices $allDevices -RetireOnlyIf $retireOnlyIf -DisableOnlyIf $disableOnlyIf -DeleteOnlyIf $deleteOnlyIf -RemoveAutopilotIdentityOnlyIf $removeAutopilotIdentityOnlyIf -FilePath $ReportPath -Online:$Online -ShowHTML:$ShowHTML -LogFile $LogPath

    Write-Color -Text '[i] ', 'Finished process of cleaning up stale cloud devices' -Color Green

    if (-not $Suppress) {
        $export.EmailBody = New-EmailBodyCloudDevices -CurrentRun $export.CurrentRun
        $export
    }
}
