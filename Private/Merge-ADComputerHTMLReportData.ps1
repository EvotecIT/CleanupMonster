function Merge-ADComputerHTMLReportData {
    <#
    .SYNOPSIS
    Streams a JSON report-data file into a PSWriteHTML DataStoreID placeholder.

    .DESCRIPTION
    Keeps the final report self-contained without loading the full serialized
    computer inventory into the PowerShell process as one string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $StagingHtmlPath,
        [Parameter(Mandatory)]
        [string] $DataFilePath,
        [Parameter(Mandatory)]
        [string] $OutputPath,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z_$][A-Za-z0-9_$]*$')]
        [string] $DataStoreID
    )

    $StagingHtml = Get-Content -LiteralPath $StagingHtmlPath -Raw -ErrorAction Stop
    $Pattern = 'var\s+' + [regex]::Escape($DataStoreID) + '\s*=\s*\[[\s\S]*?\];'
    $Matches = [regex]::Matches($StagingHtml, $Pattern)
    if ($Matches.Count -ne 1) {
        throw "Expected one PSWriteHTML data assignment for '$DataStoreID', found $($Matches.Count)."
    }

    $Marker = '__CLEANUPMONSTER_AD_REPORT_DATA_' + [guid]::NewGuid().ToString('N') + '__'
    $Replacement = "var $DataStoreID = $Marker;"
    $HtmlWithMarker = [regex]::Replace($StagingHtml, $Pattern, $Replacement, 1)
    $MarkerIndex = $HtmlWithMarker.IndexOf($Marker, [System.StringComparison]::Ordinal)
    if ($MarkerIndex -lt 0) {
        throw 'The report data marker could not be created.'
    }

    $OutputDirectory = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $null = New-Item -ItemType Directory -Path $OutputDirectory -Force -WhatIf:$false
    }
    $TemporaryOutputPath = "$OutputPath.$([guid]::NewGuid().ToString('N')).tmp"
    $Encoding = [System.Text.UTF8Encoding]::new($false)
    $Writer = $null
    $Reader = $null
    try {
        $Writer = [System.IO.StreamWriter]::new($TemporaryOutputPath, $false, $Encoding)
        $Writer.Write($HtmlWithMarker.Substring(0, $MarkerIndex))

        $Reader = [System.IO.StreamReader]::new($DataFilePath, $Encoding, $true)
        $Buffer = [char[]]::new(65536)
        while (($Read = $Reader.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $Writer.Write($Buffer, 0, $Read)
        }
        $Reader.Dispose()
        $Reader = $null

        $Writer.Write($HtmlWithMarker.Substring($MarkerIndex + $Marker.Length))
        $Writer.Flush()
        $Writer.Dispose()
        $Writer = $null

        Move-Item -LiteralPath $TemporaryOutputPath -Destination $OutputPath -Force -WhatIf:$false -ErrorAction Stop
    } catch {
        if (Test-Path -LiteralPath $TemporaryOutputPath) {
            Remove-Item -LiteralPath $TemporaryOutputPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
        throw
    } finally {
        if ($null -ne $Reader) {
            $Reader.Dispose()
        }
        if ($null -ne $Writer) {
            $Writer.Dispose()
        }
    }
}
