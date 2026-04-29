<#
.SYNOPSIS
    SecDevOps Windows Workstation CLI tool - modular security hardening and tool installation

.DESCRIPTION
    Command-line interface for managing SecDevOps workstation components.
    Supports installing, checking status, and managing individual tools.

.EXAMPLE
    .\secdevops.ps1 install os-hardening
    .\secdevops.ps1 list
    .\secdevops.ps1 status

.PARAMETER Command
    The command to execute (install, list, status, help)

.PARAMETER Component
    The component to operate on (os-hardening, network-tools, etc.)

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Validate
    Verify installation after running
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'list', 'status', 'help', 'version')]
    [string]$Command = 'help',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Import core module
$ModulePath = Join-Path $PSScriptRoot 'modules' 'SecDevOps.Core.psm1'
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
}

# Available components
$Components = @{
    'os-hardening'      = @{ Script = 'Install-OSHardening.ps1'; Description = 'Windows Defender, Firewall, UAC, BitLocker' }
    'network-tools'     = @{ Script = 'Install-NetworkTools.ps1'; Description = 'Wireshark, Nmap, netcat, tcpdump, curl' }
    'development'       = @{ Script = 'Install-DevTools.ps1'; Description = 'Git, Node.js, Python, PowerShell 7+, VS Code, Docker' }
    'security-tools'    = @{ Script = 'Install-SecurityTools.ps1'; Description = 'Burp Suite, OWASP ZAP, Metasploit, Mimikatz, Sysinternals' }
    'monitoring'        = @{ Script = 'Install-Monitoring.ps1'; Description = 'Splunk Forwarder, ELK agents, Sysmon, Event Forwarding' }
}

function Show-Help {
    Write-Host @"
SecDevOps Windows Workstation CLI v1.0.0

USAGE:
  secdevops.ps1 <command> [component] [options]

COMMANDS:
  install       Install a component
  list          List available components
  status        Check installation status
  help          Show this help message
  version       Show version

EXAMPLES:
  secdevops.ps1 install os-hardening
  secdevops.ps1 install os-hardening network-tools
  secdevops.ps1 install all
  secdevops.ps1 list
  secdevops.ps1 status

OPTIONS:
  --dry-run     Show what would be done without making changes
  --validate    Verify installation after running

For detailed component information, see docs/COMPONENTS.md
"@
}

function Show-Version {
    Write-Host "SecDevOps Windows Workstation CLI v1.0.0"
}

function Show-List {
    Write-Host "`nAvailable Components:`n"
    $Components.GetEnumerator() | ForEach-Object {
        Write-Host "  $($_.Key)" -ForegroundColor Cyan
        Write-Host "    $($_.Value.Description)" -ForegroundColor Gray
    }
    Write-Host "`nUse 'secdevops.ps1 install <component>' to install`n"
}

function Invoke-Install {
    param(
        [string[]]$ComponentList,
        [switch]$DryRun,
        [switch]$Validate
    )

    if ($ComponentList -eq 'all') {
        $ComponentList = $Components.Keys
    }

    foreach ($comp in $ComponentList) {
        if (-not $Components.ContainsKey($comp)) {
            Write-Error "Unknown component: $comp"
            continue
        }

        $script = Join-Path $PSScriptRoot 'scripts' $Components[$comp].Script
        if (-not (Test-Path $script)) {
            Write-Warning "Script not found: $script"
            continue
        }

        Write-Host "`nInstalling: $comp" -ForegroundColor Cyan
        
        if ($DryRun) {
            Write-Host "[DRY-RUN] Would execute: $script" -ForegroundColor Yellow
        } else {
            & $script -Validate:$Validate
        }
    }
}

function Show-Status {
    Write-Host "`nInstallation Status:`n"
    
    foreach ($comp in $Components.Keys) {
        $script = Join-Path $PSScriptRoot 'scripts' $Components[$comp].Script
        if (Test-Path $script) {
            Write-Host "  $comp" -ForegroundColor Green
        } else {
            Write-Host "  $comp" -ForegroundColor Red -NoNewline
            Write-Host " (script not found)"
        }
    }
    Write-Host ""
}

# Parse command
switch ($Command) {
    'help' { Show-Help }
    'version' { Show-Version }
    'list' { Show-List }
    'status' { Show-Status }
    'install' {
        $dryRun = $Arguments -contains '--dry-run'
        $validate = $Arguments -contains '--validate'
        $comps = $Arguments | Where-Object { $_ -notlike '--*' }
        
        if (-not $comps) {
            Write-Error "No component specified. Use 'secdevops.ps1 list' to see available components."
            exit 1
        }
        
        Invoke-Install -ComponentList $comps -DryRun:$dryRun -Validate:$validate
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
