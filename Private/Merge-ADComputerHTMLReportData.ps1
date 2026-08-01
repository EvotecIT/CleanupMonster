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
    $AssignmentPattern = '\bvar\s+' + [regex]::Escape($DataStoreID) + '\s*=\s*'
    $AssignmentMatches = [regex]::Matches($StagingHtml, $AssignmentPattern)
    if ($AssignmentMatches.Count -ne 1) {
        throw "Expected one PSWriteHTML data assignment for '$DataStoreID', found $($AssignmentMatches.Count)."
    }

    $DataStartIndex = $AssignmentMatches[0].Index + $AssignmentMatches[0].Length
    while ($DataStartIndex -lt $StagingHtml.Length -and [char]::IsWhiteSpace($StagingHtml[$DataStartIndex])) {
        $DataStartIndex++
    }
    if ($DataStartIndex -ge $StagingHtml.Length -or $StagingHtml[$DataStartIndex] -ne '[') {
        throw "The PSWriteHTML data assignment for '$DataStoreID' is not a JavaScript array."
    }

    $ArrayDepth = 0
    $InString = $false
    $Escaped = $false
    $DataEndIndex = -1
    for ($Index = $DataStartIndex; $Index -lt $StagingHtml.Length; $Index++) {
        $Character = $StagingHtml[$Index]
        if ($InString) {
            if ($Escaped) {
                $Escaped = $false
            } elseif ($Character -eq '\') {
                $Escaped = $true
            } elseif ($Character -eq '"') {
                $InString = $false
            }
            continue
        }

        if ($Character -eq '"') {
            $InString = $true
        } elseif ($Character -eq '[') {
            $ArrayDepth++
        } elseif ($Character -eq ']') {
            $ArrayDepth--
            if ($ArrayDepth -eq 0) {
                $DataEndIndex = $Index
                break
            }
        }
    }
    if ($DataEndIndex -lt 0) {
        throw "The PSWriteHTML data array for '$DataStoreID' is not terminated."
    }

    $TerminatorIndex = $DataEndIndex + 1
    while ($TerminatorIndex -lt $StagingHtml.Length -and [char]::IsWhiteSpace($StagingHtml[$TerminatorIndex])) {
        $TerminatorIndex++
    }
    if ($TerminatorIndex -ge $StagingHtml.Length -or $StagingHtml[$TerminatorIndex] -ne ';') {
        throw "The PSWriteHTML data assignment for '$DataStoreID' has no statement terminator."
    }

    $Marker = '__CLEANUPMONSTER_AD_REPORT_DATA_' + [guid]::NewGuid().ToString('N') + '__'
    $HtmlWithMarker = $StagingHtml.Substring(0, $DataStartIndex) + $Marker + $StagingHtml.Substring($DataEndIndex + 1)
    $MarkerIndex = $DataStartIndex

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
