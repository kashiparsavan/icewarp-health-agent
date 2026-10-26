#Requires -Version 5.1

Describe 'Windows agent scaffold' {
    BeforeAll {
        $script:testDirectory = Split-Path -Parent $PSCommandPath
        $script:agentRoot = Split-Path -Parent $script:testDirectory
        $libRoot = Join-Path $script:agentRoot 'lib'

        . (Join-Path $libRoot 'Common.ps1')
        . (Join-Path $libRoot 'Logging.ps1')
        . (Join-Path $libRoot 'Config.ps1')
        . (Join-Path $libRoot 'IceWarpTool.ps1')
        . (Join-Path $libRoot 'Json.ps1')

        function Assert-Equal {
            param(
                $Expected,
                $Actual,
                [string]$Because = ''
            )

            if ($null -eq $Expected -and $null -eq $Actual) {
                return
            }
            if ($Expected -ne $Actual) {
                throw ("Expected '{0}' but got '{1}'. {2}" -f $Expected, $Actual, $Because).Trim()
            }
        }

        function Assert-True {
            param(
                [bool]$Condition,
                [string]$Because = 'Assertion failed.'
            )

            if (-not $Condition) {
                throw $Because
            }
        }
    }

    BeforeEach {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('icewarp-agent-test-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        Initialize-AgentLogging -LogDirectory (Join-Path $script:tempRoot 'logs') | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:tempRoot) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reads the Windows agent version from VERSION' {
        Assert-Equal -Expected '0.1.0' -Actual (Get-AgentVersion -Root $script:agentRoot)
    }

    It 'loads the example PSD1 configuration' {
        $configPath = Join-Path $script:agentRoot 'config\agent.example.psd1'
        $config = Get-AgentConfig -Root $script:agentRoot -ConfigPath $configPath

        Assert-Equal -Expected 10 -Actual $config.ToolTimeoutSeconds
        Assert-Equal -Expected '1.14' -Actual $config.ChecklistVersion
        Assert-Equal -Expected $true -Actual $config.ConfigUsedExample
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$config.ToolPath)) -Because 'ToolPath should not be empty.'
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$config.OutputJson)) -Because 'OutputJson should not be empty.'
    }

    It 'parses key/value and plain tool output' {
        $keyValue = "C_Version: 14.3.0.12`r`nC_NiceVersion: IceWarp 14.3`r`n"
        Assert-Equal -Expected '14.3.0.12' -Actual (ConvertFrom-IceWarpToolOutput -Output $keyValue)
        Assert-Equal -Expected 'plain value' -Actual (ConvertFrom-IceWarpToolOutput -Output 'plain value')
        Assert-Equal -Expected '' -Actual (ConvertFrom-IceWarpToolOutput -Output '')
    }

    It 'writes valid JSON without changing scalar types' {
        $path = Join-Path $script:tempRoot 'health.json'
        $data = [ordered]@{
            'agent.version' = '0.1.0'
            'number'        = 5
            'enabled'       = $true
            'missing'       = $null
            'empty'         = ''
        }

        Write-AgentJson -Path $path -Data $data

        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        Assert-Equal -Expected '0.1.0' -Actual $json.'agent.version'
        Assert-Equal -Expected 5 -Actual $json.number
        Assert-Equal -Expected $true -Actual $json.enabled
        Assert-True -Condition ($null -eq $json.missing) -Because 'JSON null should remain null.'
        Assert-True -Condition ($null -eq $json.empty) -Because 'Empty strings should become null, matching the Linux JSON contract.'
    }

    It 'invokes a collector and merges its dictionary into agent data' {
        $collectorPath = Join-Path $script:tempRoot 'sample.ps1'
        @'
param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
)

return [ordered]@{ 'sample.value' = 'ok' }
'@ | Set-Content -LiteralPath $collectorPath -Encoding ASCII

        $config = Get-AgentConfig -Root $script:agentRoot
        $context = Initialize-AgentContext -Root $script:agentRoot -Config $config -Version '0.1.0'
        $result = Invoke-AgentCollector -Path $collectorPath -Root $script:agentRoot -Context $context

        Assert-Equal -Expected 'ok' -Actual $result.Status
        Assert-Equal -Expected 'ok' -Actual $context.Data['sample.value']
    }

    It 'records a collector error without stopping the run' {
        $collectorPath = Join-Path $script:tempRoot 'broken.ps1'
        @'
param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
)

throw 'intentional test failure'
'@ | Set-Content -LiteralPath $collectorPath -Encoding ASCII

        $config = Get-AgentConfig -Root $script:agentRoot
        $context = Initialize-AgentContext -Root $script:agentRoot -Config $config -Version '0.1.0'
        $result = Invoke-AgentCollector -Path $collectorPath -Root $script:agentRoot -Context $context

        Assert-Equal -Expected 'error' -Actual $result.Status
        Assert-True -Condition ($result.Message -match 'intentional test failure') -Because 'Collector error message was not preserved.'
    }

    It 'finds the bundled Version collector' {
        $collectors = @(Get-CollectorFiles -Root $script:agentRoot)
        $names = @($collectors | ForEach-Object { Get-CollectorName -Root $script:agentRoot -Path $_.FullName })

        Assert-True -Condition ($collectors.Count -gt 0) -Because 'No collectors were found.'
        Assert-True -Condition ($names -contains 'General/Version') -Because 'General/Version was not listed.'
    }

    It 'filters collector names case-insensitively' {
        Assert-Equal -Expected $true -Actual (Test-CollectorFilter -Name 'General/Version' -Filter 'general')
        Assert-Equal -Expected $true -Actual (Test-CollectorFilter -Name 'General/Version' -Filter 'dns,version')
        Assert-Equal -Expected $false -Actual (Test-CollectorFilter -Name 'General/Version' -Filter 'dns')
        Assert-Equal -Expected $true -Actual (Test-CollectorFilter -Name 'General/Version' -Filter '')
    }
}
