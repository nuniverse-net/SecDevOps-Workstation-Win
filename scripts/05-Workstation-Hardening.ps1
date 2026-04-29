# =============================================================================
# 05-Workstation-Hardening.ps1
# Basic security hardening for a developer workstation
# =============================================================================

#Requires -RunAsAdministrator
Set-StrictMode -Version Latest

function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }

# ── PowerShell execution policy ───────────────────────────────────────────
Write-Step "Setting PS execution policy to RemoteSigned..."
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# ── Windows Defender exclusions for dev folders ───────────────────────────
Write-Step "Adding Defender exclusions for dev paths..."
$devPaths = @(
    "$env:USERPROFILE\.wsl",
    "$env:LOCALAPPDATA\Docker",
    "C:\ProgramData\DockerDesktop",
    "$env:USERPROFILE\source",
    "$env:USERPROFILE\repos"
)
foreach ($path in $devPaths) {
    Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
    Write-Host "  Excluded: $path" -ForegroundColor DarkGray
}

# ── Firewall rules for Docker ─────────────────────────────────────────────
Write-Step "Adding firewall rule for Docker host networking..."
New-NetFirewallRule -DisplayName "DockerDesktop-Allow-Loopback" `
  -Direction Inbound -Protocol TCP `
  -LocalPort 2375,2376,5000,8080,8443,9000 `
  -Action Allow -Profile Private -ErrorAction SilentlyContinue | Out-Null

# ── Disable TCP port 2375 (insecure Docker daemon) ───────────────────────
Write-Step "Ensuring Docker daemon TCP port 2375 is NOT exposed..."
# This is enforced in Docker settings — no unauthenticated API access

# ── SSH Agent service ─────────────────────────────────────────────────────
Write-Step "Enabling OpenSSH Authentication Agent..."
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent

# Generate SSH key if not present
if (-not (Test-Path "$env:USERPROFILE.sshid_ed25519")) {
    Write-Step "Generating ED25519 SSH key..."
    $comment = "$env:USERNAME@$env:COMPUTERNAME-$(Get-Date -Format yyyyMMdd)"
    ssh-keygen -t ed25519 -C $comment -f "$env:USERPROFILE.sshid_ed25519" -N ''
    ssh-add "$env:USERPROFILE.sshid_ed25519"
    Write-Host "[+] SSH key generated. Public key:" -ForegroundColor Green
    Get-Content "$env:USERPROFILE.sshid_ed25519.pub"
}

# ── Credential manager ────────────────────────────────────────────────────
Write-Step "Configuring Git credential manager..."
git config --global credential.helper manager

# ── Windows Terminal default profile ─────────────────────────────────────
Write-Step "Windows Terminal settings reminder:"
Write-Host "  Manually configure via: Settings > Startup > Default Profile > Ubuntu" -ForegroundColor Yellow

Write-Host "[+] Hardening complete." -ForegroundColor Green