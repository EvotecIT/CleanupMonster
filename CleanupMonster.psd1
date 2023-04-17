@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2023 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'This module provides an easy way to cleanup Active Directory from dead/old objects.'
    FunctionsToExport    = 'Invoke-ADComputersCleanup'
    GUID                 = 'cd1f9987-6242-452c-a7db-6337d4a6b639'
    ModuleVersion        = '1.2.0'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            Tags                       = @('windows', 'activedirectory')
            ProjectUri                 = 'https://github.com/EvotecIT/CleanupMonster'
            IconUri                    = 'https://evotec.xyz/wp-content/uploads/2023/04/CleanupMonster.png'
            ExternalModuleDependencies = @('ActiveDirectory', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Diagnostics')
        }
    }
    RequiredModules      = @(@{
            ModuleName    = 'PSSharedGoods'
            ModuleVersion = '0.0.260'
            Guid          = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
        }, @{
            ModuleName    = 'PSWriteHTML'
            ModuleVersion = '0.0.184'
            Guid          = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
        }, @{
            ModuleName    = 'PSWriteColor'
            ModuleVersion = '0.87.3'
            Guid          = '0b0ba5c5-ec85-4c2b-a718-874e55a8bc3f'
        }, @{
            ModuleName    = 'PSEventViewer'
            ModuleVersion = '1.0.22'
            Guid          = '5df72a79-cdf6-4add-b38d-bcacf26fb7bc'
        }, 'ActiveDirectory', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Diagnostics')
    RootModule           = 'CleanupMonster.psm1'
}