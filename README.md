# SecDevOps Windows Workstation

A comprehensive, modular security hardening and tool installation suite for Windows 11 Enterprise systems. Designed for experienced sysadmins deploying secure development and security operations environments.

## Features

- **Modular scripts** — install individual components independently
- **CLI tool** — intuitive command-line interface (Phase 1)
- **Phase 2** — JSON manifest-driven config, terminal GUI/dashboard
- **No package manager restrictions** — winget, direct GitHub downloads, PowerShell Gallery only
- **Idempotent** — safe to run multiple times

## Quick Start

```powershell
# Run the CLI tool
.\secdevops.ps1 --help

# Install a specific component
.\secdevops.ps1 install os-hardening

# Install multiple components
.\secdevops.ps1 install os-hardening network-tools development
```

## Project Structure

```
secdevops-workstn-win/
├── secdevops.ps1              # Main CLI entry point
├── scripts/                   # Standalone installation scripts
│   ├── Install-OSHardening.ps1
│   ├── Install-NetworkTools.ps1
│   ├── Install-DevTools.ps1
│   ├── Install-SecurityTools.ps1
│   └── ...
├── modules/                   # Reusable PowerShell modules
│   ├── SecDevOps.Core.psm1    # Common utilities
│   └── ...
├── docs/                      # Documentation
│   └── COMPONENTS.md
└── README.md
```

## Components (Phase 1)

### OS Hardening
- Windows Defender hardening
- Windows Firewall configuration
- UAC enforcement
- BitLocker/encryption
- SMB hardening
- PowerShell constrained language mode (optional)

### Network Tools
- Wireshark
- Nmap
- netcat (ncat)
- tcpdump
- curl/wget

### Development Tools
- Git (winget)
- Node.js (winget)
- Python (winget)
- PowerShell 7+ (winget)
- VS Code (winget)
- Docker Desktop (winget)

### Security Tools
- Burp Suite Community (direct GitHub)
- OWASP ZAP (direct GitHub)
- Metasploit (PowerShell Gallery or direct)
- Mimikatz (direct GitHub, compliance check)
- Sysinternals Suite (winget)

### Monitoring & Logging
- Splunk Forwarder (winget)
- ELK Stack agents (direct)
- Sysmon (direct GitHub)
- Windows Event Forwarding setup

## Prerequisites

- Windows 11 Enterprise (or compatible)
- Administrator privileges
- PowerShell 5.1+ (PowerShell 7+ recommended)
- Internet connectivity

## Usage Examples

```powershell
# List available components
.\secdevops.ps1 list

# Install with validation
.\secdevops.ps1 install os-hardening --validate

# Dry-run mode (no changes)
.\secdevops.ps1 install network-tools --dry-run

# Install all
.\secdevops.ps1 install all

# Check installation status
.\secdevops.ps1 status
```

## Phase 2 Roadmap

- JSON manifest-driven installation profiles
- Terminal GUI/dashboard for system status
- Rollback capabilities
- Audit logging and compliance reporting

## Contributing

Follow PowerShell best practices and verb-noun naming conventions. See [COMPONENTS.md](docs/COMPONENTS.md) for details.

## License

Internal use only.
# SecDevOps-Workstation-Win
