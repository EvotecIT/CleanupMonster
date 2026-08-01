function Export-ADComputerReportData {
    <#
    .SYNOPSIS
    Serializes the complete AD computer report table with bounded memory usage.

    .DESCRIPTION
    Writes report rows as a JSON array in configurable chunks. Only the current
    chunk and one sample row remain in serialization memory. The returned sample
    is used by PSWriteHTML to configure the DataTables columns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Array] $Computers,
        [Parameter(Mandatory)]
        [string] $FilePath,
        [ValidateRange(1, 10000)]
        [int] $ChunkSize = 2000,
        [string[]] $ExcludeProperty = @('TimeOnPendingList', 'TimeToLeavePendingList', 'DistinguishedNameAfterMove'),
        [AllowEmptyString()]
        [string] $DateTimeFormat = '',
        [System.Collections.IDictionary] $NewLineFormat = @{
            NewLineCarriage = '<br>'
            NewLine         = '\n'
            Carriage        = '\r'
        },
        [System.Collections.IDictionary] $NewLineFormatProperty = @{
            NewLineCarriage = '<br>'
            NewLine         = '\n'
            Carriage        = '\r'
        }
    )

    $Writer = $null
    try {
        $Encoding = [System.Text.UTF8Encoding]::new($false)
        $Writer = [System.IO.StreamWriter]::new($FilePath, $false, $Encoding)
        $Writer.Write('[')

        $Chunk = [System.Collections.Generic.List[object]]::new($ChunkSize)
        $PropertyNames = $null
        $Sample = $null
        $Count = 0
        $WroteData = $false

        foreach ($Computer in $Computers) {
            if ($null -eq $PropertyNames) {
                $PropertyNames = @($Computer.PSObject.Properties.Name | Where-Object { $_ -notin $ExcludeProperty })
                $Sample = $Computer | Select-Object -Property $PropertyNames
            }
            $Chunk.Add($Computer)
            $Count++

            if ($Chunk.Count -ge $ChunkSize) {
                [Array] $PrettyRows = @(ConvertTo-PrettyObject -Object $Chunk.ToArray() -PropertyName $PropertyNames -Force -BoolAsString -ArrayJoin -ArrayJoinString ', ' -DateTimeFormat $DateTimeFormat -NewLineFormat $NewLineFormat -NewLineFormatProperty $NewLineFormatProperty)
                [string] $Json = ConvertTo-Json -InputObject $PrettyRows -Depth 4 -Compress
                if ($Json.Length -gt 2) {
                    if ($WroteData) {
                        $Writer.Write(',')
                    }
                    $Writer.Write($Json.Substring(1, $Json.Length - 2).Replace('<', '&lt;').Replace('>', '&gt;'))
                    $WroteData = $true
                }
                $Chunk.Clear()
                $PrettyRows = $null
                $Json = $null
            }
        }

        if ($Chunk.Count -gt 0) {
            [Array] $PrettyRows = @(ConvertTo-PrettyObject -Object $Chunk.ToArray() -PropertyName $PropertyNames -Force -BoolAsString -ArrayJoin -ArrayJoinString ', ' -DateTimeFormat $DateTimeFormat -NewLineFormat $NewLineFormat -NewLineFormatProperty $NewLineFormatProperty)
            [string] $Json = ConvertTo-Json -InputObject $PrettyRows -Depth 4 -Compress
            if ($Json.Length -gt 2) {
                if ($WroteData) {
                    $Writer.Write(',')
                }
                $Writer.Write($Json.Substring(1, $Json.Length - 2).Replace('<', '&lt;').Replace('>', '&gt;'))
            }
        }
        $Writer.Write(']')
        $Writer.Flush()

        [PSCustomObject] [ordered] @{
            FilePath      = $FilePath
            Count         = $Count
            Sample        = $Sample
            PropertyNames = $PropertyNames
            DataStoreID   = 'CleanupMonsterADComputers'
        }
    } catch {
        $ExportError = $_
    } finally {
        if ($null -ne $Writer) {
            $Writer.Dispose()
        }
    }

    if ($null -ne $ExportError) {
        if (Test-Path -LiteralPath $FilePath) {
            Remove-Item -LiteralPath $FilePath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
        throw $ExportError
    }
}
