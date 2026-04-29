# Claude Code Prompt: Refactor to BLUR.Tools.Installer — Modular Cross-Platform Installer

## Mission

Refactor the existing Windows DevOps workstation setup scripts into a fully modular,
JSON-driven, cross-platform installation framework built on PowerShell 7.

The output is a PowerShell module named **`BLUR.Tools.Installer`** plus a companion set
of JSON manifests and thin entry-point scripts. The framework must run identically on:

- Windows 11 / Windows Server 2022+ (package manager: winget)
- Ubuntu / Debian Linux — including WSL2 (package manager: apt)
- macOS (package manager: brew)

The very first action on any Linux/Ubuntu target is to install PowerShell 7 via apt,
then hand off to the same PowerShell module used everywhere else. No bash-only logic
should exist outside of that bootstrap one-liner.

---

## Existing Scripts to Absorb

The following scripts are the starting point. Understand them fully before generating
any new code — all existing tool lists, IDs, configurations, and ordering decisions
must be preserved or explicitly justified if changed.

```
01-Enable-WindowsFeatures.ps1     # Windows-only: WSL, Hyper-V, Containers
02-PostReboot-Setup.ps1           # winget installs + WSL2 + Ubuntu bootstrap
03-Configure-DevEnvironment.ps1   # PS modules, Git, VS Code extensions, Docker
04-Configure-WSL.ps1              # .wslconfig tuning, copies 04b into WSL
04b-WSL-DevEnvironment.sh         # (TO BE ELIMINATED — absorbed into PS module)
05-Workstation-Hardening.ps1      # SSH, firewall, Defender, Hyper-V paths
06-Verify-Setup.ps1               # Verification / smoke tests
07-Hyper-V-Setup.ps1              # Optional: NAT switch + VM creation
08-Update-All.ps1                 # Monthly maintenance updater
```

---

## Required Deliverables

### 1. `BLUR.Tools.Installer` PowerShell Module

**Module root:** `BLUR.Tools.Installer/`

```
BLUR.Tools.Installer/
├── BLUR.Tools.Installer.psd1          # Module manifest
├── BLUR.Tools.Installer.psm1          # Root — dot-sources all Private + Public
├── Public/
│   ├── Install-BlurGroup.ps1          # Install an entire named group
│   ├── Install-BlurTool.ps1           # Install a single named tool
│   ├── Invoke-BlurConfiguration.ps1   # Run config steps for a tool/group
│   ├── Test-BlurTool.ps1              # Verify a tool is installed + working
│   ├── Update-BlurTool.ps1            # Update a single tool
│   ├── Update-BlurGroup.ps1           # Update an entire group
│   └── Get-BlurManifest.ps1           # Load + validate a manifest file
├── Private/
│   ├── Resolve-Platform.ps1           # Detect OS: Windows | Linux | macOS
│   ├── Invoke-WingetInstall.ps1       # Windows package install via winget
│   ├── Invoke-AptInstall.ps1          # Linux package install via apt
│   ├── Invoke-BrewInstall.ps1         # macOS package install via brew
│   ├── Invoke-ScriptInstall.ps1       # URL-based script installer (curl|sh pattern)
│   ├── Invoke-BinaryInstall.ps1       # Download + install binary from URL/GitHub release
│   ├── Invoke-NpmInstall.ps1          # npm global install
│   ├── Invoke-PipxInstall.ps1         # pipx install
│   ├── Invoke-CargoInstall.ps1        # cargo install
│   ├── Invoke-GoInstall.ps1           # go install
│   ├── Write-BlurLog.ps1              # Structured logging (step/done/warn/fail)
│   └── Get-LatestGitHubRelease.ps1    # Helper: fetch latest release tag from GitHub API
└── Tests/
    ├── BLUR.Tools.Installer.Tests.ps1 # Pester tests for module functions
    └── fixtures/
        └── test-manifest.json         # Minimal manifest for testing
```

#### Module Design Rules

