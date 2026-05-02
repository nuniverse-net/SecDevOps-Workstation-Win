# CLAUDE.md — SecDevOps Workstation / BLUR.Tools.Installer

> Single source of truth. Last audited: 2026-05-02.

---

## What This Project Is

A cross-platform workstation setup framework built as a PowerShell 7 module named
**`BLUR.Tools.Installer`**. It installs, configures, updates, and verifies development
and security tools on Windows, Linux (apt), and macOS (brew) from a JSON manifest.

The full design spec lives in `docs/claude-code-prompt.md`. Read it before writing
any code — it defines every interface, JSON schema, function signature, and
implementation ordering decision.

---

## Current State (as of audit)

### What exists and is usable as reference material

| Path | Purpose | Keep? |
|------|---------|-------|
| `scripts/01-08-*.ps1` | Original numbered setup scripts — canonical source for tool IDs, package IDs, config logic | **Yes — read-only reference** |
| `scripts/04b-WSL-DevEnvironment.sh` | WSL dev env setup — to be absorbed into module | **Yes — read-only reference** |
| `scripts/Install-*.ps1` | Phase 1 Windows-only scripts — partially duplicate the numbered scripts | Reference only, will be superseded |
| `secdevops.ps1` | Phase 1 CLI — will be replaced by `Install-Workstation.ps1` | Reference only |
| `modules/SecDevOps.Core.psm1` | Phase 1 utility module — some helpers reusable | Cherry-pick into Private/ |
| `docs/claude-code-prompt.md` | **Complete Phase 2 spec — authoritative** | **Yes — primary spec** |
| `docs/COMPONENTS.md` | Component reference | Yes |

### What does NOT exist yet (needs to be built)

- `BLUR.Tools.Installer/` module (Public/, Private/, Tests/)
- `manifests/tools.json` + JSON schema
- `profiles/profiles.json` + named profile files
- `Install-Workstation.ps1`, `bootstrap.ps1`, `bootstrap.sh`
- `Configure-Workstation.ps1`, `Update-Workstation.ps1`, `Test-Workstation.ps1`
- Any Pester tests

---

## Architecture

```
blur-tools-installer/          ← project root (rename from SecDevOps-Workstation-Win eventually)
├── Install-Workstation.ps1    # main entry point (replaces secdevops.ps1)
├── Configure-Workstation.ps1
├── Update-Workstation.ps1
├── Test-Workstation.ps1
├── bootstrap.ps1              # Windows zero-dep bootstrapper
├── bootstrap.sh               # Linux/macOS: apt-install pwsh → exec pwsh
│
├── BLUR.Tools.Installer/
│   ├── BLUR.Tools.Installer.psd1
│   ├── BLUR.Tools.Installer.psm1    # dot-sources all Public/ + Private/
│   ├── Public/
│   │   ├── Install-BlurGroup.ps1
│   │   ├── Install-BlurTool.ps1
│   │   ├── Invoke-BlurConfiguration.ps1
│   │   ├── Test-BlurTool.ps1
│   │   ├── Update-BlurTool.ps1
│   │   ├── Update-BlurGroup.ps1
│   │   ├── Get-BlurManifest.ps1
│   │   └── Invoke-BlurWslSetup.ps1
│   ├── Private/
│   │   ├── Resolve-Platform.ps1
│   │   ├── Invoke-WingetInstall.ps1
│   │   ├── Invoke-AptInstall.ps1
│   │   ├── Invoke-BrewInstall.ps1
│   │   ├── Invoke-ScriptInstall.ps1
│   │   ├── Invoke-BinaryInstall.ps1
│   │   ├── Invoke-NpmInstall.ps1
│   │   ├── Invoke-PipxInstall.ps1
│   │   ├── Invoke-CargoInstall.ps1
│   │   ├── Invoke-GoInstall.ps1
│   │   ├── Invoke-WindowsFeature.ps1
│   │   ├── Invoke-WslSetup.ps1
│   │   ├── Write-BlurLog.ps1
│   │   └── Get-LatestGitHubRelease.ps1
│   └── Tests/
│       ├── BLUR.Tools.Installer.Tests.ps1
│       └── fixtures/test-manifest.json
│
├── manifests/
│   ├── tools.json
│   ├── schemas/blur-tools-manifest.schema.json
│   └── overrides/README.md
│
├── profiles/
│   ├── profiles.json          # minimal | developer | devops | security | windows-wsl
│   └── *.json                 # one file per profile
│
├── scripts/                   # PRESERVED — read-only reference, not executed by module
└── docs/
    ├── claude-code-prompt.md  # PRIMARY SPEC — read this first
    ├── adding-a-tool.md
    ├── adding-a-profile.md
    └── cross-platform-notes.md
```

---

## Non-Negotiables

