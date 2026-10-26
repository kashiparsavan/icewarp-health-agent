# IceWarp Health Agent for Windows

This directory contains an independent Windows implementation of the IceWarp
Health Agent. It is written for **Windows PowerShell 5.1** and does not use
Bash, `agent.sh`, or any file under the Linux `lib/` directory.

Current status: **0.1.0 scaffold**. The scaffolding, configuration, logging,
`tool.exe` wrapper, flat JSON output, one sample collector, and Pester smoke
tests are working. The full 113-item checklist, health rules, PDF reports, DNS
collectors, and automatic updates are not ported yet.

## Requirements

- Windows Server 2012 R2 or later, or Windows 10/11.
- Windows PowerShell 5.1 (the default on supported Windows versions).
- An IceWarp installation with `tool.exe` for live data collection.
- Pester 3.4 or later for the test suite. Pester 3.4 is bundled with many
  Windows Server installations; Pester 5 is also supported by the test runner.

PowerShell 7 can run the scaffold, but the supported target is Windows
PowerShell 5.1. Avoid PowerShell 7-only syntax in this directory.

## Quick Start

Run these commands from the `windows/` directory in a PowerShell console:

```powershell
Copy-Item .\config\agent.example.psd1 .\config\agent.local.psd1
notepad .\config\agent.local.psd1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\agent.ps1 -Report
```

If IceWarp is not installed, the sample collector reports
`collector.general.version = tool_unavailable`, but the agent still writes
valid JSON. Set `ToolPath` and `IceWarpHome` in `agent.local.psd1` for the real
server.

## Command Line

| Option | Description |
|---|---|
| `-Report` | Run collectors and print a console summary |
| `-List` | List available collectors and exit |
| `-Only <filter>` | Run only collectors whose relative path contains the filter (comma-separated, case-insensitive) |
| `-Company <name>` | Override `CompanyName` from the configuration |
| `-Technician <name>` | Override `Technician` from the configuration |
| `-ConfigPath <path>` | Use an alternate PSD1 configuration file |
| `-Help` | Show usage |

Examples:

```powershell
.\agent.ps1
.\agent.ps1 -Report
.\agent.ps1 -List
.\agent.ps1 -Only General -Report
.\agent.ps1 -Report -Company "Contoso" -Technician "Alex"
```

## Configuration

The agent loads `config\agent.local.psd1` when it exists. Otherwise it falls
back to the tracked `config\agent.example.psd1` and logs a warning. Create the
local file for each server:

```powershell
Copy-Item .\config\agent.example.psd1 .\config\agent.local.psd1
```

`agent.local.psd1` is ignored by Git. The file is read with
`Import-PowerShellDataFile`, so it is data-only and cannot execute code.
Relative paths are resolved against the `windows/` directory.

| Key | Default | Purpose |
|---|---|---|
| `IceWarpHome` | `C:\Program Files\IceWarp` | IceWarp installation directory |
| `ToolPath` | `C:\Program Files\IceWarp\tool.exe` | IceWarp command-line tool |
| `ToolTimeoutSeconds` | `10` | Per-call timeout for `tool.exe` |
| `OutputJson` | `output\health.json` | Flat JSON output path |
| `LogDirectory` | `logs` | Runtime log directory |
| `CompanyName` | empty | Company name for reports |
| `Technician` | `Parsavan` | Technician name for reports |
| `ChecklistVersion` | `1.14` | Report metadata label |
| `MailHostname` | empty | Reserved for future DNS collectors |
| `MailDomain` | empty | Reserved for future DNS/DMARC collectors |

Do not copy the Linux `config/*.conf` files into this directory. The Windows
agent intentionally has a separate, PSD1-only configuration.

## Output

The current scaffold writes one output file and one runtime log:

| Path | Description |
|---|---|
| `output\health.json` | Flat, dotted-key JSON; scalar types are preserved |
| `logs\agent.log` | Timestamped INFO/WARN/ERROR/DEBUG log, rotated to `agent.log.1` at 5 MB |

Example JSON:

