# =============================================================================
# 03-Configure-DevEnvironment.ps1
# Run as Administrator — post-install configuration
# Configures Git, PowerShell modules, AWS Tools, VS Code extensions, Docker
# =============================================================================

#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Done { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }

# ── PowerShell modules ────────────────────────────────────────────────────
Write-Step "Installing PowerShell modules..."

$psModules = @(
    "AWS.Tools.Installer",    # AWS Tools for PowerShell (modular)
    "Az",                     # Azure PowerShell module
    "Posh-Git",               # Git integration in prompt
    "PSReadLine",             # Better readline for PS
    "Terminal-Icons",         # File icons in terminal
    "ImportExcel",            # Excel manipulation
    "PowerShellGet"           # Module management
)

foreach ($mod in $psModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Step "  Installing $mod..."
        Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
    } else {
        Write-Host "  [skip] $mod already installed" -ForegroundColor DarkGray
    }
}

# Install AWS Tools for PowerShell (modular — installs only what you need)
Write-Step "Installing AWS.Tools modules..."
Install-AWSToolsModule AWS.Tools.EC2, AWS.Tools.S3, AWS.Tools.IAM, `
    AWS.Tools.SecretsManager, AWS.Tools.SSM, AWS.Tools.Organizations `
    -Scope CurrentUser -Force

# ── Git global config ─────────────────────────────────────────────────────
Write-Step "Configuring Git globals..."

$gitEmail = Read-Host "Enter your Git email"
$gitName  = Read-Host "Enter your Git display name"

git config --global user.email $gitEmail
git config --global user.name  $gitName
git config --global core.autocrlf input
git config --global core.editor "code --wait"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global fetch.prune true
git config --global diff.tool vscode
git config --global merge.tool vscode
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.light false

# ── VS Code extensions ────────────────────────────────────────────────────
Write-Step "Installing VS Code extensions..."

$vscodeExts = @(
    "ms-vscode-remote.remote-wsl",
    "ms-vscode-remote.remote-containers",
    "ms-vscode-remote.remote-ssh",
    "ms-azuretools.vscode-docker",
    "hashicorp.terraform",
    "redhat.ansible",
    "ms-python.python",
    "ms-python.black-formatter",
    "golang.go",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "eamodio.gitlens",
    "mhutchie.git-graph",
    "github.copilot",
    "github.copilot-chat",
    "amazonwebservices.aws-toolkit-vscode",
    "ms-kubernetes-tools.vscode-kubernetes-tools",
    "timonwong.shellcheck",
    "foxundermoon.shell-format",
    "aaron-bond.better-comments",
    "streetsidesoftware.code-spell-checker"
)

foreach ($ext in $vscodeExts) {
    code --install-extension $ext --force 2>&1 | Out-Null
    Write-Host "  [+] $ext" -ForegroundColor DarkGreen
}

# ── Docker Desktop configuration ──────────────────────────────────────────
Write-Step "Configuring Docker Desktop settings..."

$dockerSettings = @{
    "wslEngineEnabled"        = $true
    "useCredentialHelper"     = $true
    "buildkitEnabled"         = $true
    "exposeDockerAPIOnTCP2375"= $false   # Keep this false — security risk
    "memoryMiB"               = 8192
    "cpus"                    = 4
    "diskSizeMiB"             = 65536
}

$settingsPath = "$env:APPDATADockersettings.json"
if (Test-Path $settingsPath) {
    $existing = Get-Content $settingsPath | ConvertFrom-Json
    foreach ($key in $dockerSettings.Keys) {
        $existing | Add-Member -NotePropertyName $key -NotePropertyValue $dockerSettings[$key] -Force
    }
    $existing | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
    Write-Done "Docker settings updated at $settingsPath"
} else {
    Write-Warning "Docker settings file not found — start Docker Desktop first, then re-run."
}

# ── Python tooling ────────────────────────────────────────────────────────
Write-Step "Installing Python DevOps tools..."
pip install --upgrade pip ansible ansible-lint pre-commit detect-secrets black ruff awscurl

# ── Node global tools ─────────────────────────────────────────────────────
Write-Step "Installing Node.js global tools..."
npm install -g aws-cdk serverless yarn pnpm

Write-Done "Environment configuration complete!"