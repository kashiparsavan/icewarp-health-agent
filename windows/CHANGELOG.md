# Changelog - IceWarp Health Agent for Windows

All notable changes to the Windows implementation are documented here.
The Linux agent keeps its own changelog in the repository root.

## [0.1.0] - 2026-10-26

### Added

- Independent PowerShell 5.1 entry point at `agent.ps1`.
- PSD1 configuration with a tracked `config/agent.example.psd1` and ignored
  `config/agent.local.psd1`.
- Shared modules for configuration, logging, collector execution, IceWarp
  `tool.exe` calls with timeouts, and flat JSON output.
- Sample `General/Version` collector for the IceWarp version and basic Windows
  host details.
- Flat JSON output preserves booleans and numbers and converts empty string
  values to `null`, matching the Linux JSON contract.
- Pester smoke tests compatible with Pester 3.4 and later, plus a version-aware
  test runner.
- Windows setup, deployment, and troubleshooting documentation.

### Notes

- This is a scaffold, not feature parity with the Linux agent. The full
  checklist, health rules, PDF reports, DNS collectors, and automatic updates
  are not implemented yet.
- The Windows tree does not call `agent.sh` or source anything from the Linux
  `lib/` directory.
- Windows versions and tags are independent of Linux (`windows/VERSION`,
  `windows-v*` tags).
