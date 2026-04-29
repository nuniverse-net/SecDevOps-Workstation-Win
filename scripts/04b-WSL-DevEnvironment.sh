#!/usr/bin/env bash
# =============================================================================
# 04b-WSL-DevEnvironment.sh
# Run INSIDE Ubuntu WSL2 — installs the full Linux-native DevOps toolchain
# Usage:  bash 04b-WSL-DevEnvironment.sh
# Idempotent: safe to re-run
# =============================================================================
set -euo pipefail

BOLD="\033[1m"; CYAN="\033[36m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"
step() { echo -e "${CYAN}${BOLD}[*] $*${RESET}"; }
done_() { echo -e "${GREEN}[+] $*${RESET}"; }
warn() { echo -e "${YELLOW}[!] $*${RESET}"; }

# ── 1. APT base packages ──────────────────────────────────────────────────
step "Updating apt and installing base packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq \
  build-essential curl wget git vim neovim tmux zsh \
  ca-certificates gnupg lsb-release apt-transport-https \
  unzip zip tar gzip xz-utils \
  jq yq ripgrep fd-find bat tree htop ncdu \
  fzf direnv stow \
  python3 python3-pip python3-venv pipx \
  software-properties-common \
  make gcc g++ cmake pkg-config \
  libssl-dev libffi-dev zlib1g-dev \
  socat netcat-openbsd dnsutils iputils-ping

# bat is installed as batcat on Ubuntu — create alias
mkdir -p ~/.local/bin
ln -sf /usr/bin/batcat ~/.local/bin/bat 2>/dev/null || true
# fd is installed as fdfind on Ubuntu
ln -sf /usr/bin/fdfind ~/.local/bin/fd 2>/dev/null || true

# ── 2. Git & credential helper ───────────────────────────────────────────
step "Configuring Git..."
sudo add-apt-repository ppa:git-core/ppa -y -n 2>/dev/null || true
sudo apt-get update -qq && sudo apt-get install -y -qq git

# Use the Windows Git Credential Manager from WSL (avoids duplicate auth)
git config --global credential.helper \
  "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
git config --global core.autocrlf input
git config --global init.defaultBranch main
git config --global fetch.prune true
git config --global pull.rebase false

# ── 3. Zsh + Oh My Zsh ───────────────────────────────────────────────────
step "Installing Zsh and Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Useful Oh My Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ] && \
  git clone --depth 1 https://github.com/zsh-users/zsh-completions \
  "$ZSH_CUSTOM/plugins/zsh-completions"

# Set zsh as default shell
sudo chsh -s "$(which zsh)" "$USER"

# ── 4. Node.js (via nvm) ─────────────────────────────────────────────────
step "Installing nvm + Node.js LTS..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default node

# Global npm tools
npm install -g \
  aws-cdk \
  serverless \
  yarn \
  pnpm \
  typescript \
  ts-node \
  prettier \
  eslint

# ── 5. Python toolchain ──────────────────────────────────────────────────
step "Installing Python DevOps tools..."
python3 -m pip install --upgrade pip --quiet

# Use pipx for CLI tools (isolated envs, no conflicts)
pipx install ansible
pipx install ansible-lint
pipx install pre-commit
pipx install detect-secrets
pipx install black
pipx install ruff
pipx install awscurl
pipx install httpie
pipx install poetry
pipx install ipython

# ── 6. Go ────────────────────────────────────────────────────────────────
step "Installing Go..."
GO_VERSION="1.22.3"
GO_ARCH="linux-amd64"
if ! command -v go &>/dev/null || [[ "$(go version)" != *"$GO_VERSION"* ]]; then
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
fi
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

# Go-based tools
go install github.com/derailed/k9s@latest 2>/dev/null || true
go install sigs.k8s.io/kind@latest 2>/dev/null || true

# ── 7. Rust ──────────────────────────────────────────────────────────────
step "Installing Rust (rustup)..."
if ! command -v rustup &>/dev/null; then
  curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
source "$HOME/.cargo/env"

# Useful Rust CLI tools (faster than GNU equivalents)
cargo install \
  hyperfine \
  tokei \
  du-dust \
  bottom \
  2>/dev/null || true

# ── 8. Docker CLI (connects to Docker Desktop daemon) ───────────────────
step "Installing Docker CLI..."
if ! command -v docker &>/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce-cli docker-compose-plugin docker-buildx-plugin
fi

# Add user to docker group (for Docker-in-Docker or local daemon scenarios)
sudo usermod -aG docker "$USER" 2>/dev/null || true

# ── 9. kubectl ───────────────────────────────────────────────────────────
step "Installing kubectl..."
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  -o /tmp/kubectl
sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# ── 10. Helm ─────────────────────────────────────────────────────────────
step "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ── 11. kubectx / kubens ─────────────────────────────────────────────────
step "Installing kubectx and kubens..."
sudo git clone --depth 1 https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || \
  sudo git -C /opt/kubectx pull
sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -sf /opt/kubectx/kubens  /usr/local/bin/kubens

# ── 12. Terraform ────────────────────────────────────────────────────────
step "Installing Terraform + OpenTofu..."
wget -qO- https://apt.releases.hashicorp.com/gpg |
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -qq
sudo apt-get install -y -qq terraform packer

# OpenTofu (open-source Terraform fork)
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sudo bash -s -- --install-method deb

# tenv — manages multiple Terraform/OpenTofu versions (like nvm for Terraform)
TENV_VERSION="$(curl -fsSL https://api.github.com/repos/tofuutils/tenv/releases/latest | jq -r .tag_name)"
curl -fsSL "https://github.com/tofuutils/tenv/releases/latest/download/tenv_${TENV_VERSION}_amd64.deb" \
  -o /tmp/tenv.deb && sudo dpkg -i /tmp/tenv.deb

# ── 13. AWS CLI v2 ───────────────────────────────────────────────────────
step "Installing AWS CLI v2..."
if ! command -v aws &>/dev/null || ! aws --version 2>&1 | grep -q "aws-cli/2"; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/awscliv2
  sudo /tmp/awscliv2/aws/install --update
  rm -rf /tmp/awscliv2 /tmp/awscliv2.zip
fi

# AWS Session Manager Plugin (for SSM-based SSH tunnels)
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
  -o /tmp/ssm-plugin.deb
sudo dpkg -i /tmp/ssm-plugin.deb

# ── 14. Azure CLI ────────────────────────────────────────────────────────
step "Installing Azure CLI..."
curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash

# ── 15. Google Cloud SDK ─────────────────────────────────────────────────
step "Installing Google Cloud SDK..."
if ! command -v gcloud &>/dev/null; then
  curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
fi

# ── 16. GitHub CLI ───────────────────────────────────────────────────────
step "Installing GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" |
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -qq && sudo apt-get install -y -qq gh

# ── 17. Pulumi ───────────────────────────────────────────────────────────
step "Installing Pulumi..."
curl -fsSL https://get.pulumi.com | sh

# ── 18. Security / secrets tooling ───────────────────────────────────────
step "Installing security tools..."

# git-secrets — prevent committing secrets
if ! command -v git-secrets &>/dev/null; then
  git clone --depth 1 https://github.com/awslabs/git-secrets /tmp/git-secrets
  sudo make -C /tmp/git-secrets install
  git secrets --register-aws --global
fi

# sops — secret encryption for files (pairs with age or PGP)
SOPS_VERSION="$(curl -fsSL https://api.github.com/repos/getsops/sops/releases/latest | jq -r .tag_name)"
curl -fsSL "https://github.com/getsops/sops/releases/latest/download/sops-${SOPS_VERSION}.linux.amd64" \
  -o /tmp/sops && sudo install /tmp/sops /usr/local/bin/sops

# age — modern encryption tool (used with sops)
sudo apt-get install -y -qq age

# ── 19. .zshrc configuration ─────────────────────────────────────────────
step "Writing ~/.zshrc..."
cat > "$HOME/.zshrc" << "ZSHRC"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  docker
  kubectl
  helm
  terraform
  aws
  gh
  direnv
  fzf
)

source $ZSH/oh-my-zsh.sh

# ── PATH ──────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.pulumi/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── Aliases ───────────────────────────────────────────────────────────────
alias ls="ls --color=auto"
alias ll="ls -lah"
alias cat="bat --paging=never"
alias grep="rg"
alias find="fd"
alias tf="terraform"
alias tof="tofu"
alias k="kubectl"
alias kx="kubectx"
alias kn="kubens"
alias dc="docker compose"
alias d="docker"

# ── kubectl completions ────────────────────────────────────────────────────
source <(kubectl completion zsh)
source <(helm completion zsh)
source <(gh completion -s zsh)

# ── direnv hook ───────────────────────────────────────────────────────────
eval "$(direnv hook zsh)"

# ── AWS profile helper ────────────────────────────────────────────────────
awsp() { export AWS_PROFILE="$1"; echo "Switched to AWS profile: $1"; }

ZSHRC

# ── 20. PowerShell (pwsh) ────────────────────────────────────────────────
step "Installing PowerShell 7..."
# Official Microsoft apt repo — tracks stable releases
if ! command -v pwsh &>/dev/null; then
  # Install prereqs
  sudo apt-get install -y -qq wget apt-transport-https software-properties-common
  # Download and register the Microsoft repo GPG key
  SOURCE_LIST="https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
  wget -q "$SOURCE_LIST" -O /tmp/packages-microsoft-prod.deb
  sudo dpkg -i /tmp/packages-microsoft-prod.deb
  rm /tmp/packages-microsoft-prod.deb
  sudo apt-get update -qq
  sudo apt-get install -y -qq powershell
