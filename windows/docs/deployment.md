# Windows Deployment

This guide covers the 0.1.0 Windows scaffold. The agent is a console
PowerShell script; it is not installed as a Windows service yet.

## Prerequisites

1. Windows PowerShell 5.1 is available as `powershell.exe`.
2. The IceWarp installation includes `tool.exe`.
3. The account that runs the agent can read the IceWarp installation and write
   to the configured output and log directories.
4. The `windows/` directory is on the server, either from a Git checkout or a
   copied release directory.

## Prepare the Configuration

From the `windows/` directory:

```powershell
Copy-Item .\config\agent.example.psd1 .\config\agent.local.psd1
notepad .\config\agent.local.psd1
```

Set at least:

```powershell
@{
    IceWarpHome        = 'C:\Program Files\IceWarp'
    ToolPath           = 'C:\Program Files\IceWarp\tool.exe'
    ToolTimeoutSeconds = 10
    OutputJson         = 'output\health.json'
    LogDirectory       = 'logs'
    CompanyName        = 'Contoso'
    Technician         = 'Operations'
    ChecklistVersion   = '1.14'
}
```

Use an absolute `OutputJson` and `LogDirectory` when the agent is started by
Task Scheduler, so the paths are unambiguous.

## First Manual Run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\agent.ps1 -Report
```

Expected result:

- Console output includes `General/Version`.
- `output\health.json` is created and parses as JSON.
- `logs\agent.log` records the run.

Check the JSON explicitly:

```powershell
Get-Content .\output\health.json -Raw | ConvertFrom-Json
```

If the collector reports `tool_unavailable`, fix `ToolPath` before scheduling
the task.

## Task Scheduler

The following example creates a daily task that runs as `SYSTEM`. Adjust the
path and time for the site. Use a dedicated service account if IceWarp policy
requires it.

```powershell
$agentRoot = 'C:\icewarp-health-agent\windows'
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}\agent.ps1" -Report' -f $agentRoot) `
    -WorkingDirectory $agentRoot

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

Register-ScheduledTask `
    -TaskName 'IceWarp Health Agent (Windows)' `
    -Action $action `
    -Trigger $trigger `
    -Description 'Collect IceWarp health data and write flat JSON.' `
    -User 'SYSTEM' `
    -RunLevel Highest
```

Verify the task:

```powershell
Get-ScheduledTask -TaskName 'IceWarp Health Agent (Windows)'
Start-ScheduledTask -TaskName 'IceWarp Health Agent (Windows)'
Get-ScheduledTaskInfo -TaskName 'IceWarp Health Agent (Windows)'
```

To remove it:

```powershell
Unregister-ScheduledTask -TaskName 'IceWarp Health Agent (Windows)' -Confirm
```

## Execution Policy

The examples use `-ExecutionPolicy Bypass` for the process only. If your
security policy disallows that, sign the scripts and use an appropriate
machine or user policy instead. Do not weaken the machine-wide policy just for
this agent.

## Files and Permissions

| Path | Permission |
|---|---|
| `windows\agent.ps1`, `lib\`, `collectors\` | Read for the task account |
| `windows\config\agent.local.psd1` | Read for the task account; restrict write access |
| `windows\output\` | Modify for the task account |
| `windows\logs\` | Modify for the task account |

`agent.local.psd1` contains site settings, but no credentials are required by
the 0.1.0 scaffold. Do not add credentials to a tracked file. If future
collectors need secrets, use Windows Credential Manager or a protected
configuration mechanism instead.

## Log Rotation

`agent.log` rotates to `agent.log.1` when it reaches 5 MB. Only one previous
file is kept. If the task runs frequently and the log grows quickly, add a
separate retention task or lower the run frequency.

## Updates

Automatic updates are not implemented for Windows in 0.1.0. For a Git
checkout, update manually during a maintenance window:

```powershell
git pull --ff-only origin main
```

The Linux auto-updater is independent and must not be invoked from Windows.
Windows releases will use `windows-v*` tags.

## Troubleshooting

| Symptom | Check |
|---|---|
| `tool_unavailable` in JSON | `ToolPath` points to the real `tool.exe`; the task account can read it |
| `collector.general.version = unknown` | `C_Version` was empty or unparsable; run `tool.exe display system C_Version` manually |
| `UnauthorizedAccessException` | Output or log directory permissions for the task account |
| Script will not run | Execution policy or file blocking; use `-ExecutionPolicy Bypass` for the process or sign the files |
| Tests cannot load Pester | Install Pester 3.4+ with `Install-Module Pester -Scope CurrentUser` |
| JSON has unexpected values | Check `logs\agent.log` for collector warnings; tool errors are logged without setting values |
