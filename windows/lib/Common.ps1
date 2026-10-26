#Requires -Version 5.1
<#
.SYNOPSIS
Shared helpers for the Windows IceWarp Health Agent.
#>

function Get-AgentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $versionPath = Join-Path $Root 'VERSION'
    if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
        $version = (Get-Content -LiteralPath $versionPath -Raw -ErrorAction Stop).Trim()
        if ($version) {
            return $version
        }
    }

    return 'unknown'
}

function Resolve-AgentPath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Initialize-AgentContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $hostName = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($hostName)) {
        try {
            $hostName = [System.Net.Dns]::GetHostName()
        } catch {
            $hostName = 'unknown'
        }
    }

    $data = [ordered]@{}
    $data['agent.version'] = $Version
    $data['agent.hostname'] = $hostName
    $data['agent.time'] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $data['agent.platform'] = 'windows'
    $data['checklist.version'] = [string]$Config.ChecklistVersion
    $data['agent.config.path'] = [string]$Config.ConfigPath
    $data['agent.config.example_used'] = [bool]$Config.ConfigUsedExample

    if (-not [string]::IsNullOrWhiteSpace([string]$Config.Technician)) {
        $data['general.technician'] = [string]$Config.Technician
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Config.CompanyName)) {
        $data['general.company'] = [string]$Config.CompanyName
    }

    return @{
        Root        = $Root
        ProjectRoot = Split-Path -Parent $Root
        Config      = $Config
        Data        = $data
        Version     = $Version
    }
}

function Set-AgentData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [AllowNull()]
        $Value
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        throw 'Data keys must not be empty.'
    }

    $Context.Data[$Key] = $Value
}

function Get-CollectorFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $collectorRoot = Join-Path $Root 'collectors'
    if (-not (Test-Path -LiteralPath $collectorRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $collectorRoot -Recurse -File -Filter '*.ps1' |
        Sort-Object -Property FullName)
}

function Get-CollectorName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $collectorRoot = Join-Path $Root 'collectors'
    $relativePath = $Path

    if ($Path.StartsWith($collectorRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $Path.Substring($collectorRoot.Length).TrimStart([char[]]@('\', '/'))
    }

    $relativePath = $relativePath -replace '\.ps1$', ''
    return ($relativePath -replace '\\', '/')
}

function Test-CollectorFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowEmptyString()]
        [string]$Filter
    )

    if ([string]::IsNullOrWhiteSpace($Filter)) {
        return $true
    }

    foreach ($part in $Filter.Split(',')) {
        $candidate = $part.Trim()
        if ($candidate -and $Name.IndexOf($candidate, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }

    return $false
}

function Invoke-AgentCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    $name = Get-CollectorName -Root $Root -Path $Path
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Collector not found: $Path"
        }

        $result = & $Path -Context $Context

        if ($null -eq $result) {
            $stopwatch.Stop()
            return [pscustomobject]@{
                Name       = $name
                Path       = $Path
                Status     = 'empty'
                Message    = 'Collector returned no data.'
                DurationMs = $stopwatch.ElapsedMilliseconds
            }
        }

        if (-not ($result -is [System.Collections.IDictionary])) {
            throw 'Collector must return an IDictionary (hashtable or ordered dictionary).'
        }

        foreach ($key in $result.Keys) {
            $keyText = [string]$key
            if ([string]::IsNullOrWhiteSpace($keyText)) {
                continue
            }
            $Context.Data[$keyText] = $result[$key]
        }

        $stopwatch.Stop()
        Write-AgentLog -Level DEBUG -Message ("Collector {0} completed in {1} ms ({2} keys)." -f $name, $stopwatch.ElapsedMilliseconds, $result.Count)

        return [pscustomobject]@{
            Name       = $name
            Path       = $Path
            Status     = 'ok'
            Message    = ''
            DurationMs = $stopwatch.ElapsedMilliseconds
        }
    } catch {
        $stopwatch.Stop()
        $message = $_.Exception.Message
        Write-AgentLog -Level ERROR -Message ("Collector {0} failed: {1}" -f $name, $message)

        return [pscustomobject]@{
            Name       = $name
            Path       = $Path
            Status     = 'error'
            Message    = $message
            DurationMs = $stopwatch.ElapsedMilliseconds
        }
    }
}

function Show-AgentHelp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    @"
IceWarp Health Agent (Windows) v$Version

Usage:
  .\agent.ps1 [OPTIONS]

Options:
  -Report                 Run collectors and print a console summary
  -List                   List available collectors
  -Only <filter>          Run only collectors whose path contains a filter
                          (comma-separated, case-insensitive)
  -Company <name>         Override company name
  -Technician <name>      Override technician name
  -ConfigPath <path>      Use an alternate PSD1 configuration file
  -Help                   Show this help

Defaults:
  Configuration           config\agent.local.psd1, then config\agent.example.psd1
  JSON output             output\health.json
  Log file                logs\agent.log
"@ | Write-Host
}

function Write-AgentReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$CollectorResults
    )

    Write-Host ''
    Write-Host '========================================'
    Write-Host 'IceWarp Health Check Report (Windows)'
    Write-Host '========================================'
    Write-Host ''

    foreach ($key in ($Context.Data.Keys | Sort-Object)) {
        Write-Host ('{0,-40} : {1}' -f $key, $Context.Data[$key])
    }

    Write-Host ''
    Write-Host ('Total Keys : {0}' -f $Context.Data.Count)

    $failed = @($CollectorResults | Where-Object { $_.Status -ne 'ok' })
    if ($failed.Count -gt 0) {
        Write-Host ''
        Write-Host ('Collector issues ({0}):' -f $failed.Count)
        foreach ($item in ($failed | Sort-Object -Property Name)) {
            Write-Host ('  [{0}] {1,-30} {2}' -f $item.Status, $item.Name, $item.Message)
        }
    }

    Write-Host ''
}
