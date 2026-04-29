# =============================================================================
# 07-Hyper-V-Setup.ps1
# Run as Administrator — creates the DevNAT virtual switch and an optional
# Ubuntu dev VM. Run this only if you need full Hyper-V VMs in addition to WSL.
# =============================================================================

#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Done { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }

# ── Verify Hyper-V is running ─────────────────────────────────────────────────
if (-not (Get-Service -Name vmms -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' })) {
    Write-Warn "Hyper-V Virtual Machine Management service is not running."
    Write-Warn "Ensure 01-Enable-WindowsFeatures.ps1 was run and the system was rebooted."
    exit 1
}

# ── Create internal NAT switch ────────────────────────────────────────────────
Write-Step "Creating DevNAT internal virtual switch..."

$switchName = "DevNAT"
$natName    = "DevNATNetwork"
$natPrefix  = "192.168.100.0/24"
$gatewayIP  = "192.168.100.1"

if (-not (Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name $switchName -SwitchType Internal | Out-Null
    Write-Done "Virtual switch '$switchName' created."
} else {
    Write-Host "  [skip] Switch '$switchName' already exists." -ForegroundColor DarkGray
}

# Assign gateway IP to the new switch adapter
$ifIndex = (Get-NetAdapter | Where-Object { $_.Name -like "*$switchName*" }).ifIndex
if ($ifIndex -and -not (Get-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $gatewayIP -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -IPAddress $gatewayIP -PrefixLength 24 -InterfaceIndex $ifIndex | Out-Null
    Write-Done "Gateway IP $gatewayIP assigned to $switchName."
}

# Create NAT rule
if (-not (Get-NetNat -Name $natName -ErrorAction SilentlyContinue)) {
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $natPrefix | Out-Null
    Write-Done "NAT rule '$natName' created for $natPrefix."
} else {
    Write-Host "  [skip] NAT rule '$natName' already exists." -ForegroundColor DarkGray
}

# ── Optionally create a dev VM ─────────────────────────────────────────────────
Write-Host ""
$createVM = Read-Host "Create a new Ubuntu 24.04 dev VM? (y/N)"
if ($createVM -notmatch '^[Yy]') {
    Write-Done "Hyper-V network setup complete. Skipping VM creation."
    exit 0
}

# ── VM parameters ─────────────────────────────────────────────────────────────
$vmName     = Read-Host "VM name [DevVM-Ubuntu]"
if ([string]::IsNullOrWhiteSpace($vmName)) { $vmName = "DevVM-Ubuntu" }

$vmPath     = "C:\VMs"
$vhdPath    = "$vmPath\$vmName\$vmName.vhdx"
$vhdSizeGB  = 80

$isoPath = Read-Host "Path to Ubuntu 24.04 server ISO (e.g. C:\ISOs\ubuntu-24.04-server-amd64.iso)"
if (-not (Test-Path $isoPath)) {
    Write-Warn "ISO not found at: $isoPath"
    Write-Warn "Download from: https://ubuntu.com/download/server"
    Write-Warn "Create the VM manually or re-run with a valid ISO path."
    exit 1
}

# ── Create VM ─────────────────────────────────────────────────────────────────
Write-Step "Creating VM: $vmName..."

if (-not (Test-Path "$vmPath\$vmName")) {
    New-Item -ItemType Directory -Path "$vmPath\$vmName" | Out-Null
}

New-VM `
    -Name             $vmName `
    -Path             $vmPath `
    -Generation       2 `
    -MemoryStartupBytes 4GB `
    -SwitchName       $switchName | Out-Null

# VHD
Write-Step "Creating VHDX ($vhdSizeGB GB dynamic)..."
New-VHD -Path $vhdPath -SizeBytes ($vhdSizeGB * 1GB) -Dynamic | Out-Null
Add-VMHardDiskDrive -VMName $vmName -Path $vhdPath | Out-Null

# DVD / ISO
Add-VMDvdDrive -VMName $vmName -Path $isoPath | Out-Null

# CPU + Memory
Set-VMProcessor -VMName $vmName -Count 4
Set-VMMemory -VMName $vmName `
    -DynamicMemoryEnabled $true `
    -MinimumBytes 1GB `
    -StartupBytes 4GB `
    -MaximumBytes 8GB

# Secure Boot (required for Gen 2 + Ubuntu)
Set-VMFirmware -VMName $vmName `
    -EnableSecureBoot On `
    -SecureBootTemplate MicrosoftUEFICertificateAuthority

# Set DVD as first boot device
$dvd = Get-VMDvdDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -BootOrder $dvd, (Get-VMHardDiskDrive -VMName $vmName)

# Enable VM integration services
Enable-VMIntegrationService -VMName $vmName -Name "Guest Service Interface" -ErrorAction SilentlyContinue

Write-Done "VM '$vmName' created."
Write-Host ""
Write-Host "  To connect:  vmconnect localhost '$vmName'" -ForegroundColor Cyan
Write-Host "  To start:    Start-VM -Name '$vmName'" -ForegroundColor Cyan
Write-Host ""

$startNow = Read-Host "Start VM now? (y/N)"
if ($startNow -match '^[Yy]') {
    Start-VM -Name $vmName
    Start-Sleep -Seconds 2
    vmconnect localhost $vmName
}

Write-Done "Hyper-V setup complete."