1. **PowerShell 7.2+ only** — use `$IsWindows`/`$IsLinux`/`$IsMacOS`, never `[System.Environment]::OSVersion`
2. **JSON drives everything** — no tool IDs, package IDs, or config values hardcoded in `.ps1` files
3. **Install and Configure are always separate** — `Install-BlurTool git` never runs git config; `Invoke-BlurConfiguration git` does
4. **`-WhatIf` on every public function** — implement `ShouldProcess` correctly
5. **Module importable on a clean machine** with only PS7 + internet. No other prerequisites.
6. **Cross-platform paths** — `Join-Path`, `$HOME`, `$env:TEMP` only. Never hardcode `/home/user` or `C:\Users`
7. **All apt operations use `sudo`** — detect root, drop sudo if already root, fail clearly if no sudo rights
8. **Return objects, not strings** — every Install-* function returns a `[PSCustomObject]` with Tool/Group/Platform/Status/Version/Duration/Error
9. **No bash logic** beyond `bootstrap.sh` (which only installs pwsh then hands off)
10. **Module name `BLUR.Tools.Installer` is fixed**

---

## Implementation Order

Follow this sequence exactly — each step builds on the last:

1. Scaffold project structure (empty files, module manifest, psm1 dot-source stub)
2. `Resolve-Platform` + tests — foundation for everything
3. `Get-BlurManifest` with JSON Schema validation
4. `Write-BlurLog`
5. Package manager private functions: `Invoke-WingetInstall`, `Invoke-AptInstall`, `Invoke-BrewInstall` (with mocks)
6. `Install-BlurTool` (single tool — calls resolver + correct package manager)
7. `Test-BlurTool`
8. `Install-BlurGroup` (iterates tools, respects `dependsOn`)
9. `Invoke-BlurConfiguration` + all config step types
10. Full `tools.json` manifest — absorb all tools from `scripts/01-08` + taxonomy in spec
11. `profiles.json` + named profile files
12. Entry-point scripts (`Install-Workstation.ps1`, etc.)
13. `bootstrap.ps1` + `bootstrap.sh`
14. Pester tests for all public functions
15. `docs/` — `adding-a-tool.md` is most important

---

## Key Design Details

### Install result object (every Install-* must return this)
```powershell
[PSCustomObject]@{
    Tool     = <string>
    Group    = <string>
    Platform = <string>         # 'Windows' | 'Linux' | 'macOS'
    Status   = <string>         # 'Installed' | 'AlreadyInstalled' | 'Failed' | 'Skipped' | 'WhatIf'
    Version  = <string>
    Duration = <TimeSpan>
    Error    = <string>         # $null on success
}
```

### Write-BlurLog signature
```powershell
Write-BlurLog -Level Step|Done|Warn|Fail|Info -Message <string> [-Tool <string>] [-Group <string>]
# Writes to host (coloured) AND $env:TEMP\BLUR.Tools.Installer\<timestamp>.log
# Log format: [ISO8601] [LEVEL] [tool/group] message
```

### Invoke-WingetInstall behaviour
- Always pass `--accept-package-agreements --accept-source-agreements`
- Exit code `-1978335189` = already installed → treat as success
- On failure: emit structured warning object, do not throw by default

### Invoke-AptInstall behaviour
- `sudo apt-get install -y -qq` (drop `-qq` when `-Verbose`)
- Handle `aptRepo` pre-install (key + repo line + apt update) from manifest
- Detect root: if `id -u` = 0, drop sudo prefix

### Windows-specific extras
- WSL setup driven by `windowsExtras.wslConfig` in profile — `memory: "auto"` = 50% RAM, `processors: "auto"` = total_cores - 2
- Windows Features via DISM — collect all reboot-required features, warn once at end, single reboot prompt
- Hyper-V VM creation via `New-BlurHyperVDevVm`

---

## Known Bugs in Existing Code (fix before reuse)

- `scripts/Install-DevTools.ps1:76` — hardcoded `git config --global user.email "nuno@bluerush.com"`. Must become a `valueFrom: "prompt"` config step in `tools.json`.
- `secdevops.ps1:104` — `if ($ComponentList -eq 'all')` should be `if ($ComponentList -contains 'all')` (wrong equality operator for arrays).
- Numbered scripts use inline helper functions (`Write-Step`, `Write-Done`) instead of `Write-BlurLog` — absorb into the module logger.

---

## Testing

Use **Pester 5**. Required test coverage:
- `Resolve-Platform` returns correct value on current host
- `Get-BlurManifest` loads and validates schema
- `Install-BlurTool -WhatIf` returns WhatIf result without invoking any package manager
- `Test-BlurTool` returns correct structure for git (known installed) and `fake-tool-xyz` (fail case)
- Mock tests for all three package manager invokers — verify correct args from manifest entries
- Schema validation: every tool in `tools.json` has a valid `verify` block

---

## Branch

Active development branch: `claude/clarify-task-AdJYv`
Remote: `nuniverse-net/secdevops-workstation-win`
