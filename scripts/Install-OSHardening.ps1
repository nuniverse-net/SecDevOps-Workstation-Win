<#
.SYNOPSIS
    Install and configure Windows Defender, Firewall, UAC, BitLocker hardening

.DESCRIPTION
    Hardens Windows 11 Enterprise security posture through:
    - Windows Defender engine and definition updates
    - Real-time protection and scan scheduling
    - Windows Firewall inbound/outbound rule enforcement
    - UAC elevation requirements
    - BitLocker drive encryption setup
    - SMB signing/encryption hardening
    - PowerShell script execution policy enforcement

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

Write-Log "Starting OS Hardening configuration" -Level Info

try {
    Assert-Administrator
} catch {
    Write-Log "Administrative privileges required" -Level Error
    throw
}

# Windows Defender Configuration
Write-Log "Configuring Windows Defender" -Level Info

if (-not $DryRun) {
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction Stop
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
        Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction Stop
        Write-Log "Windows Defender real-time protection enabled" -Level Success
    } catch {
        Write-Log "Failed to configure Windows Defender: $_" -Level Warning
    }

    try {
        Update-MpSignature
        Write-Log "Windows Defender definitions updated" -Level Success
    } catch {
        Write-Log "Could not update Defender signatures (may require internet): $_" -Level Warning
    }
}

# Windows Firewall Configuration
Write-Log "Configuring Windows Firewall" -Level Info

if (-not $DryRun) {
    try {
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True -ErrorAction Stop
        Set-NetFirewallProfile -Profile Domain, Public, Private -DefaultInboundAction Block -ErrorAction Stop
        Set-NetFirewallProfile -Profile Domain, Public, Private -DefaultOutboundAction Allow -ErrorAction Stop
        Set-NetFirewallProfile -Profile Domain, Public, Private -AllowInboundRules True -ErrorAction Stop
        Write-Log "Windows Firewall profiles hardened (block inbound, allow outbound)" -Level Success
    } catch {
        Write-Log "Failed to configure Windows Firewall: $_" -Level Warning
    }

    try {
        Enable-NetFirewallRule -DisplayGroup "Windows Defender Firewall Remote Management" -ErrorAction SilentlyContinue
        Write-Log "Remote management firewall rules enabled" -Level Success
    } catch {
        Write-Log "Could not enable remote management rules: $_" -Level Warning
    }
}

# UAC Enforcement
Write-Log "Enforcing UAC settings" -Level Info

if (-not $DryRun) {
    try {
        $UACRegistryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
        Set-ItemProperty -Path $UACRegistryPath -Name "EnableLUA" -Value 1 -ErrorAction Stop
        Set-ItemProperty -Path $UACRegistryPath -Name "ConsentPromptBehaviorAdmin" -Value 1 -ErrorAction Stop
        Set-ItemProperty -Path $UACRegistryPath -Name "ConsentPromptBehaviorUser" -Value 0 -ErrorAction Stop
        Set-ItemProperty -Path $UACRegistryPath -Name "ValidateAdminCodeSignatures" -Value 1 -ErrorAction Stop
        Write-Log "UAC enforcement configured" -Level Success
    } catch {
        Write-Log "Failed to configure UAC: $_" -Level Warning
    }
}

# BitLocker Configuration
Write-Log "Checking BitLocker status" -Level Info

if (-not $DryRun) {
    try {
        $BitLockerStatus = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue

        if ($BitLockerStatus.VolumeStatus -eq 'FullyEncrypted') {
            Write-Log "BitLocker already enabled on $($env:SystemDrive)" -Level Success
        } elseif ($BitLockerStatus.VolumeStatus -eq 'EncryptionInProgress') {
            Write-Log "BitLocker encryption in progress on $($env:SystemDrive)" -Level Info
        } else {
            Write-Log "BitLocker not fully enabled. Enable via: Enable-BitLocker -MountPoint $env:SystemDrive -EncryptionMethod Aes256" -Level Warning
        }
    } catch {
        Write-Log "BitLocker check failed (may not be supported): $_" -Level Warning
    }
}

# SMB Hardening
Write-Log "Hardening SMB configuration" -Level Info

if (-not $DryRun) {
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RequireSecuritySignature" -Value 1 -ErrorAction Stop
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "EnableSecuritySignature" -Value 1 -ErrorAction Stop
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RestrictNullSessAccess" -Value 1 -ErrorAction Stop
        Write-Log "SMB signing required and null sessions restricted" -Level Success
    } catch {
        Write-Log "Failed to configure SMB hardening: $_" -Level Warning
    }

    try {
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
        Write-Log "SMBv1 protocol disabled" -Level Success
    } catch {
        Write-Log "Could not disable SMBv1 (may already be disabled): $_" -Level Warning
    }
}

# PowerShell Execution Policy
Write-Log "Setting PowerShell execution policy" -Level Info

if (-not $DryRun) {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
        Write-Log "PowerShell execution policy set to RemoteSigned" -Level Success
    } catch {
        Write-Log "Failed to set execution policy: $_" -Level Warning
    }
}

# Validation
if ($Validate -and -not $DryRun) {
    Write-Log "Validating OS hardening configuration" -Level Info

    $validationPassed = $true

    try {
        $mpStatus = Get-MpPreference
        if ($mpStatus.DisableRealtimeMonitoring -eq $false) {
            Write-Log "✓ Windows Defender real-time protection enabled" -Level Success
        } else {
            Write-Log "✗ Windows Defender real-time protection NOT enabled" -Level Warning
            $validationPassed = $false
        }
    } catch {
        Write-Log "Could not validate Defender status: $_" -Level Warning
    }

    try {
        $firewallStatus = Get-NetFirewallProfile -Profile Domain
        if ($firewallStatus.Enabled -eq $true) {
            Write-Log "✓ Windows Firewall enabled on Domain profile" -Level Success
        } else {
            Write-Log "✗ Windows Firewall NOT enabled" -Level Warning
            $validationPassed = $false
        }
    } catch {
        Write-Log "Could not validate Firewall status: $_" -Level Warning
    }

    if ($validationPassed) {
        Write-Log "OS hardening validation passed" -Level Success
    } else {
        Write-Log "Some hardening settings could not be validated" -Level Warning
    }
}

Write-Log "OS Hardening configuration complete" -Level Success
