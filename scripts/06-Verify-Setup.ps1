# =============================================================================
# 06-Verify-Setup.ps1
# Verifies all tools installed correctly — run after all other scripts
# =============================================================================

$pass = 0; $fail = 0

function Test-Tool {
    param($name, $cmd, $pattern)
    try {
        $out = Invoke-Expression $cmd 2>&1 | Out-String
        if ($out -match $pattern) {
            Write-Host "  [PASS] $name" -ForegroundColor Green
            $script:pass++
        } else {
            Write-Host "  [WARN] $name — unexpected output" -ForegroundColor Yellow
            $script:fail++
        }
    } catch {
        Write-Host "  [FAIL] $name — not found or errored" -ForegroundColor Red
        $script:fail++
    }
}

Write-Host "=== DevOps Workstation Verification ===" -ForegroundColor Cyan

Test-Tool "WSL2"          "wsl --status"                    "Default Version: 2"
Test-Tool "Ubuntu WSL"    "wsl -l -v"                       "Ubuntu"
Test-Tool "Docker"        "docker --version"                "Docker version"
Test-Tool "docker compose""docker compose version"          "Docker Compose"
Test-Tool "Git"           "git --version"                   "git version"
Test-Tool "GitHub CLI"    "gh --version"                    "gh version"
Test-Tool "kubectl"       "kubectl version --client"        "Client"
Test-Tool "Helm"          "helm version"                    "Version"
Test-Tool "k9s"           "k9s version"                     "Version"
Test-Tool "Terraform"     "terraform version"               "Terraform v"
Test-Tool "AWS CLI"       "aws --version"                   "aws-cli"
Test-Tool "Azure CLI"     "az --version"                    "azure-cli"
Test-Tool "Python"        "python --version"                "Python 3"
Test-Tool "pip"           "pip --version"                   "pip"
Test-Tool "Node.js"       "node --version"                  "v"
Test-Tool "npm"           "npm --version"                   "\d+"
Test-Tool "Go"            "go version"                      "go version"
Test-Tool "jq"            "jq --version"                    "jq-"
Test-Tool "VS Code"       "code --version"                  "\d+\.\d+"
Test-Tool "SSH Agent"     "(Get-Service ssh-agent).Status"  "Running"
Test-Tool "SSH Key"       "Test-Path $env:USERPROFILE.sshid_ed25519" "True"

Write-Host ""
Write-Host "Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })

if ($fail -gt 0) {
    Write-Host "Review failed items above and re-run the appropriate setup script." -ForegroundColor Yellow
}