- **PowerShell 7.2+ only** — use `$IsWindows`, `$IsLinux`, `$IsMacOS` built-ins everywhere,
  never `[System.Environment]::OSVersion`
- **No external module dependencies** at install time — the module must be self-contained
  until it can install its own dependencies
- **All public functions** must support `-WhatIf` (ShouldProcess) for dry-run mode
- **All public functions** must accept pipeline input where logical
- **`-Verbose`** must produce meaningful per-step output
- **Return objects**, not strings — callers can format; functions should not
- **`-Force`** flag on Install-* functions bypasses already-installed checks
- **`-SkipVerification`** on Install-* skips the post-install Test-BlurTool call
- Every Install-* function calls `Test-BlurTool` after install and surfaces the result
- Platform detection must happen inside the Private resolver, not scattered across functions

#### Invoke-WingetInstall behaviour
- Accept winget package ID
- `--accept-package-agreements --accept-source-agreements` always passed
- Exit code `-1978335189` (already installed) treated as success
- On failure, emit a structured warning object, do not throw by default

#### Invoke-AptInstall behaviour
- Always run `sudo apt-get install -y` with `-qq` unless `-Verbose`
- Handle apt key/repo setup as a pre-install step defined in the manifest
  (see `aptRepo` field in JSON schema below)
- Support `sudo` detection: if already root, drop sudo

#### Bootstrap behaviour (Linux)
- `Invoke-AptInstall` must check if pwsh is installed first; if not, install it before
  proceeding. This is the only place bash is called — a single `apt-get install -y powershell`
  wrapped by `sudo bash -c` if necessary.

---

### 2. JSON Manifest Schema

**File:** `manifests/tools.json` (primary), with optional split files per group
importable via the `$include` directive.

#### Top-level structure

```json
{
  "$schema": "./schemas/blur-tools-manifest.schema.json",
  "$version": "1.0",
  "groups": { ... }
}
```

#### Group structure

```json
"system": {
  "description": "Core system tooling — required on all machines",
  "subgroups": {
    "base": {
      "description": "Essential CLI utilities",
      "tools": [ ... ]
    },
    "shells": { ... },
    "services": { ... }
  }
}
```

#### Tool entry — full schema

Every field except `id` and `name` is optional. The module resolves which fields apply
based on platform and install method.

```json
{
  "id": "terraform",
  "name": "Terraform",
  "description": "HashiCorp infrastructure-as-code tool",
  "version": "latest",
  "tags": ["iac", "ops", "hashicorp"],
  "platforms": ["windows", "linux", "macos"],

  "install": {
    "method": "package | script | binary | npm | pipx | cargo | go | pwsh-module | manual",

    "windows": {
      "method": "package",
      "packageManager": "winget",
      "packageId": "Hashicorp.Terraform"
    },
    "linux": {
      "method": "package",
      "packageManager": "apt",
      "packageId": "terraform",
      "aptRepo": {
        "keyUrl": "https://apt.releases.hashicorp.com/gpg",
        "keyFile": "/usr/share/keyrings/hashicorp-archive-keyring.gpg",
        "repoLine": "deb [signed-by={keyFile}] https://apt.releases.hashicorp.com {codename} main",
        "listFile": "/etc/apt/sources.list.d/hashicorp.list"
      }
    },
    "macos": {
      "method": "package",
      "packageManager": "brew",
      "packageId": "hashicorp/tap/terraform"
    }
  },

  "configure": {
    "description": "Post-install configuration steps",
    "steps": [
      {
        "id": "set-alias",
        "description": "Set tf alias",
        "type": "shell-alias",
        "alias": "tf",
        "command": "terraform",
        "platforms": ["linux", "macos"],
        "shell": "zsh"
      }
    ]
  },

  "verify": {
    "command": "terraform version",
    "pattern": "Terraform v\\d+",
    "exitCode": 0
  },

  "update": {
    "windows": { "method": "winget-upgrade", "packageId": "Hashicorp.Terraform" },
    "linux":   { "method": "apt-upgrade",    "packageId": "terraform" },
    "macos":   { "method": "brew-upgrade",   "packageId": "terraform" }
  },

  "dependsOn": ["git"],
  "notes": "tenv is recommended for multi-version management — see id: tenv"
}
```