fi

# Install AWS Tools for PowerShell (modular) inside WSL pwsh
pwsh -NoProfile -NonInteractive -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module -Name AWS.Tools.Installer -Scope CurrentUser -Force"
pwsh -NoProfile -NonInteractive -Command "Install-AWSToolsModule AWS.Tools.Common,AWS.Tools.EC2,AWS.Tools.S3,AWS.Tools.IAM,AWS.Tools.SecretsManager,AWS.Tools.SSM,AWS.Tools.Organizations -Scope CurrentUser -Force -CleanUp" 2>/dev/null || true
pwsh -NoProfile -NonInteractive -Command "Install-Module Posh-Git,PSReadLine,Terminal-Icons -Scope CurrentUser -Force" 2>/dev/null || warn "Some PS modules failed — re-run: pwsh then Install-Module <name>"

# Write a PowerShell profile for WSL
PWSH_PROFILE_DIR="$(pwsh -NoProfile -Command "Split-Path $PROFILE" 2>/dev/null)"
mkdir -p "$PWSH_PROFILE_DIR"
cat > "${PWSH_PROFILE_DIR}/Microsoft.PowerShell_profile.ps1" << "PWSHPROFILE"
# WSL PowerShell Profile

# ── Modules ───────────────────────────────────────────────────────────────
Import-Module Posh-Git      -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# ── PSReadLine config ─────────────────────────────────────────────────────
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# ── Aliases ───────────────────────────────────────────────────────────────
Set-Alias k    kubectl
Set-Alias tf   terraform
Set-Alias tof  tofu
Set-Alias d    docker
function dc  { docker compose @args }
function kx  { kubectx @args }
function kn  { kubens @args }
function ll  { Get-ChildItem -Force @args }

# ── AWS profile helper ────────────────────────────────────────────────────
function awsp {
  param([string]$Profile)
  $env:AWS_PROFILE = $Profile
  Write-Host "Switched to AWS profile: $Profile" -ForegroundColor Cyan
}

# ── kubectl completions ───────────────────────────────────────────────────
kubectl completion powershell | Out-String | Invoke-Expression

# ── Prompt ────────────────────────────────────────────────────────────────
function prompt {
  $loc = $executionContext.SessionState.Path.CurrentLocation
  $branch = if ((Get-Command git -ErrorAction SilentlyContinue) -and (git rev-parse --abbrev-ref HEAD 2>$null)) {
    " [$(git rev-parse --abbrev-ref HEAD 2>$null)]" } else { "" }
  $awsProf = if ($env:AWS_PROFILE) { " (aws:$env:AWS_PROFILE)" } else { "" }
  Write-Host "PS " -NoNewline -ForegroundColor DarkGray
  Write-Host "$loc" -NoNewline -ForegroundColor Cyan
  Write-Host "$branch" -NoNewline -ForegroundColor Yellow
  Write-Host "$awsProf" -NoNewline -ForegroundColor Green
  return "> "
}
PWSHPROFILE

done_ "PowerShell (pwsh) installed and configured"

# ── 21. Fish shell ───────────────────────────────────────────────────────
step "Installing Fish shell..."
sudo apt-add-repository ppa:fish-shell/release-3 -y -n 2>/dev/null || true
sudo apt-get update -qq
sudo apt-get install -y -qq fish

# Fisher — Fish plugin manager
fish -c "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" 2>/dev/null

# Fish plugins
fish -c "fisher install \
  jorgebucaran/autopair.fish \
  PatrickF1/fzf.fish \
  jethrokuan/z \
  nickeb96/puffer-fish \
  jorgebucaran/nvm.fish" 2>/dev/null || warn "Some Fisher plugins failed — run manually inside fish"

# Write Fish config
mkdir -p "$HOME/.config/fish/functions"
cat > "$HOME/.config/fish/config.fish" << "FISHCONFIG"
# Fish Shell Config — WSL DevOps

# ── PATH ──────────────────────────────────────────────────────────────────
fish_add_path $HOME/.local/bin
fish_add_path $HOME/go/bin
fish_add_path /usr/local/go/bin
fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/.pulumi/bin
fish_add_path /usr/local/bin

# ── nvm (Fish-native via jorgebucaran/nvm.fish) ───────────────────────────
set --universal nvm_default_version lts

# ── direnv hook ───────────────────────────────────────────────────────────
direnv hook fish | source

# ── Aliases (Fish uses abbr for expansion, functions for complex cases) ───
abbr -a k    kubectl
abbr -a tf   terraform
abbr -a tof  tofu
abbr -a d    docker
abbr -a dc   "docker compose"
abbr -a kx   kubectx
abbr -a kn   kubens
abbr -a ll   "ls -lah"
abbr -a cat  "bat --paging=never"
abbr -a grep rg
abbr -a find fd

