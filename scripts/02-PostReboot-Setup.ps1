# =============================================================================
# 02-PostReboot-Setup.ps1
# Run as Administrator after first reboot
# Sets WSL2 as default, installs Ubuntu, configures Docker
# =============================================================================

#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Done { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }

# ── WSL2 ──────────────────────────────────────────────────────────────────
Write-Step "Setting WSL default version to 2..."
wsl --set-default-version 2

Write-Step "Updating WSL kernel..."
wsl --update

Write-Step "Installing Ubuntu 24.04 LTS..."
wsl --install -d Ubuntu-24.04

# ── winget: Core CLI tools ────────────────────────────────────────────────
Write-Step "Installing core tooling via winget..."

$wingetPkgs = @(
    # Shells & terminals
    @{ Id = "Microsoft.WindowsTerminal";   Name = "Windows Terminal" }
    @{ Id = "JanDeDobbeleer.OhMyPosh";     Name = "Oh My Posh" }

    # Package managers / runtimes
    @{ Id = "Chocolatey.Chocolatey";       Name = "Chocolatey" }
    @{ Id = "OpenJS.NodeJS.LTS";           Name = "Node.js LTS" }
    @{ Id = "Python.Python.3.12";          Name = "Python 3.12" }
    @{ Id = "GoLang.Go";                   Name = "Go" }

    # Containers & virtualisation
    @{ Id = "Docker.DockerDesktop";        Name = "Docker Desktop" }

    # Cloud CLIs
    @{ Id = "Amazon.AWSCLI";               Name = "AWS CLI v2" }
    @{ Id = "Microsoft.AzureCLI";          Name = "Azure CLI" }
    @{ Id = "Google.CloudSDK";             Name = "Google Cloud SDK" }

    # IaC / config
    @{ Id = "Hashicorp.Terraform";         Name = "Terraform" }
    @{ Id = "Hashicorp.Packer";            Name = "Packer" }
    @{ Id = "Pulumi.Pulumi";               Name = "Pulumi" }
    @{ Id = "RedHat.Ansible";              Name = "Ansible (via pip, see below)" }

    # Source control & review
    @{ Id = "Git.Git";                     Name = "Git" }
    @{ Id = "GitHub.cli";                  Name = "GitHub CLI" }
    @{ Id = "GitExtensionsTeam.GitExtensions"; Name = "Git Extensions" }

    # Editors & IDEs
    @{ Id = "Microsoft.VisualStudioCode";  Name = "VS Code" }
    @{ Id = "JetBrains.Toolbox";          Name = "JetBrains Toolbox" }

    # Kubernetes
    @{ Id = "Kubernetes.kubectl";          Name = "kubectl" }
    @{ Id = "Helm.Helm";                   Name = "Helm" }
    @{ Id = "derailed.k9s";               Name = "k9s" }
    @{ Id = "ahmetb.kubectx";             Name = "kubectx / kubens" }

    # Security & secrets
    @{ Id = "GnuPG.GnuPG";               Name = "GnuPG" }
    @{ Id = "twpayne.chezmoi";            Name = "chezmoi (dotfiles)" }
    @{ Id = "FiloSottile.mkcert";         Name = "mkcert (local TLS)" }

    # Productivity CLIs
    @{ Id = "jqlang.jq";                  Name = "jq" }
    @{ Id = "BurntSushi.ripgrep.MSVC";    Name = "ripgrep" }
    @{ Id = "sharkdp.bat";                Name = "bat" }
    @{ Id = "sharkdp.fd";                 Name = "fd" }
    @{ Id = "junegunn.fzf";               Name = "fzf" }
    @{ Id = "dandavison.delta";           Name = "delta (git diff)" }

    # GUI apps
    @{ Id = "WinSCP.WinSCP";             Name = "WinSCP" }
    @{ Id = "PuTTY.PuTTY";              Name = "PuTTY" }
    @{ Id = "Postman.Postman";           Name = "Postman" }
    @{ Id = "DBngin.DBngin";             Name = "DBngin" }
    @{ Id = "dbeaver.dbeaver";           Name = "DBeaver" }
    @{ Id = "Obsidian.Obsidian";         Name = "Obsidian" }
)

foreach ($pkg in $wingetPkgs) {
    Write-Step "  Installing $($pkg.Name)..."
    winget install --id $pkg.Id --silent --accept-package-agreements --accept-source-agreements 2>&1 |
        Where-Object { $_ -notmatch "^$" } | ForEach-Object { Write-Verbose $_ }
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Write-Warning "  $($pkg.Name) returned exit code $LASTEXITCODE — may need manual install"
    }
}

Write-Done "winget installs complete."