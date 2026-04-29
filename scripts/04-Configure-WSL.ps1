# =============================================================================
# 04-Configure-WSL.ps1
# Drops a .wslconfig tuning file and provisions Ubuntu via WSL
# =============================================================================

#Requires -RunAsAdministrator

# ── .wslconfig (global WSL2 settings) ────────────────────────────────────
$wslConfig = @"
[wsl2]
memory=12GB          # Max RAM for WSL2 VM (tune to your hardware)
processors=6         # vCPUs
swap=4GB
swapFile=%USERPROFILE%\AppData\Local\Temp\wsl-swap.vhdx
localhostForwarding=true
nestedVirtualization=true

[experimental]
sparseVhd=true       # Reclaims disk space automatically
autoMemoryReclaim=gradual
"@

$wslConfigPath = "$env:USERPROFILE.wslconfig"
$wslConfig | Set-Content -Path $wslConfigPath -Encoding UTF8
Write-Host "[+] .wslconfig written to $wslConfigPath" -ForegroundColor Green

# ── Ubuntu bootstrap script (runs inside WSL) ────────────────────────────
$ubuntuSetup = @"
#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating apt packages..."
sudo apt-get update -qq && sudo apt-get upgrade -y -qq

echo "==> Installing base packages..."
sudo apt-get install -y -qq \
  build-essential curl wget git vim tmux zsh fzf \
  ca-certificates gnupg lsb-release apt-transport-https \
  unzip jq ripgrep fd-find bat tree htop \
  python3-pip python3-venv pipx \
  software-properties-common

echo "==> Installing Docker CLI (for WSL-side tooling)..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce-cli docker-compose-plugin

echo "==> Installing kubectl..."
curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl && sudo chmod +x /usr/local/bin/kubectl

echo "==> Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "==> Installing AWS CLI v2 (Linux)..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install

echo "==> Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "==> Done! Ubuntu WSL environment ready."
"@

$bootstrapPath = "$env:TEMPwsl-ubuntu-setup.sh"
$ubuntuSetup | Set-Content -Path $bootstrapPath -Encoding UTF8 -NoNewline

Write-Host "[*] Running Ubuntu bootstrap inside WSL..." -ForegroundColor Cyan
wsl -d Ubuntu-24.04 -- bash /mnt/c/Users/$env:USERNAME/AppData/Local/Temp/wsl-ubuntu-setup.sh

Write-Host "[+] WSL configuration complete!" -ForegroundColor Green