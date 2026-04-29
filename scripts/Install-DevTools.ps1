<#
.SYNOPSIS
    Install core development environment tools

.DESCRIPTION
    Installs development tools via winget:
    - Git — version control (winget: Git.Git)
    - Node.js — JavaScript runtime (winget: OpenJS.NodeJS)
    - Python — interpreted language (winget: Python.Python.3.12)
    - PowerShell 7+ — modern PowerShell (winget: Microsoft.PowerShell)
    - VS Code — code editor (winget: Microsoft.VisualStudioCode)
    - Docker Desktop — containerization (winget: Docker.DockerDesktop)

.PARAMETER Validate
    Verify installation after completion

.PARAMETER DryRun
    Show what would be done without making changes
#>

[CmdletBinding()]
param(
    [switch]$Validate,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'SecDevOps.Core.psm1') -Force

Write-Log "Starting Development Tools installation" -Level Info

$tools = @(
    @{ PackageId = 'Git.Git'; Name = 'Git'; Validation = 'git' },
    @{ PackageId = 'OpenJS.NodeJS'; Name = 'Node.js'; Validation = 'node' },
    @{ PackageId = 'Python.Python.3.12'; Name = 'Python 3.12'; Validation = 'python' },
    @{ PackageId = 'Microsoft.PowerShell'; Name = 'PowerShell 7+'; Validation = 'pwsh' },
    @{ PackageId = 'Microsoft.VisualStudioCode'; Name = 'VS Code'; Validation = 'code' },
    @{ PackageId = 'Docker.DockerDesktop'; Name = 'Docker Desktop'; Validation = 'docker' }
)

foreach ($tool in $tools) {
    Write-Log "Processing $($tool.Name) ($($tool.PackageId))" -Level Info

    if (-not $DryRun) {
        try {
            $installed = winget list --id $tool.PackageId 2>$null | Select-String $tool.PackageId
            if ($installed) {
                Write-Log "$($tool.Name) already installed" -Level Success
                continue
            }

            Write-Log "Installing $($tool.Name)..." -Level Info
            winget install --id $tool.PackageId --accept-source-agreements --accept-package-agreements --silent 2>$null

            if ($?) {
                Write-Log "✓ $($tool.Name) installed" -Level Success
            } else {
                Write-Log "Failed to install $($tool.Name) via winget. Verify package ID exists." -Level Warning
            }
        } catch {
            Write-Log "Error installing $($tool.Name): $_" -Level Warning
        }
    } else {
        Write-Log "[DRY-RUN] Would install $($tool.Name)" -Level Info
    }
}

# Post-installation configuration
if (-not $DryRun) {
    Write-Log "Running post-installation configuration" -Level Info

    try {
        git config --global core.autocrlf true
        git config --global user.email "nuno@bluerush.com"
        Write-Log "Git configured with CRLF handling" -Level Success
    } catch {
        Write-Log "Could not configure Git: $_" -Level Warning
    }

    try {
        npm config set prefix "$env:APPDATA\npm" --global
        Write-Log "Node.js/npm configured with app-data prefix" -Level Success
    } catch {
        Write-Log "Could not configure npm: $_" -Level Warning
    }
}

# Validation
if ($Validate -and -not $DryRun) {
    Write-Log "Validating development tools installation" -Level Info

    $validationPassed = $true

    foreach ($tool in $tools) {
        if (Test-CommandExists $tool.Validation) {
            Write-Log "✓ $($tool.Name) available in PATH" -Level Success
        } else {
            Write-Log "✗ $($tool.Name) not found in PATH (may need shell restart)" -Level Warning
            $validationPassed = $false
        }
    }

    if ($validationPassed) {
        Write-Log "Development tools validation passed" -Level Success
    } else {
        Write-Log "Some development tools could not be validated. Restart PowerShell to update PATH." -Level Warning
    }
}

Write-Log "Development Tools installation complete" -Level Success
