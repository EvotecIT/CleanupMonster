Import-Module $PSScriptRoot\Modules\PSEventViewer\PSEventViewer.psd1 -Force

Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers'