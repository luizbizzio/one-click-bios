# Security Policy

## Supported Versions

This project is small and maintained on a best-effort basis.

Security fixes are generally applied to:

- `main` branch
- Latest release (if a release exists)

Older versions may not receive fixes.

## Reporting a Vulnerability

If you believe you found a security issue, please report it privately first.

### Please do
- Describe the issue clearly
- Include reproduction steps
- Include Windows version and PowerShell version
- Explain the impact (what could go wrong)
- Share screenshots or logs if useful

### Please do not
- Open a public issue with exploit details before disclosure
- Post proof-of-concept code publicly before a fix is available

You can report issues through:
- GitHub Security Advisory (preferred, if enabled)
- Private message through GitHub profile / contact method listed on profile

## What Counts as a Security Issue

Examples of issues that may be considered security-related:

- Command injection or unsafe command execution
- Path manipulation that allows writing shortcuts outside expected locations
- Script behavior that can be abused to run unintended commands
- Unsafe handling of user input that changes the command executed by the shortcut
- Supply chain concerns in installation instructions (for example, unsafe remote execution patterns)

## Out of Scope / Not a Security Bug

The following are usually not considered security vulnerabilities for this project:

- Systems that do not support `shutdown /r /fw` (compatibility limitation)
- Legacy BIOS systems that cannot boot to firmware settings through Windows
- Missing admin privileges when the system requires elevation for restart actions
- Visual issues such as icon not rendering correctly
- User accidentally clicking the shortcut (unless the script claims to provide confirmation and fails to do so)

## Security Notes for Users

This project creates a Windows shortcut that triggers a system restart to BIOS/UEFI firmware settings.

### Important
- The shortcut can restart your PC immediately
- Save your work before using it
- Use the confirmation version if you want an extra safety step

### One-liner install warning
The one-liner installation method downloads and executes a remote PowerShell script.

Only use it if you trust:
- The repository owner
- The repository URL
- The script contents

If you want a safer workflow, review the script before running it.

## Disclosure Process

After receiving a valid report, fixes are handled on a best-effort basis.

Typical process:
1. Confirm the issue
2. Prepare a fix
3. Publish the patch
4. Disclose the issue publicly (if applicable)

## No Warranty

This project is provided as-is, without warranty. See the repository license for details.
