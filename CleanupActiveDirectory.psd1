@{
    AliasesToExport      = @()
    Author               = 'Przemyslaw Klys'
    CmdletsToExport      = @()
    CompanyName          = 'Evotec'
    CompatiblePSEditions = @('Desktop', 'Core')
    Copyright            = '(c) 2011 - 2023 Przemyslaw Klys @ Evotec. All rights reserved.'
    Description          = 'This module allows to synchronize users to/from Office 365.'
    FunctionsToExport    = 'Invoke-ADComputersCleanup'
    GUID                 = 'c162c3b8-962c-4ded-bb5f-0a0ea941965d'
    ModuleVersion        = '0.0.1'
    PowerShellVersion    = '5.1'
    PrivateData          = @{
        PSData = @{
            Tags                       = 'windows'
            ProjectUri                 = 'https://github.com/EvotecIT/CleanupActiveDirectory'
            ExternalModuleDependencies = @('ActiveDirectory')
        }
    }
    RequiredModules      = @(@{
            ModuleVersion = '0.0.257'
            ModuleName    = 'PSSharedGoods'
            Guid          = 'ee272aa8-baaa-4edf-9f45-b6d6f7d844fe'
        }, @{
            ModuleVersion = '0.0.181'
            ModuleName    = 'PSWriteHTML'
            Guid          = 'a7bdf640-f5cb-4acf-9de0-365b322d245c'
        }, @{
            ModuleVersion = '0.87.3'
            ModuleName    = 'PSWriteColor'
            Guid          = '0b0ba5c5-ec85-4c2b-a718-874e55a8bc3f'
        }, @{
            ModuleVersion = '1.0.22'
            ModuleName    = 'PSEventViewer'
            Guid          = '5df72a79-cdf6-4add-b38d-bcacf26fb7bc'
        }, 'ActiveDirectory')
    RootModule           = 'CleanupActiveDirectory.psm1'
}