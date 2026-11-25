# Contributing to One Click BIOS

[`one-click-bios.ps1`](one-click-bios.ps1) handles the Windows Start menu integration. The [README](README.md) lists the shortcuts and files the script creates.

## Review a change

- Validate PowerShell syntax. Use a Windows test environment to verify install, reinstall, and uninstall behavior.
- Inspect the created shortcut properties and verify cleanup before exercising the firmware restart action. Use a disposable system for any restart test.
- Cover path handling, declined elevation, and systems where the firmware action is unavailable when those paths are affected.

Include the Windows build, PowerShell version, and which install or uninstall behavior you verified. State whether you inspected the shortcut or tested a full firmware restart.
