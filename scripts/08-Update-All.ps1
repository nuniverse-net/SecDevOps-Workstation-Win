# =============================================================================
# 08-Update-All.ps1
# Monthly maintenance — updates all Windows and WSL tooling
# Run as Administrator for full coverage; works without Admin for most updates
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Done { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DevOps Workstation — Monthly Update          " -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')        " -ForegroundColor DarkGray
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── winget: update all packages ───────────────────────────────────────────────
Write-Step "Updating all winget packages..."
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
Write-Done "winget updates complete."

# ── WSL kernel ────────────────────────────────────────────────────────────────
Write-Step "Updating WSL kernel..."
wsl --update
Write-Done "WSL kernel updated."

# ── PowerShell modules ────────────────────────────────────────────────────────
Write-Step "Updating PowerShell modules..."
Update-Module -Force -ErrorAction SilentlyContinue
Write-Done "PowerShell modules updated."

# ── AWS Tools for PowerShell ──────────────────────────────────────────────────
Write-Step "Updating AWS Tools for PowerShell..."
Update-AWSToolsModule -Force -ErrorAction SilentlyContinue
Write-Done "AWS Tools updated."

# ── VS Code extensions ────────────────────────────────────────────────────────
Write-Step "Updating VS Code extensions..."
code --list-extensions 2>/dev/null | ForEach-Object {
    code --install-extension $_ --force 2>&1 | Out-Null
}
Write-Done "VS Code extensions updated."

# ── Windows pip tools ─────────────────────────────────────────────────────────
Write-Step "Updating Windows pip tools..."
pip install --upgrade pip pre-commit detect-secrets --quiet
Write-Done "pip tools updated."

# ── npm globals ───────────────────────────────────────────────────────────────
Write-Step "Updating npm global packages..."
npm update -g --silent
Write-Done "npm globals updated."

# ── WSL: full update ──────────────────────────────────────────────────────────
Write-Step "Running apt upgrade inside WSL Ubuntu..."
wsl -d Ubuntu-24.04 -- bash -c "sudo apt-get update -qq && sudo apt-get upgrade -y -qq && sudo apt-get autoremove -y -qq"
Write-Done "WSL apt packages updated."

Write-Step "Updating WSL pip/pipx tools..."
wsl -d Ubuntu-24.04 -- bash -c "
    pipx upgrade-all --quiet 2>/dev/null || true
    python3 -m pip install --upgrade pip --quiet
"
Write-Done "WSL Python tools updated."

Write-Step "Updating WSL npm globals..."
wsl -d Ubuntu-24.04 -- bash -c "source ~/.nvm/nvm.sh && npm update -g --silent"
Write-Done "WSL npm globals updated."

Write-Step "Updating WSL Rust and cargo tools..."
wsl -d Ubuntu-24.04 -- bash -c "
    source ~/.cargo/env
    rustup update --quiet
    cargo install hyperfine tokei du-dust bottom 2>/dev/null || true
"
Write-Done "WSL Rust tools updated."

Write-Step "Updating WSL Go tools..."
wsl -d Ubuntu-24.04 -- bash -c "
    export PATH=/usr/local/go/bin:\$HOME/go/bin:\$PATH
    go install github.com/derailed/k9s@latest 2>/dev/null || true
    go install sigs.k8s.io/kind@latest 2>/dev/null || true
"
Write-Done "WSL Go tools updated."

Write-Step "Updating WSL kubectl to latest stable..."
wsl -d Ubuntu-24.04 -- bash -c "
    KUBECTL_VERSION=\"\$(curl -fsSL https://dl.k8s.io/release/stable.txt)\"
    curl -fsSL \"https://dl.k8s.io/release/\${KUBECTL_VERSION}/bin/linux/amd64/kubectl\" -o /tmp/kubectl
    sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm /tmp/kubectl
"
Write-Done "kubectl updated."

# ── Docker cleanup ────────────────────────────────────────────────────────────
Write-Step "Pruning unused Docker images and build cache..."
Write-Warn "This removes stopped containers, dangling images, and unused build cache."
$prune = Read-Host "Proceed with Docker prune? (y/N)"
if ($prune -match '^[Yy]') {
    docker system prune -f | Out-Null
    docker volume prune -f  | Out-Null
    Write-Done "Docker cleanup complete."
} else {
    Write-Host "  Skipped Docker prune." -ForegroundColor DarkGray
}

# ── WSL VHD compaction ────────────────────────────────────────────────────────
Write-Step "WSL VHD compaction (reclaims disk space)..."
Write-Warn "This shuts down WSL temporarily. Close any WSL terminals first."
$compact = Read-Host "Compact WSL VHD? (y/N)"
if ($compact -match '^[Yy]') {
    wsl --shutdown
    $vhdPattern = "$env:LOCALAPPDATA\Packages\CanonicalGroup*\LocalState\ext4.vhdx"
    $vhdPath = Resolve-Path $vhdPattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vhdPath) {
        try {
            Optimize-VHD -Path $vhdPath.Path -Mode Full -ErrorAction Stop
            Write-Done "VHD compacted: $($vhdPath.Path)"
        } catch {
            Write-Warn "Optimize-VHD failed — requires Hyper-V tools. Try: diskpart > select vdisk file='...' > compact vdisk"
        }
    } else {
        Write-Warn "WSL VHD not found at expected path."
    }
}

Write-Host ""
Write-Done "All updates complete — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host ""