#### Install method reference

| `method` value | Handler | Notes |
|---|---|---|
| `package` | Invoke-WingetInstall / Invoke-AptInstall / Invoke-BrewInstall | `packageManager` selects which |
| `script` | Invoke-ScriptInstall | `scriptUrl`, optional `args` |
| `binary` | Invoke-BinaryInstall | `githubRepo`, `assetPattern`, `installPath` |
| `npm` | Invoke-NpmInstall | `packageId`, optional `global: true` |
| `pipx` | Invoke-PipxInstall | `packageId` |
| `cargo` | Invoke-CargoInstall | `packageId` |
| `go` | Invoke-GoInstall | `packageId` (e.g. `github.com/derailed/k9s@latest`) |
| `pwsh-module` | Install-Module | `moduleId`, `scope`, `repository` |
| `manual` | Write warning + `manualUrl` | For tools with no automatable install |

---

### 3. Full `tools.json` Manifest

Populate the manifest with **all tools from the existing scripts** plus the new
taxonomy below. Every tool must have Windows, Linux, and macOS entries where the tool
is available on that platform. If a tool is not available on a platform, omit the
platform key (do not set to null).

#### Required groups / subgroups / tools

```
system/
  base/
    git
    gh                        (GitHub CLI)
    delta                     (better git diffs)
    jq
    yq
    ripgrep
    fd
    bat
    fzf
    tree
    curl
    wget
    htop
    ncdu
    direnv
    stow
    unzip

  shells/
    powershell7               (pwsh — apt/winget/brew)
    oh-my-posh
    zsh
    fish
    bash                      (latest, macOS/Linux only; skip Windows)
    oh-my-zsh                 (script install)
    powerlevel10k             (git clone into $ZSH_CUSTOM/themes)
    zsh-autosuggestions       (git clone into $ZSH_CUSTOM/plugins)
    zsh-syntax-highlighting   (git clone into $ZSH_CUSTOM/plugins)

  editors/
    vscode
    neovim
    jetbrains-toolbox

  services/
    docker-desktop            (Windows/macOS only — method: manual on Linux, use docker-engine)
    docker-engine             (Linux only — apt, from Docker's own repo)
    docker-cli                (all platforms — CLI only)
    docker-compose-plugin     (Linux — installed alongside docker-engine)
    docker-buildx-plugin      (Linux — installed alongside docker-engine)
    nginx                     (apt/brew/winget)
    apache2                   (apt/brew — id: httpd on brew)
    tomcat                    (manual — Java dependency, provide manualUrl)

  terminal/
    windows-terminal          (Windows only)
    wezterm                   (all platforms)

dev/
  java/
    temurin-21                (Eclipse Temurin JDK 21 LTS — apt/brew/winget)
    temurin-17                (Eclipse Temurin JDK 17 LTS)
    sdkman                    (script install — Linux/macOS; manages JDK versions)
    maven                     (apt/brew/winget)
    gradle                    (apt/brew/winget)

  node/
    nvm                       (script install — Linux/macOS)
    nodejs-lts                (winget on Windows; via nvm on Linux/macOS)
    yarn                      (npm global)
    pnpm                      (npm global)
    typescript                (npm global)
    ts-node                   (npm global)
    aws-cdk                   (npm global)
    serverless-framework      (npm global)

  python/
    python3                   (apt/brew/winget)
    pipx                      (apt/brew/winget)
    poetry                    (pipx)
    black                     (pipx)
    ruff                      (pipx)
    ipython                   (pipx)
    httpie                    (pipx)

  go/
    go                        (binary from go.dev/dl)

  rust/
    rustup                    (script install)
    hyperfine                 (cargo)
    tokei                     (cargo)
    du-dust                   (cargo)
    bottom                    (cargo)

  dotnet/
    dotnet-sdk-8              (apt/brew/winget)

ops/
  cloud/
    aws-cli                   (binary — awscli.amazonaws.com)
    aws-ssm-plugin            (binary — s3 download per platform)
    azure-cli                 (script/apt/brew)
    gcloud                    (apt/brew — google-cloud-cli)
    pulumi                    (script install)

  iac/
    terraform                 (apt/winget/brew via HashiCorp repo)
    opentofu                  (script install)
    tenv                      (binary from GitHub — tofuutils/tenv)
    packer                    (apt/winget/brew via HashiCorp repo)
    ansible                   (pipx)
    ansible-lint              (pipx)

  kubernetes/
    kubectl                   (binary from dl.k8s.io)
    helm                      (script install)
    k9s                       (go install or binary)
    kubectx                   (git clone + symlink or brew)
    kubens                    (included with kubectx)
    kind                      (go install)
    lens                      (winget/brew — GUI, desktop app)

  monitoring/
    prometheus                (binary from GitHub — prometheus/prometheus)
    grafana                   (apt/brew/winget)
    loki                      (binary from GitHub — grafana/loki)
    vector                    (script install — vector.dev)
    datadog-agent             (script install — platform-specific)

  databases/
    dbeaver                   (winget/brew)
    dbgate                    (winget/brew — lighter alternative to DBeaver)
    redis-cli                 (apt/brew — redis-tools package on apt)
    postgresql-client         (apt/brew/winget)

  misc/
    postman                   (winget/brew)
    insomnia                  (winget/brew)
    mkcert                    (winget/brew/apt)
    chezmoi                   (winget/brew/binary)
    winscp                    (winget — Windows only)
    putty                     (winget — Windows only)

  powershell-modules/
    aws-tools-ec2             (pwsh-module: AWS.Tools.EC2)
    aws-tools-s3              (pwsh-module: AWS.Tools.S3)
    aws-tools-iam             (pwsh-module: AWS.Tools.IAM)
    aws-tools-ssm             (pwsh-module: AWS.Tools.SSM)
    aws-tools-secretsmanager  (pwsh-module: AWS.Tools.SecretsManager)
    aws-tools-orgs            (pwsh-module: AWS.Tools.Organizations)
    aws-tools-ecs             (pwsh-module: AWS.Tools.ECS)
    aws-tools-eks             (pwsh-module: AWS.Tools.EKS)
    aws-tools-cfn             (pwsh-module: AWS.Tools.CloudFormation)
    az-module                 (pwsh-module: Az)
    posh-git                  (pwsh-module: Posh-Git)
    psreadline                (pwsh-module: PSReadLine)
    terminal-icons            (pwsh-module: Terminal-Icons)
    importexcel               (pwsh-module: ImportExcel)

sec/
  scanning/
    trivy                     (binary from GitHub — aquasecurity/trivy)
    grype                     (binary from GitHub — anchore/grype)
    syft                      (binary from GitHub — anchore/syft — SBOM)
    semgrep                   (pipx)
    gitleaks                  (binary from GitHub — gitleaks/gitleaks)
    trufflehog                (binary from GitHub — trufflesecurity/trufflehog)
    checkov                   (pipx — IaC scanning)
    tfsec                     (binary from GitHub — aquasecurity/tfsec)
    kube-bench                (binary from GitHub — aquasecurity/kube-bench)

  secrets/
    git-secrets               (script/source build — awslabs/git-secrets)
    detect-secrets            (pipx)
    sops                      (binary from GitHub — getsops/sops)
    age                       (apt/brew/binary)
    gnupg                     (apt/brew/winget)
    mkcert                    (winget/brew — also in ops/misc)
    hashicorp-vault           (apt/brew/winget via HashiCorp repo)

  compliance/
    pre-commit                (pipx)
    commitlint                (npm global)
    husky                     (npm global)
    osquery                   (binary from GitHub — osquery/osquery)
```

