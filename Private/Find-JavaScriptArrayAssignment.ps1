function Find-JavaScriptArrayAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Html,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z_$][A-Za-z0-9_$]*$')]
        [string] $VariableName
    )

    $AssignmentPattern = '\bvar\s+' + [regex]::Escape($VariableName) + '\s*=\s*'
    $ScriptPattern = '(?is)<script\b[^>]*>(?<Content>.*?)</script\s*>'

    foreach ($ScriptMatch in [regex]::Matches($Html, $ScriptPattern)) {
        $ContentGroup = $ScriptMatch.Groups['Content']
        $Content = $ContentGroup.Value

        foreach ($AssignmentMatch in [regex]::Matches($Content, $AssignmentPattern)) {
            $State = 'Code'
            $Escaped = $false
            for ($Index = 0; $Index -lt $AssignmentMatch.Index; $Index++) {
                $Character = $Content[$Index]
                $NextCharacter = if ($Index + 1 -lt $Content.Length) { $Content[$Index + 1] } else { [char] 0 }

                if ($State -eq 'LineComment') {
                    if ($Character -eq "`r" -or $Character -eq "`n") {
                        $State = 'Code'
                    }
                    continue
                }
                if ($State -eq 'BlockComment') {
                    if ($Character -eq '*' -and $NextCharacter -eq '/') {
                        $State = 'Code'
                        $Index++
                    }
                    continue
                }
                if ($State -ne 'Code') {
                    if ($Escaped) {
                        $Escaped = $false
                    } elseif ($Character -eq '\') {
                        $Escaped = $true
                    } elseif (($State -eq 'SingleQuote' -and $Character -eq "'") -or
                        ($State -eq 'DoubleQuote' -and $Character -eq '"') -or
                        ($State -eq 'Template' -and $Character -eq [char] 96)) {
                        $State = 'Code'
                    }
                    continue
                }

                if ($Character -eq "'") {
                    $State = 'SingleQuote'
                } elseif ($Character -eq '"') {
                    $State = 'DoubleQuote'
                } elseif ($Character -eq [char] 96) {
                    $State = 'Template'
                } elseif ($Character -eq '/' -and $NextCharacter -eq '/') {
                    $State = 'LineComment'
                    $Index++
                } elseif ($Character -eq '/' -and $NextCharacter -eq '*') {
                    $State = 'BlockComment'
                    $Index++
                }
            }

            if ($State -ne 'Code') {
                continue
            }

            $DataStartIndex = $AssignmentMatch.Index + $AssignmentMatch.Length
            while ($DataStartIndex -lt $Content.Length -and [char]::IsWhiteSpace($Content[$DataStartIndex])) {
                $DataStartIndex++
            }
            if ($DataStartIndex -ge $Content.Length -or $Content[$DataStartIndex] -ne '[') {
                continue
            }

            $ArrayDepth = 0
            $InString = $false
            $Escaped = $false
            $DataEndIndex = -1
            for ($Index = $DataStartIndex; $Index -lt $Content.Length; $Index++) {
                $Character = $Content[$Index]
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
                continue
            }

            $TerminatorIndex = $DataEndIndex + 1
            while ($TerminatorIndex -lt $Content.Length -and [char]::IsWhiteSpace($Content[$TerminatorIndex])) {
                $TerminatorIndex++
            }
            if ($TerminatorIndex -ge $Content.Length -or $Content[$TerminatorIndex] -ne ';') {
                continue
            }

            return [PSCustomObject] @{
                DataStartIndex = $ContentGroup.Index + $DataStartIndex
                DataEndIndex   = $ContentGroup.Index + $DataEndIndex
            }
        }
    }

    throw "The JavaScript array assignment for '$VariableName' was not found."
}