```json
{
    "agent.version": "0.1.0",
    "agent.platform": "windows",
    "icewarp.version": "14.3.0.12",
    "icewarp.tool.available": true,
    "collector.general.version": "ok"
}
```

The JSON is UTF-8 without a BOM. Empty string values are emitted as `null`,
matching the Linux JSON contract; booleans and numbers remain native JSON
types. PDF generation is not implemented on Windows yet; this scaffold is
focused on a stable data path first.

## Collector Contract

Collectors live under `collectors\<Area>\<Name>.ps1` and follow this contract:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Context
)

$value = Get-IceWarpSetting -Name 'C_Version' -Context $Context

return [ordered]@{
    'icewarp.version' = $value
}
```

Rules:

- Return exactly one `IDictionary` (preferably an ordered dictionary).
- Do not write strings or other objects to the output pipeline.
- Use namespaced dotted keys, matching the Linux data contract where possible.
- Use `Get-IceWarpSetting` or `Invoke-IceWarpTool` for `tool.exe` calls; both
  apply the configured timeout.
- The agent isolates collector failures, records `error` or `empty` status, and
  continues with the remaining collectors.
- `$Context` exposes `Config`, `Data`, `Root`, and `Version`. Modules may add
  data with `Set-AgentData`.

The only collector in 0.1.0 is `collectors\General\Version.ps1`, which reads
`C_Version` and `C_NiceVersion` and adds basic operating-system fields.

## API Reference

The authoritative Windows-side API reference is
`tool.v14.3.0.13.windows.help`, which is the IceWarp 14.3.0.13
`APIConst.pas` from the Windows server. It is **not** the same file as the
Linux reference.

| File | Platform | SHA-256 |
|---|---|---|
| `tool.v14.3.0.13.help` | Linux | `51EE702640A3B08CC0AF77805E3D54E143709E91DCEEF190BF880DEF11287E5D` |
| `tool.v14.3.0.13.windows.help` | Windows | `5102C041514887DEC81A428B05EB9D6D930EA38B3F423B350EE790EDA31D9D36` |

Key-level comparison:

- All Linux keys are present on Windows.
- Windows adds 4 keys: `C_API_DomainList_DefaultLimit`, `U_MailingLists`,
  `U_MailingListsList`, and `U_SlaveDomain`.
- `U_GROUPS` / `U_GROUPSLIST` are spelled `U_Groups` / `U_GroupsList` on
  Windows; the IDs and descriptions are the same.
- `U_MasterDomain` is `String [R]` on Windows and `String` on Linux. Read
  only on Windows.
- `C_OS` is `0` for Windows and `1` for Linux on both platforms.
- `C_Accounts_Policies_Auth_Schemes` is present; the incorrect
  `C_Mail_Security_AuthScheme` is absent.

Use the Windows reference when writing or reviewing Windows collectors. Keep
both files; do not treat the Linux reference as authoritative for Windows.
See `docs/api-windows-vs-linux-v14.3.0.13.md` for the full comparison.

**Important:** the API reference defines key names and IDs. It is not a
substitute for validating `tool.exe` output formatting, value semantics,
service names, and Windows-only behavior on the lab server. A Windows
`tool.exe` search/list export is still needed to confirm the property
listing.

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

The runner detects Pester 3.x or 5.x. The suite checks version loading, PSD1
configuration, tool-output parsing, JSON types, collector success/failure
isolation, collector discovery, and `-Only` filtering. It does not require a
live IceWarp server.

## Deployment

See [`docs/deployment.md`](docs/deployment.md) for a Task Scheduler example,
service-account guidance, log handling, and troubleshooting.

## Independence and Versioning

- Windows files are additive under `windows/`; Linux paths at the repository
  root are unchanged.
- `windows/VERSION` is independent of the root Linux `VERSION`.
- Use Windows tags such as `windows-v0.1.0`; Linux releases continue to use
  `v*`.
- The Linux auto-updater follows `origin/main`. It does not run the Windows
  agent, and the Windows scaffold does not call the Linux updater.
- Automatic updates for Windows are not implemented in 0.1.0.

For repository-wide context, see the root [`README.md`](../README.md) and
[`CLAUDE.md`](../CLAUDE.md).
