#Requires -Version 5.1
<#
.SYNOPSIS
File and console logging for the Windows IceWarp Health Agent.
#>

# Collector scripts run in a child scope, so logging state must be reachable
# from functions called there. A uniquely named global avoids StrictMode
# failures on child-scope $script: variables.
$global:IceWarpHealthAgentLogPath = $null
$global:IceWarpHealthAgentLogMaxBytes = 5242880

function Initialize-AgentLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogDirectory,
        [string]$LogFileName = 'agent.log',
        [int]$MaxBytes = 5242880
    )

    if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
        throw 'LogDirectory must not be empty.'
    }

    if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $global:IceWarpHealthAgentLogPath = Join-Path $LogDirectory $LogFileName
    $global:IceWarpHealthAgentLogMaxBytes = $MaxBytes

    if ((Test-Path -LiteralPath $global:IceWarpHealthAgentLogPath -PathType Leaf) -and
        (Get-Item -LiteralPath $global:IceWarpHealthAgentLogPath).Length -ge $MaxBytes) {
        Move-Item -LiteralPath $global:IceWarpHealthAgentLogPath -Destination ($global:IceWarpHealthAgentLogPath + '.1') -Force
    }

    Write-AgentLog -Level INFO -Message ('Windows agent started (PowerShell {0}).' -f $PSVersionTable.PSVersion.ToString())
}

function Write-AgentLog {
    [CmdletBinding()]
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message

    if ($global:IceWarpHealthAgentLogPath) {
        try {
            $encoding = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::AppendAllText($global:IceWarpHealthAgentLogPath, $line + [Environment]::NewLine, $encoding)
        } catch {
            Write-Warning ('Could not write agent log: {0}' -f $_.Exception.Message)
        }
    }

    switch ($Level) {
        'ERROR' {
            Write-Host $line -ForegroundColor Red
        }
        'WARN' {
            Write-Host $line -ForegroundColor Yellow
        }
        'INFO' {
            Write-Host $line
        }
        'DEBUG' {
            Write-Verbose $line
        }
    }
}