# ── AWS profile helper ────────────────────────────────────────────────────
function awsp
  set -gx AWS_PROFILE $argv[1]
  echo "Switched to AWS profile: $argv[1]"
end

# ── kubectl completions (Fish-native) ─────────────────────────────────────
kubectl completion fish | source
helm    completion fish | source

# ── Suppress greeting ─────────────────────────────────────────────────────
set fish_greeting ""
FISHCONFIG

# Starship prompt — works in Fish, Zsh, and PowerShell
step "Installing Starship prompt (cross-shell)..."
curl -fsSL https://starship.rs/install.sh | sh -s -- -y

# Add Starship to all three shells
# zsh — append to .zshrc if not already there
grep -q "starship init zsh" "$HOME/.zshrc" || \
  echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"

# Fish — add to config.fish
grep -q "starship init fish" "$HOME/.config/fish/config.fish" || \
  echo 'starship init fish | source' >> "$HOME/.config/fish/config.fish"

# PowerShell — add to profile
PWSH_PROFILE="${PWSH_PROFILE_DIR}/Microsoft.PowerShell_profile.ps1"
if [ -f "$PWSH_PROFILE" ]; then
  grep -q "starship init powershell" "$PWSH_PROFILE" || \
    echo 'Invoke-Expression (&starship init powershell)' >> "$PWSH_PROFILE"
fi

# Write Starship config
mkdir -p "$HOME/.config"
cat > "$HOME/.config/starship.toml" << "STARSHIP"
[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"

[directory]
truncation_length = 4
truncate_to_repo  = true

[git_branch]
symbol = " "

[git_status]
ahead  = "⇡${count}"
behind = "⇣${count}"
staged = "[+${count}](green)"
modified = "[!${count}](yellow)"
untracked = "[?${count}](blue)"

[aws]
symbol = " "
format = "[$symbol$profile(\($region\))]($style) "
style  = "bold yellow"

[kubernetes]
disabled = false
format   = "[ $context(\($namespace\))]($style) "
style    = "bold blue"

[terraform]
format = "[ $workspace]($style) "

[nodejs]
symbol = " "

[python]
symbol = " "

[golang]
symbol = " "

[rust]
symbol = " "
STARSHIP

done_ "Fish shell installed and configured"
done_ "Starship prompt installed (Zsh + Fish + PowerShell)"

# ── 22. SSH key (reuse Windows key from WSL) ─────────────────────────────
step "Linking Windows SSH key into WSL..."
WIN_SSH="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d "\r")/.ssh"
mkdir -p "$HOME/.ssh"
if [ -f "$WIN_SSH/id_ed25519" ]; then
  # Copy (not symlink) because WSL filesystem permissions differ
  cp "$WIN_SSH/id_ed25519"     "$HOME/.ssh/id_ed25519"
  cp "$WIN_SSH/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"
  chmod 600 "$HOME/.ssh/id_ed25519"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"
  done_ "SSH key copied from Windows .ssh directory"
else
  warn "No Windows SSH key found — generating a new one in WSL"
  ssh-keygen -t ed25519 -C "$(whoami)@wsl-$(hostname)" -f "$HOME/.ssh/id_ed25519" -N ""
fi

# ── 23. pre-commit global hooks ──────────────────────────────────────────
step "Configuring pre-commit and detect-secrets globally..."
git config --global init.templateDir ~/.git-template
pre-commit init-templatedir ~/.git-template

# ── 24. Verify ───────────────────────────────────────────────────────────
step "Running verification..."
echo ""
tools=(
  "git --version"
  "docker --version"
  "kubectl version --client --short 2>/dev/null"
  "helm version --short"
  "terraform version -json | jq -r .terraform_version"
  "aws --version"
  "az version --query '\"azure-cli\"' -o tsv"
  "node --version"
  "python3 --version"
  "go version"
  "rustc --version"
  "ansible --version | head -1"
  "pre-commit --version"
  "sops --version"
  "pulumi version"
  "gh --version | head -1"
  "pwsh --version"
  "fish --version"
  "starship --version"
)

PASS=0; FAIL=0
for cmd in "${tools[@]}"; do
  tool_name="$(echo "$cmd" | awk "{print \$1}")"
  if output=$(eval "$cmd" 2>&1); then
    printf "  \033[32m[PASS]\033[0m %-20s %s\n" "$tool_name" "$output"
    ((PASS++))
  else
    printf "  \033[31m[FAIL]\033[0m %s\n" "$tool_name"
    ((FAIL++))
  fi
done

echo ""
echo -e "${GREEN}Results: $PASS passed, $FAIL failed${RESET}"
echo ""
done_ "WSL dev environment setup complete!"
warn "Open a new shell (or run: exec zsh) for all PATH changes to take effect."