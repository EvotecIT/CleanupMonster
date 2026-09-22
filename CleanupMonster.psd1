@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2026 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'This module provides an easy way to cleanup Active Directory and cloud devices from dead/old objects based on various criteria. It can also disable, move, retire or delete objects. It can utilize Azure AD, Intune and Jamf to get additional information about objects before deleting them.'
    FunctionsToExport    = @('Invoke-ADComputersCleanup', 'Invoke-ADServiceAccountsCleanup', 'Invoke-ADSIDHistoryCleanup', 'Invoke-CloudDevicesCleanup')
    GUID                 = 'cd1f9987-6242-452c-a7db-6337d4a6b639'
    ModuleVersion        = '3.1.14'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            ExternalModuleDependencies = @('ActiveDirectory', 'Microsoft.WSMan.Management', 'NetTCPIP', 'CimCmdlets')
            IconUri                    = 'https://evotec.xyz/wp-content/uploads/2023/04/CleanupMonster.png'
            ProjectUri                 = 'https://github.com/EvotecIT/CleanupMonster'
            RequireLicenseAcceptance   = $false
            Tags                       = @('windows', 'activedirectory')
        }
    }
    RequiredModules      = @(@{
            Guid            = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
            ModuleName      = 'PSSharedGoods'
            ModuleVersion   = '0.0.313'
        }, @{
            Guid            = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
            ModuleName      = 'PSWriteHTML'
            ModuleVersion   = '1.41.0'
        }, @{
            Guid            = '5df72a79-cdf6-4add-b38d-bcacf26fb7bc'
            ModuleName      = 'PSEventViewer'
            ModuleVersion   = '4.0.0'
        }, @{
            Guid            = '9fc9fd61-7f11-4f4b-a527-084086f1905f'
            ModuleName      = 'ADEssentials'
            ModuleVersion   = '1.0.5'
        }, @{
            Guid            = '0b0ba5c5-ec85-4c2b-a718-874e55a8bc3f'
            ModuleName      = 'PSWriteColor'
            ModuleVersion   = '1.0.3'
        })
    RootModule           = 'CleanupMonster.psm1'
}