---

### 4. Entry-Point Scripts

These replace the old numbered scripts. They are thin wrappers around the module.

#### `Install-Workstation.ps1` — main interactive entry point

```powershell
# Usage examples:
#   .\Install-Workstation.ps1 -Groups system,dev
#   .\Install-Workstation.ps1 -Groups system -Subgroups base,shells
#   .\Install-Workstation.ps1 -Tools git,terraform,kubectl
#   .\Install-Workstation.ps1 -Profile developer    # loads a named profile
#   .\Install-Workstation.ps1 -All                  # installs everything
#   .\Install-Workstation.ps1 -WhatIf               # dry run
#   .\Install-Workstation.ps1 -ConfigureOnly        # skip install, run config steps
#   .\Install-Workstation.ps1 -VerifyOnly           # smoke test only
```

#### `bootstrap.ps1` — zero-dependency first-run bootstrapper (Windows)

Installs PowerShell 7 via winget if not present, then calls `Install-Workstation.ps1`.
Must work from a `Invoke-Expression (Invoke-WebRequest ...)` one-liner.

#### `bootstrap.sh` — Linux/macOS bootstrapper

The **only** bash script in the project. Its sole job:

```bash
#!/usr/bin/env bash
# 1. Detect distro (apt/brew)
# 2. Install PowerShell 7
# 3. exec pwsh ./Install-Workstation.ps1 "$@"
```

