# =============================================================================
# 01-Enable-WindowsFeatures.ps1
# Run as Administrator — enables WSL2, Hyper-V, and Virtual Machine Platform
# REBOOT REQUIRED after completion
# =============================================================================

#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Done { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }

Write-Step "Enabling WSL (Windows Subsystem for Linux)..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

Write-Step "Enabling Virtual Machine Platform..."
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Write-Step "Enabling Hyper-V..."
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V /all /norestart

Write-Step "Enabling Hyper-V Management Tools..."
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-Tools-All /all /norestart

Write-Step "Enabling Windows Hypervisor Platform..."
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart

Write-Step "Enabling Containers feature..."
dism.exe /online /enable-feature /featurename:Containers /all /norestart

Write-Done "All Windows features enabled."
Write-Warn "REBOOT REQUIRED — run 02-PostReboot-Setup.ps1 after restart."

Read-Host "Press Enter to reboot now, or Ctrl+C to reboot manually"
Restart-Computer -Force