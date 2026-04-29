# SecDevOps Components Reference

Detailed documentation for each component and tools installed.

## OS Hardening

**Script:** `Install-OSHardening.ps1`

Hardens Windows 11 Enterprise security posture through:
- Windows Defender engine and definition updates
- Real-time protection and scan scheduling
- Windows Firewall inbound/outbound rule enforcement
- UAC elevation requirements
- BitLocker drive encryption setup
- SMB signing/encryption hardening
- PowerShell script execution policy enforcement
- Optional: Constrained Language Mode for legacy PowerShell

## Network Tools

**Script:** `Install-NetworkTools.ps1`

Essential network analysis and debugging tools:
- **Wireshark** — packet capture and analysis (winget)
- **Nmap** — network reconnaissance and scanning (winget)
- **Ncat** — netcat-compatible tool for port scanning/listening (winget)
- **tcpdump** — command-line packet capture (winget)
- **curl/wget** — HTTP/file download utilities (winget)

## Development Tools

**Script:** `Install-DevTools.ps1`

Core development environment:
- **Git** — version control (winget: Git.Git)
- **Node.js** — JavaScript runtime (winget: OpenJS.NodeJS)
- **Python** — interpreted language (winget: Python.Python.3.12)
- **PowerShell 7+** — modern PowerShell (winget: Microsoft.PowerShell)
- **VS Code** — code editor (winget: Microsoft.VisualStudioCode)
- **Docker Desktop** — containerization (winget: Docker.DockerDesktop)

## Security Tools

**Script:** `Install-SecurityTools.ps1`

Offensive and defensive security utilities:
- **Burp Suite Community** — web vulnerability scanner (GitHub release)
- **OWASP ZAP** — dynamic application security testing (GitHub release)
- **Metasploit Framework** — penetration testing (PowerShell Gallery or GitHub)
- **Mimikatz** — credential extraction (GitHub, compliance verification required)
- **Sysinternals Suite** — process and system analysis (winget: Microsoft.Sysinternals.Suite)

## Monitoring & Logging

**Script:** `Install-Monitoring.ps1`

Security event collection and analysis:
- **Splunk Forwarder** — send logs to central SIEM (winget)
- **ELK Stack Agents** — Elastic agent for centralized logging (direct/GitHub)
- **Sysmon** — system activity monitoring (GitHub release from Sysinternals)
- **Windows Event Forwarding** — configure WEF for centralized event collection

## Installation Notes

### Prerequisites
- Windows 11 Enterprise (Windows 10 may work with modifications)
- Administrator privileges required
- 20GB free disk space recommended
- 8GB RAM minimum (16GB recommended)
- Internet connectivity

### Installation Order
Recommended installation sequence (dependencies):
1. OS Hardening (sets security baseline)
2. Development Tools (foundational)
3. Network Tools
4. Security Tools
5. Monitoring (last, after tools are installed)

### Post-Installation
- Restart may be required for OS hardening changes
- Some tools require additional configuration (Splunk, ELK)
- Review Security Tools for compliance requirements in your environment

## Idempotency

All installation scripts are idempotent and safe to run multiple times:
- Skip already-installed components
- Update if newer version available (optional)
- No cleanup of existing configurations

## Troubleshooting

### winget not found
Install Windows Package Manager from Microsoft Store or GitHub.

### Access Denied
Ensure script runs as Administrator.

### Network errors
Verify internet connectivity and firewall rules allow downloads.

### Tool verification fails
Check installation logs and run `secdevops.ps1 status` for diagnostics.
