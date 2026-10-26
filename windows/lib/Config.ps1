#Requires -Version 5.1
<#
.SYNOPSIS
Configuration loading for the Windows IceWarp Health Agent.
#>

function Get-AgentConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [string]$ConfigPath
    )

    $defaults = @{
        IceWarpHome        = 'C:\Program Files\IceWarp'
        ToolPath           = 'C:\Program Files\IceWarp\tool.exe'
        ToolTimeoutSeconds = 10
        OutputJson         = 'output\health.json'
        LogDirectory       = 'logs'
        CompanyName        = ''
        Technician         = 'Parsavan'
        ChecklistVersion   = '1.14'
        MailHostname       = ''
        MailDomain         = ''
    }

    $examplePath = Join-Path $Root 'config\agent.example.psd1'
    $localPath = Join-Path $Root 'config\agent.local.psd1'
    $candidate = ''

    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $candidate = Resolve-AgentPath -Path $ConfigPath -Root $Root
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Configuration file not found: $candidate"
        }
    } elseif (Test-Path -LiteralPath $localPath -PathType Leaf) {
        $candidate = $localPath
    } elseif (Test-Path -LiteralPath $examplePath -PathType Leaf) {
        $candidate = $examplePath
    } else {
        throw 'No Windows agent configuration found. Copy config\agent.example.psd1 to config\agent.local.psd1.'
    }

    $loaded = Import-PowerShellDataFile -LiteralPath $candidate -ErrorAction Stop
    $config = @{}

    foreach ($key in $defaults.Keys) {
        $config[$key] = $defaults[$key]
    }
    foreach ($key in $loaded.Keys) {
        $config[$key] = $loaded[$key]
    }

    $timeout = 0
    if (-not [int]::TryParse([string]$config.ToolTimeoutSeconds, [ref]$timeout) -or $timeout -lt 1) {
        throw 'ToolTimeoutSeconds must be a positive integer.'
    }
    $config.ToolTimeoutSeconds = $timeout

    foreach ($key in @('IceWarpHome', 'ToolPath', 'OutputJson', 'LogDirectory')) {
        if ([string]::IsNullOrWhiteSpace([string]$config[$key])) {
            throw "Configuration value '$key' must not be empty."
        }
        $config[$key] = Resolve-AgentPath -Path ([string]$config[$key]) -Root $Root
    }

    $config['ConfigPath'] = $candidate
    $config['ConfigUsedExample'] = [string]::Equals($candidate, $examplePath, [System.StringComparison]::OrdinalIgnoreCase)

    return $config
}
