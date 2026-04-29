<#
.SYNOPSIS
    SecDevOps.Core - Common utilities and helper functions

.DESCRIPTION
    Reusable PowerShell module providing common utilities for all installation scripts.
#>

# Verify admin privileges
function Assert-Administrator {
    [CmdletBinding()]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]$identity

    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script requires administrator privileges. Please run PowerShell as Administrator."
    }
}

# Check if a command exists
function Test-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command
    )

    $null = Get-Command $Command -ErrorAction SilentlyContinue
    $?
}

# Install via winget
function Install-ViaPsGallery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [string]$Repository = 'PSGallery'
    )

    Write-Verbose "Installing $ModuleName from $Repository"
    
    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Install-Module -Name $ModuleName -Repository $Repository -Force -AllowClobber
        Write-Host "Installed: $ModuleName" -ForegroundColor Green
    } else {
        Write-Host "Already installed: $ModuleName" -ForegroundColor Yellow
    }
}

# Install via winget
function Install-ViaWinget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,
        [string]$Version
    )

    Write-Verbose "Installing $PackageId via winget"
    
    if (Test-CommandExists winget) {
        $args = @('install', '--id', $PackageId, '--accept-source-agreements', '--accept-package-agreements')
        if ($Version) { $args += '--version', $Version }
        
        & winget @args
        Write-Host "Installed: $PackageId" -ForegroundColor Green
    } else {
        throw "winget not found. Install Windows Package Manager from Microsoft Store."
    }
}

# Download and extract from GitHub release
function Install-FromGitHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        [Parameter(Mandatory)]
        [string]$Repo,
        [string]$AssetPattern,
        [string]$DownloadPath = "$env:TEMP\secdevops-downloads"
    )

    Write-Verbose "Downloading $Owner/$Repo from GitHub"
    
    if (-not (Test-Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath | Out-Null
    }

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        
        if (-not $asset) {
            throw "No matching asset found for pattern: $AssetPattern"
        }

        $output = Join-Path $DownloadPath $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $output
        Write-Host "Downloaded: $($asset.name)" -ForegroundColor Green
        
        return $output
    } catch {
        Write-Error "Failed to download from GitHub: $_"
        throw
    }
}

# Log execution
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = @{
        'Info'    = 'Cyan'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Success' = 'Green'
    }

    Write-Host "[$timestamp] $Message" -ForegroundColor $color[$Level]
}

Export-ModuleMember -Function @(
    'Assert-Administrator',
    'Test-CommandExists',
    'Install-ViaPsGallery',
    'Install-ViaWinget',
    'Install-FromGitHub',
    'Write-Log'
)