All subsequent logic is PowerShell.

#### `Configure-Workstation.ps1` — post-install configuration only

Runs `Invoke-BlurConfiguration` for specified groups/tools without reinstalling.

#### `Update-Workstation.ps1` — updater

Wraps `Update-BlurGroup` / `Update-BlurTool` with a menu or `-All` flag.

#### `Test-Workstation.ps1` — verification only

Runs `Test-BlurTool` across specified or all installed tools, outputs a pass/fail table.

---

### 5. Profiles JSON

**File:** `profiles/`

Pre-defined install profiles composing groups for common personas.
Each profile is a JSON file or a named entry in `profiles.json`.

```json
{
  "profiles": {
    "minimal": {
      "description": "Bare minimum — git, shells, VS Code",
      "groups": ["system/base", "system/shells", "system/editors"]
    },
    "developer": {
      "description": "Full dev workstation",
      "groups": ["system", "dev"],
      "exclude": ["dev/dotnet"]
    },
    "devops": {
      "description": "DevOps / cloud engineer",
      "groups": ["system", "dev", "ops"],
      "exclude": ["dev/java", "dev/dotnet"]
    },
    "security": {
      "description": "Security engineer",
      "groups": ["system", "dev", "ops", "sec"]
    },
    "windows-wsl": {
      "description": "Windows workstation with WSL2",
      "groups": ["system", "dev", "ops"],
      "windowsExtras": {
        "features": [
          "Microsoft-Windows-Subsystem-Linux",
          "VirtualMachinePlatform",
          "Microsoft-Hyper-V",
          "HypervisorPlatform",
          "Containers"
        ],
        "wslDistro": "Ubuntu-24.04",
        "wslConfig": {
          "memory": "auto",
          "processors": "auto",
          "swap": "auto",
          "sparseVhd": true,
          "autoMemoryReclaim": "gradual"
        }
      }
    }
  }
}
```

---

### 6. Configuration System

Separate installation from configuration. Each tool's `configure` block in the JSON
defines what `Invoke-BlurConfiguration` applies. Configuration types:

| `type` | What it does |
|---|---|
| `git-config` | Runs `git config --global key value` |
| `shell-alias` | Appends alias to the appropriate shell profile |
| `shell-export` | Appends `export VAR=value` to shell profile |
| `shell-source` | Appends `source <(command)` for completions |
| `powershell-profile` | Appends a block to `$PROFILE` |
| `file-write` | Writes a config file to a specified path |
| `file-append` | Appends content to an existing file |
| `symlink` | Creates a symlink |
| `directory` | Ensures a directory exists |
| `chmod` | Sets file permissions (Linux/macOS) |
| `registry` | Sets a Windows registry value |
| `service` | Enables/starts/stops a system service |
| `wsl-config` | Writes or patches `.wslconfig` on Windows |
| `windows-feature` | Enables a Windows optional feature via DISM |
| `env-var` | Sets a persistent environment variable |
| `run-once` | Runs a command once, tracked by a stamp file |

