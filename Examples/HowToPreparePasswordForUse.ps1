<#
.SYNOPSIS
Encrypts a plaintext password for reuse in example scripts.

.DESCRIPTION
This helper converts a plaintext password into the secure string format used
by some examples that pass encrypted credentials to other modules or tools.

Use it only when a dependency requires this format. Prefer gMSA or other
secret-management approaches when possible.
#>

ConvertTo-SecureString -String 'PasswordToProtect' -AsPlainText -Force | ConvertFrom-SecureString | Set-Clipboard
