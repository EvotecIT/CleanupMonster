<#
.SYNOPSIS
Initializes the Windows Event Log source used by CleanupMonster.

.DESCRIPTION
Some computer-cleanup examples assume that the CleanupComputers event source
already exists. Run this once with administrative rights on the host that
will execute the scheduled task.
#>

Import-Module PSEventViewer -Force

Write-Event -ID 10 -LogName 'Application' -EntryType Information -Category 0 -Message 'Initialize' -Source 'CleanupComputers'
