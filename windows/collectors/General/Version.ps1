#Requires -Version 5.1
<#
.SYNOPSIS
Collect the IceWarp version and basic Windows host information.

.DESCRIPTION
This is the first Windows collector and the reference for the collector
contract:

  * The file declares a mandatory -Context parameter.
  * It returns exactly one IDictionary (an ordered dictionary is preferred).
  * It must not write strings or other objects to the output pipeline.
  * External calls go through the shared IceWarp tool wrapper.
#>

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
)

$iceWarpVersion = Get-IceWarpSetting -Name 'C_Version' -Context $Context
$iceWarpNiceVersion = Get-IceWarpSetting -Name 'C_NiceVersion' -Context $Context
$toolAvailable = Test-IceWarpTool -ToolPath $Context.Config.ToolPath

$data = [ordered]@{
    'icewarp.version'        = $iceWarpVersion
    'icewarp.version.nice'   = $iceWarpNiceVersion
    'icewarp.tool.path'      = [string]$Context.Config.ToolPath
    'icewarp.tool.available' = [bool]$toolAvailable
    'agent.powershell.version' = $PSVersionTable.PSVersion.ToString()
}

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $data['os.caption'] = [string]$os.Caption
    $data['os.version'] = [string]$os.Version
    $data['os.build'] = [string]$os.BuildNumber
    $data['os.architecture'] = [string]$os.OSArchitecture
} catch {
    Write-AgentLog -Level WARN -Message ('Could not read Windows operating-system details: {0}' -f $_.Exception.Message)
}

if ($toolAvailable -and $iceWarpVersion) {
    $data['collector.general.version'] = 'ok'
} elseif ($toolAvailable) {
    $data['collector.general.version'] = 'unknown'
} else {
    $data['collector.general.version'] = 'tool_unavailable'
}

return $data
