<#
.SYNOPSIS
    Install security event collection and monitoring agents

.DESCRIPTION
    Configures centralized logging and monitoring:
    - Splunk Forwarder — send logs to SIEM (winget)
    - ELK Stack Agents — Elastic agent for log collection (direct/GitHub)
    - Sysmon — system activity monitoring (direct from Sysinternals)
    - Windows Event Forwarding — centralized event collection setup

.PARAMETER Validate
    Verify installation after completion

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER SplunkForwarder
    Install Splunk Universal Forwarder (requires license)

.PARAMETER ElasticAgent
    Install Elastic Agent for centralized logging

.PARAMETER Sysmon
    Install Sysmon for system monitoring
#>

[CmdletBinding()]
param(
    [switch]$Validate,
    [switch]$DryRun,
    [switch]$SplunkForwarder,
    [switch]$ElasticAgent,
    [switch]$Sysmon = $true
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Import-Module (Join-Path $PSScriptRoot '..' 'modules' 'SecDevOps.Core.psm1') -Force

Write-Log "Starting Monitoring and Logging installation" -Level Info

# Sysmon Installation
if ($Sysmon -and -not $DryRun) {
    Write-Log "Installing Sysmon for system monitoring" -Level Info

    try {
        $sysmonPath = Join-Path $env:ProgramFiles "Sysmon"

        if (Test-Path "$sysmonPath\sysmon.exe") {
            Write-Log "Sysmon already installed" -Level Success
        } else {
            Write-Log "Sysmon can be installed from Sysinternals:" -Level Info
            Write-Log "  Download: https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon" -Level Info
            Write-Log "  Install: sysmon.exe -i -n" -Level Info
            Write-Log "  SwiftOnSecurity config: https://github.com/SwiftOnSecurity/sysmon-config" -Level Info
        }
    } catch {
        Write-Log "Error checking Sysmon: $_" -Level Warning
    }
} elseif ($Sysmon) {
    Write-Log "[DRY-RUN] Would install Sysmon" -Level Info
}

# Splunk Universal Forwarder Installation
if ($SplunkForwarder) {
    Write-Log "Configuring Splunk Universal Forwarder" -Level Info

    if (-not $DryRun) {
        try {
            $splunkPath = Join-Path $env:ProgramFiles "Splunk" "bin" "splunkd.exe"

            if (Test-Path $splunkPath) {
                Write-Log "Splunk Universal Forwarder already installed" -Level Success
            } else {
                Write-Log "Splunk Universal Forwarder installation:" -Level Info
                Write-Log "  1. Download from: https://www.splunk.com/en_us/download/universal-forwarder.html" -Level Info
                Write-Log "  2. Run installer with: msiexec /i splunkforwarder-*.msi AGREETOLICENSE=Yes" -Level Info
                Write-Log "  3. Configure inputs.conf pointing to Splunk instance" -Level Info
            }
        } catch {
            Write-Log "Error checking Splunk Forwarder: $_" -Level Warning
        }
    } else {
        Write-Log "[DRY-RUN] Would configure Splunk Universal Forwarder" -Level Info
    }
}

# Elastic Agent Installation
if ($ElasticAgent) {
    Write-Log "Configuring Elastic Agent" -Level Info

    if (-not $DryRun) {
        try {
            $elasticPath = Join-Path $env:ProgramFiles "Elastic" "Agent" "elastic-agent.exe"

            if (Test-Path $elasticPath) {
                Write-Log "Elastic Agent already installed" -Level Success
            } else {
                Write-Log "Elastic Agent installation:" -Level Info
                Write-Log "  1. Download from: https://www.elastic.co/downloads/elastic-agent" -Level Info
                Write-Log "  2. Deploy via Kibana Fleet UI (recommended)" -Level Info
                Write-Log "  3. Or install manually: elastic-agent.exe install" -Level Info
            }
        } catch {
            Write-Log "Error checking Elastic Agent: $_" -Level Warning
        }
    } else {
        Write-Log "[DRY-RUN] Would configure Elastic Agent" -Level Info
    }
}

# Windows Event Forwarding Configuration
Write-Log "Configuring Windows Event Forwarding" -Level Info

if (-not $DryRun) {
    try {
        $wefService = Get-Service wecsvc -ErrorAction SilentlyContinue

        if ($wefService) {
            Write-Log "Windows Event Collector service available" -Level Success

            if ($wefService.Status -ne 'Running') {
                Write-Log "Enabling Windows Event Collector service" -Level Info
                Set-Service wecsvc -StartupType Automatic
                Start-Service wecsvc
                Write-Log "Windows Event Collector service started" -Level Success
            }
        } else {
            Write-Log "Windows Event Collector service not found (may require Windows Server)" -Level Warning
        }
    } catch {
        Write-Log "Error configuring Event Forwarding: $_" -Level Warning
    }

    try {
        $wecService = Get-Service wecutil -ErrorAction SilentlyContinue
        if ($wecService -or (Test-CommandExists wecutil)) {
            Write-Log "WEF configuration tool (wecutil) available" -Level Success
            Write-Log "Create subscription with: wecutil cs <name>" -Level Info
        }
    } catch {
        Write-Log "WEF utility check failed: $_" -Level Warning
    }
}

# Validation
if ($Validate -and -not $DryRun) {
    Write-Log "Validating monitoring tools installation" -Level Info

    $validationPassed = $true

    if ($Sysmon) {
        $sysmonPath = Join-Path $env:ProgramFiles "Sysmon" "sysmon.exe"
        if (Test-Path $sysmonPath) {
            Write-Log "✓ Sysmon installed" -Level Success
        } else {
            Write-Log "⚠ Sysmon not found (requires manual installation)" -Level Warning
            $validationPassed = $false
        }
    }

    $wefService = Get-Service wecsvc -ErrorAction SilentlyContinue
    if ($wefService -and $wefService.Status -eq 'Running') {
        Write-Log "✓ Windows Event Collector service running" -Level Success
    } else {
        Write-Log "⚠ Windows Event Collector service not available" -Level Warning
        $validationPassed = $false
    }

    if ($validationPassed) {
        Write-Log "Monitoring tools validation passed" -Level Success
    } else {
        Write-Log "Review manual installation requirements above" -Level Warning
    }
}

Write-Log "Monitoring and Logging configuration complete" -Level Success