#### Example: git configure block

```json
"configure": {
  "steps": [
    {
      "id": "git-user-email",
      "type": "git-config",
      "key": "user.email",
      "valueFrom": "prompt",
      "promptText": "Enter your Git email address"
    },
    {
      "id": "git-user-name",
      "type": "git-config",
      "key": "user.name",
      "valueFrom": "prompt",
      "promptText": "Enter your Git display name"
    },
    {
      "id": "git-default-branch",
      "type": "git-config",
      "key": "init.defaultBranch",
      "value": "main"
    },
    {
      "id": "git-credential-helper-windows",
      "type": "git-config",
      "key": "credential.helper",
      "value": "manager",
      "platforms": ["windows"]
    },
    {
      "id": "git-credential-helper-wsl",
      "type": "git-config",
      "key": "credential.helper",
      "value": "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe",
      "platforms": ["linux"],
      "condition": "Test-Path '/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe'"
    }
  ]
}
```

#### `valueFrom` options

- `"literal"` (default) — use `value` field directly
- `"prompt"` — interactive `Read-Host` with `promptText`
- `"env"` — read from environment variable named in `envVar`
- `"command"` — result of running `command` field
- `"auto"` — module logic determines the value (e.g. memory = 50% of RAM)

---

### 7. Windows-Specific Extras

The Windows-specific concerns from the old scripts must be preserved as first-class
features of the module, not bolted-on edge cases.

#### WSL Management (`Private/Invoke-WslSetup.ps1`)

Expose as `Invoke-BlurWslSetup` (Public). Driven entirely by the profile's
`windowsExtras.wslConfig` block. The `memory: "auto"` and `processors: "auto"` values
must trigger the same auto-detection logic from `04-Configure-WSL.ps1`
(50% RAM, total_cores - 2).

#### Windows Features (`Private/Invoke-WindowsFeature.ps1`)

Wrap DISM enable-feature as a configuration step type `windows-feature`. Reboot
detection: if any feature requires reboot, collect them all, warn once at the end,
and offer a single reboot prompt rather than rebooting mid-install.

#### Hyper-V VM creation

Move `07-Hyper-V-Setup.ps1` logic into a dedicated public function
`New-BlurHyperVDevVm` with parameters matching the existing prompts, callable
standalone or from a profile that includes a `hyperv` block.

---

### 8. Logging and Output

#### `Write-BlurLog` signature

```powershell
Write-BlurLog -Level Step|Done|Warn|Fail|Info -Message <string> [-Tool <string>] [-Group <string>]
```

- Output goes to the host (coloured) AND to a log file at
  `$env:TEMP\BLUR.Tools.Installer\<timestamp>.log` (plain text, no ANSI codes)
- Each log line: `[ISO8601] [LEVEL] [tool/group] message`
- The log path is exposed as `$env:BLUR_LOG_PATH` after first write

#### Install result object

Every Install-* function must return a `[PSCustomObject]` with at minimum:

```powershell
[PSCustomObject]@{
    Tool        = <string>
    Group       = <string>
    Platform    = <string>
    Status      = 'Installed' | 'AlreadyInstalled' | 'Failed' | 'Skipped' | 'WhatIf'
    Version     = <string>    # populated by verify step
    Duration    = <TimeSpan>
    Error       = <string>    # null on success
}
```

---

### 9. Testing

Use **Pester 5** for all tests. Tests live in `Tests/`. At minimum:

- `Resolve-Platform` returns correct value on the current host
- `Get-BlurManifest` loads and validates the schema correctly
- `Install-BlurTool` with `-WhatIf` returns a WhatIf result object without invoking
  any package manager
- `Test-BlurTool` returns correct structure for a tool known to be installed (git)
- `Test-BlurTool` returns a Fail result for a tool that cannot exist (`fake-tool-xyz`)
- Mock tests for `Invoke-WingetInstall`, `Invoke-AptInstall`, `Invoke-BrewInstall`
  verifying correct arguments are constructed from manifest entries
