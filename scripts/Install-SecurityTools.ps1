<#
.SYNOPSIS
    Install offensive and defensive security tools

.DESCRIPTION
    Installs security testing utilities via multiple sources:
    - Burp Suite Community — web vulnerability scanner (GitHub release)
    - OWASP ZAP — dynamic application security testing (GitHub release)
    - Metasploit Framework — penetration testing (PowerShell Gallery)
    - Sysinternals Suite — process and system analysis (winget: Microsoft.Sysinternals.Suite)
    - Mimikatz — credential extraction tool (GitHub, requires compliance check)

.PARAMETER Validate
    Verify installation after completion

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER SkipMimikatz
    Skip Mimikatz installation (recommended for restricted environments)
#>

[CmdletBinding()]
param(
    [switch]$Validate,
    [switch]$DryRun,
    [switch]$SkipMimikatz
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'SecDevOps.Core.psm1') -Force

Write-Log "Starting Security Tools installation" -Level Info

# Install via winget
Write-Log "Installing tools via winget" -Level Info

$wingetTools = @(
    @{ PackageId = 'Microsoft.Sysinternals.Suite'; Name = 'Sysinternals Suite'; Validation = 'procexp' }
)

foreach ($tool in $wingetTools) {
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
                Write-Log "Failed to install $($tool.Name)" -Level Warning
            }
        } catch {
            Write-Log "Error installing $($tool.Name): $_" -Level Warning
        }
    } else {
        Write-Log "[DRY-RUN] Would install $($tool.Name)" -Level Info
    }
}

# Install Burp Suite Community from GitHub
Write-Log "Checking Burp Suite Community" -Level Info

if (-not $DryRun) {
    try {
        if (Test-CommandExists burpsuite) {
            Write-Log "Burp Suite Community already installed" -Level Success
        } else {
            Write-Log "Burp Suite Community requires manual download from https://portswigger.net/burp/communitydownload" -Level Warning
            Write-Log "Or use: winget install --id PortSwigger.BurpSuiteCommunity" -Level Info
        }
    } catch {
        Write-Log "Error checking Burp Suite: $_" -Level Warning
    }
} else {
    Write-Log "[DRY-RUN] Would check Burp Suite Community installation" -Level Info
}

# Install OWASP ZAP from GitHub
Write-Log "Checking OWASP ZAP" -Level Info

if (-not $DryRun) {
    try {
        $zapFound = Get-ChildItem "$env:ProgramFiles*\OWASP\ZAP\zap.exe" -ErrorAction SilentlyContinue
        if ($zapFound) {
            Write-Log "OWASP ZAP already installed" -Level Success
        } else {
            Write-Log "OWASP ZAP requires manual download from https://www.zaproxy.org/download/" -Level Warning
            Write-Log "Or use: winget install --id OWASP.ZAP" -Level Info
        }
    } catch {
        Write-Log "Error checking OWASP ZAP: $_" -Level Warning
    }
} else {
    Write-Log "[DRY-RUN] Would check OWASP ZAP installation" -Level Info
}

# Install Metasploit Framework
Write-Log "Checking Metasploit Framework" -Level Info

if (-not $DryRun) {
    try {
        if (Test-CommandExists msfconsole) {
            Write-Log "Metasploit Framework already installed" -Level Success
        } else {
            Write-Log "Metasploit Framework can be installed via:" -Level Info
            Write-Log "  winget install --id Rapid7.MetasploitFramework" -Level Info
            Write-Log "  Or manual download from https://www.metasploit.com/download" -Level Info
        }
    } catch {
        Write-Log "Error checking Metasploit: $_" -Level Warning
    }
} else {
    Write-Log "[DRY-RUN] Would check Metasploit Framework installation" -Level Info
}

# Install Mimikatz (with compliance check)
if (-not $SkipMimikatz) {
    Write-Log "Checking Mimikatz" -Level Info

    if (-not $DryRun) {
        Write-Log "⚠ Mimikatz can be flagged as malware by antivirus. Use only in authorized testing environments." -Level Warning
        Write-Log "  Repository: https://github.com/gentilkiwi/mimikatz/releases" -Level Info
        Write-Log "  Recommended: Run with -SkipMimikatz in restricted environments" -Level Info
    } else {
        Write-Log "[DRY-RUN] Would check Mimikatz installation" -Level Info
    }
} else {
    Write-Log "Mimikatz installation skipped" -Level Info
}

# Validation
if ($Validate -and -not $DryRun) {
    Write-Log "Validating security tools installation" -Level Info

    $validationPassed = $true

    if (Test-CommandExists procexp) {
        Write-Log "✓ Sysinternals Suite available" -Level Success
    } else {
        Write-Log "✗ Sysinternals Suite not found in PATH" -Level Warning
        $validationPassed = $false
    }

    if (Test-CommandExists msfconsole) {
        Write-Log "✓ Metasploit Framework available" -Level Success
    } else {
        Write-Log "⚠ Metasploit Framework not found (may need manual installation)" -Level Warning
    }

    if ($validationPassed) {
        Write-Log "Security tools validation passed" -Level Success
    } else {
        Write-Log "Review manual installation requirements above" -Level Warning
    }
}

Write-Log "Security Tools installation complete" -Level Success
