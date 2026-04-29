<#
.SYNOPSIS
    Install essential network analysis and debugging tools

.DESCRIPTION
    Installs network utilities via winget:
    - Wireshark — packet capture and analysis
    - Nmap — network reconnaissance and scanning
    - Ncat — netcat-compatible tool for port scanning/listening
    - tcpdump — command-line packet capture
    - curl/wget — HTTP/file download utilities

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

Write-Log "Starting Network Tools installation" -Level Info

$tools = @(
    @{ PackageId = 'Wireshark.Wireshark'; Name = 'Wireshark' },
    @{ PackageId = 'Nmap.Nmap'; Name = 'Nmap' },
    @{ PackageId = 'Ncat'; Name = 'Ncat' },
    @{ PackageId = 'Tcpdump.Tcpdump'; Name = 'tcpdump' },
    @{ PackageId = 'curl.curl'; Name = 'curl' },
    @{ PackageId = 'GnuWin32.Wget'; Name = 'wget' }
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

# Validation
if ($Validate -and -not $DryRun) {
    Write-Log "Validating network tools installation" -Level Info

    $validationPassed = $true

    $cmdValidations = @(
        @{ Command = 'wireshark'; Tool = 'Wireshark' },
        @{ Command = 'nmap'; Tool = 'Nmap' },
        @{ Command = 'ncat'; Tool = 'Ncat' },
        @{ Command = 'tcpdump'; Tool = 'tcpdump' },
        @{ Command = 'curl'; Tool = 'curl' },
        @{ Command = 'wget'; Tool = 'wget' }
    )

    foreach ($validation in $cmdValidations) {
        if (Test-CommandExists $validation.Command) {
            Write-Log "✓ $($validation.Tool) available in PATH" -Level Success
        } else {
            Write-Log "✗ $($validation.Tool) not found in PATH (may need shell restart)" -Level Warning
            $validationPassed = $false
        }
    }

    if ($validationPassed) {
        Write-Log "Network tools validation passed" -Level Success
    } else {
        Write-Log "Some network tools could not be validated. Restart PowerShell to update PATH." -Level Warning
    }
}

Write-Log "Network Tools installation complete" -Level Success
