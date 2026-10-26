#Requires -Version 5.1
<#
.SYNOPSIS
Flat, type-aware JSON output for the Windows IceWarp Health Agent.
#>

function Write-AgentJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Data
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and
        -not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $serializable = [ordered]@{}
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($value -is [string] -and $value.Length -eq 0) {
            $serializable[$key] = $null
        } else {
            $serializable[$key] = $value
        }
    }

    $json = ConvertTo-Json -InputObject $serializable -Depth 10
    if ($null -eq $json) {
        $json = '{}'
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
    Write-AgentLog -Level INFO -Message ('Wrote JSON output: {0}' -f $Path)
}
