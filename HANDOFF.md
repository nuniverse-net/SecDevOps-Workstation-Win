# HANDOFF.md — SecDevOps Workstation / BLUR.Tools.Installer

> Written: 2026-05-02. For whoever picks this up next — human or AI.

---

## Situation in One Paragraph

This repo was originally a Windows-only workstation setup suite (Phase 1). That work is
done but was always intended to be replaced. The real goal — a cross-platform, JSON-driven
PowerShell 7 module called **`BLUR.Tools.Installer`** — has never been started. A full
spec exists at `docs/claude-code-prompt.md`, a clean CLAUDE.md has been written, and the
project has been audited. The Phase 1 scripts are preserved as read-only reference material.
**The next session should begin building `BLUR.Tools.Installer` from scratch, step 1.**

---

## What Was Done in This Session

| # | Action | Result |
|---|--------|--------|
| 1 | Read all source files (`scripts/`, `modules/`, `docs/`, `secdevops.ps1`) | Full picture of Phase 1 |
| 2 | Read `docs/claude-code-prompt.md` | Confirmed Phase 2 spec is complete and authoritative |
| 3 | Audited project against original intent | Score: 13/25 — clean restart recommended |
| 4 | Wrote `CLAUDE.md` | Single source of truth, committed and pushed |

Nothing was deleted. Nothing was refactored. The working tree is clean.

---

## What Has NOT Been Built Yet (the actual work)

Everything in the `BLUR.Tools.Installer` column is zero percent done:

```
BLUR.Tools.Installer/          ← does not exist
manifests/tools.json           ← does not exist
manifests/schemas/             ← does not exist
profiles/                      ← does not exist
Install-Workstation.ps1        ← does not exist
Configure-Workstation.ps1      ← does not exist
Update-Workstation.ps1         ← does not exist
Test-Workstation.ps1           ← does not exist
bootstrap.ps1                  ← does not exist
bootstrap.sh                   ← does not exist
Any Pester tests               ← do not exist
docs/adding-a-tool.md          ← does not exist
```

---

## Where to Start Next

**Step 1 of 15 from `CLAUDE.md`:** Scaffold the project structure.

That means creating the directory tree and empty/stub files so the module is importable
before any real logic exists:

```
BLUR.Tools.Installer/
├── BLUR.Tools.Installer.psd1      ← New-ModuleManifest, RootModule = psm1
├── BLUR.Tools.Installer.psm1      ← dot-sources all Public/*.ps1 + Private/*.ps1
├── Public/                        ← 8 empty .ps1 stubs
├── Private/                       ← 14 empty .ps1 stubs
└── Tests/
    ├── BLUR.Tools.Installer.Tests.ps1
    └── fixtures/test-manifest.json
```

Then proceed in order: `Resolve-Platform` → `Get-BlurManifest` → `Write-BlurLog` →
package manager invokers → `Install-BlurTool` → etc. **Do not skip ahead or batch steps.**

The full 15-step sequence is in `CLAUDE.md § Implementation Order`.

---

## Key Files to Read Before Writing Code

| File | Why |
|------|-----|
| `docs/claude-code-prompt.md` | **Primary spec** — defines every interface, JSON schema, function signature |
| `CLAUDE.md` | Distilled rules, architecture, known bugs |
| `scripts/02-PostReboot-Setup.ps1` | Winget package IDs for dev tools |
| `scripts/03-Configure-DevEnvironment.ps1` | PS modules, git config, VS Code extensions |
| `scripts/04-Configure-WSL.ps1` | WSL config auto-calculation logic (50% RAM, cores-2) |
| `scripts/05-Workstation-Hardening.ps1` | SSH, firewall, Defender config values |
| `scripts/07-Hyper-V-Setup.ps1` | Hyper-V VM creation logic |
| `scripts/08-Update-All.ps1` | Update patterns to preserve |
| `scripts/04b-WSL-DevEnvironment.sh` | Linux-side setup to be absorbed |

---

## Bugs to Avoid When Absorbing Phase 1 Code

| Location | Bug | Fix in Phase 2 |
|----------|-----|----------------|
| `scripts/Install-DevTools.ps1:76` | Hardcoded `user.email "nuno@bluerush.com"` | `valueFrom: "prompt"` in tools.json configure block |
| `secdevops.ps1:104` | `if ($ComponentList -eq 'all')` — wrong operator for arrays | `if ($ComponentList -contains 'all')` |
| `scripts/01-08-*.ps1` | `Write-Step`/`Write-Done` inline helpers | Replace with `Write-BlurLog` |

---

## Repository State

```
Branch:   claude/clarify-task-AdJYv
Remote:   nuniverse-net/secdevops-workstation-win
Last commit: Add CLAUDE.md: full project audit and single source of truth
Tree:     clean — nothing uncommitted
```

---

## Decisions Already Made (do not re-litigate)

- Module name is **`BLUR.Tools.Installer`** — fixed, not negotiable
- PowerShell 7.2+ only — `$IsWindows` / `$IsLinux` / `$IsMacOS` built-ins everywhere
- `scripts/` directory is read-only reference — do not modify or delete it
- Phase 1 (`secdevops.ps1`, `Install-*.ps1`) will be superseded, not extended
- `bootstrap.sh` is the only bash file allowed; all other logic is PowerShell
- Install and Configure are always separate concerns; they are never combined in one function
- All public functions must support `-WhatIf` via `ShouldProcess`
- All Install-* functions return a structured `[PSCustomObject]`, never a string

---

## Out of Scope (intentional omissions)

- GUI / TUI dashboard — mentioned in the original README Phase 2 roadmap but not in the spec; omit unless explicitly requested
- Rollback / uninstall — not in spec; add to notes field in manifest if needed later
- Windows 10 support — Windows 11 / Server 2022+ only per spec
- PowerShell 5.x compatibility — explicitly excluded
