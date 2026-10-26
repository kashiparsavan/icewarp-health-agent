#Requires -Version 5.1
<#
.SYNOPSIS
Run the Windows agent Pester smoke tests.

.DESCRIPTION
Supports Pester 3.x (Windows PowerShell 5.1 default) and Pester 5.x.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$testDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$testFile = Join-Path $testDirectory 'Agent.Smoke.Tests.ps1'

$pesterModule = Get-Module -ListAvailable -Name Pester |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1

if (-not $pesterModule) {
    throw 'Pester is required. Install it with Install-Module Pester -Scope CurrentUser.'
}

Import-Module $pesterModule.Path -Force

$pesterVersion = (Get-Module -Name Pester).Version
Write-Host ('Using Pester {0}' -f $pesterVersion.ToString())

if ($pesterVersion.Major -ge 5) {
    $result = Invoke-Pester -Path $testFile -PassThru
} else {
    $result = Invoke-Pester -Script $testFile -PassThru
}

Write-Host ('Tests passed: {0}; failed: {1}' -f $result.PassedCount, $result.FailedCount)

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