- Schema validation test: every tool in `tools.json` has a valid `verify` block

---

### 10. Project Layout

```
blur-tools-installer/
├── README.md
├── Install-Workstation.ps1           # main entry point
├── Configure-Workstation.ps1
├── Update-Workstation.ps1
├── Test-Workstation.ps1
├── bootstrap.ps1                     # Windows zero-dep bootstrapper
├── bootstrap.sh                      # Linux/macOS one-liner (bash → pwsh)
│
├── BLUR.Tools.Installer/             # The module
│   ├── BLUR.Tools.Installer.psd1
│   ├── BLUR.Tools.Installer.psm1
│   ├── Public/
│   ├── Private/
│   └── Tests/
│
├── manifests/
│   ├── tools.json                    # Full tool manifest
│   ├── schemas/
│   │   └── blur-tools-manifest.schema.json   # JSON Schema for validation
│   └── overrides/
│       └── README.md                 # How to write local overrides
│
├── profiles/
│   ├── profiles.json
│   ├── minimal.json
│   ├── developer.json
│   ├── devops.json
│   ├── security.json
│   └── windows-wsl.json
│
└── docs/
    ├── adding-a-tool.md
    ├── adding-a-profile.md
    └── cross-platform-notes.md
```

---

## Constraints and Non-Negotiables

1. **PowerShell 7 is the runtime everywhere** — no PowerShell 5, no bash logic beyond
   the bootstrap one-liner
2. **JSON drives everything** — no tool IDs, package IDs, or config values hardcoded in
   `.ps1` files. Scripts read from manifests.
3. **Install and Configure are always separate concerns** — `Install-BlurTool git` never
   runs git config steps. `Invoke-BlurConfiguration git` does.
4. **`-WhatIf` must work on every public function** — implement `ShouldProcess` correctly
5. **The module must be importable on a clean machine** with only PowerShell 7 and
   internet access. No other prerequisites.
6. **Cross-platform paths** — use `Join-Path`, `$HOME`, `$env:TEMP`, never hardcode
   `/home/user` or `C:\Users`
7. **All apt operations require sudo** — but the module must not assume it is running as
   root. Use `sudo` explicitly and handle the case where the user lacks sudo rights with
   a clear error.
8. **Do not shell out to bash from PowerShell** unless unavoidable (brew install on macOS
   may require it for PATH reasons — document this if so)
9. **The module name `BLUR.Tools.Installer` is fixed** — this is the published module name
10. **Preserve all existing tool selections** from the 8 source scripts — nothing is
    dropped without a note in the manifest's `notes` field

---

## Suggested Implementation Order for Claude Code

1. **Scaffold the project structure** — empty files, module manifest, psm1 dot-source stub
2. **Implement `Resolve-Platform`** and its tests — foundation for everything else
3. **Implement `Get-BlurManifest`** with JSON Schema validation
4. **Implement `Write-BlurLog`**
5. **Implement the three package manager private functions** (winget, apt, brew) with mocks
6. **Implement `Install-BlurTool`** (single tool, calls resolver + correct package manager)
7. **Implement `Test-BlurTool`**
8. **Implement `Install-BlurGroup`** (iterates tools, respects `dependsOn`)
9. **Implement `Invoke-BlurConfiguration`** and all configuration step types
10. **Write the full `tools.json` manifest** — all tools from existing scripts + taxonomy above
11. **Write `profiles.json`** and the named profile files
12. **Write entry-point scripts** (`Install-Workstation.ps1`, etc.)
13. **Write `bootstrap.ps1` and `bootstrap.sh`**
14. **Write Pester tests** for all public functions
15. **Write `docs/`** — adding-a-tool guide is the most important

Start with step 1 and proceed sequentially. At each step, confirm the interface
contract (function signatures, return types, JSON schema fields) before filling in
implementation. This makes later refactoring minimal.
