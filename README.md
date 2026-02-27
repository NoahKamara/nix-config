# Nix Configuration Monorepo

Declarative, flake-based system configuration for:

* macOS (via nix-darwin)
* NixOS (Linux workstation)
* Windows (via WSL + Home Manager)

This repository provides a single source of truth for system, user, and development environments across machines.

---

## Goals

* Single flake for all machines
* Reusable modules
* Clear host separation
* Reproducible development environments
* Minimal duplication

---

## Setup macOS

This section covers bootstrapping and daily use on macOS via nix-darwin.

### Prerequisites

* Install Nix (Lix works too) so `nix` is available on your `PATH`.
* If you hit build failures later, install Xcode Command Line Tools: `xcode-select --install`

**Lix users:** If `nix` isn't found after installing Lix:

* Use the full path: `/nix/var/nix/profiles/default/bin/nix`
* Or source the profile script (zsh/bash): `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`

### Bootstrap nix-darwin

Install [nix-darwin](https://github.com/nix-darwin/nix-darwin). Use `sudo -i` instead of plain `sudo` due to [this issue](https://github.com/nix-darwin/nix-darwin/issues/1527).

This flake defines `darwinConfigurations.hammerhead`.

**First switch** (works even before `darwin-rebuild` is on your PATH):

```bash
nix --extra-experimental-features "nix-command flakes" \
  run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake .#hammerhead"
```

**Subsequent switches:**

```bash
darwin-rebuild switch --flake ".#hammerhead"
```

### Update inputs

```bash
nix flake update
darwin-rebuild switch --flake ".#hammerhead"
```

### Customize

* Edit `flake.nix` to add packages under `environment.systemPackages`.
* If this machine's hostname changes, update `networking.hostName` and rename `darwinConfigurations."hammerhead"`.

---

## Supported Targets

### macOS

Managed via nix-darwin and Home Manager. See [Setup macOS](#setup-macos) for bootstrap and usage.

Build:

```bash
darwin-rebuild switch --flake .#hammerhead
```

### NixOS

Full declarative system.

Build:

```bash
sudo nixos-rebuild switch --flake .#nebulon
```

### Windows (WSL)

User-level configuration via Home Manager inside WSL.

Build:

```bash
home-manager switch --flake .#user@windows-wsl
```

Windows remains native for gaming; development happens inside WSL.

---

## Development Shells

You can manually enter the default development shell (with `jq`, `just`, etc.) by running:

```bash
nix develop
```

Or you can enter a specific shell (like the Swift environment) by running:

```bash
nix develop .#swift
```

### Automatic Environment Activation (direnv + Cursor)

This repository includes `direnv` and `nix-direnv` setup via Home Manager to automatically load these shells when you `cd` into a project directory. 

**1. Configure the Project Folder**
In your specific project folder, create a `.envrc` file to point to the desired shell in this flake:

* For the **Swift** shell: `echo "use flake ~/Tools/nix-config#swift" > .envrc`
* For the **Default** shell: `echo "use flake ~/Tools/nix-config" > .envrc`

**2. Allow the Environment**
Navigate to the folder in your terminal and allow the environment:

```bash
direnv allow
```

**3. Use in Cursor IDE**
To make Cursor recognize these tools (for language servers, formatters like `swiftformat`, etc.), you have two options:
* **Option A (Recommended)**: Install the **`direnv`** extension (`mkhl.direnv`) in Cursor. It will automatically load the Nix environment when you open the folder.
* **Option B**: Launch Cursor directly from the activated terminal (`cursor .`), which passes the Nix environment variables to the editor.

---

Optional per-project shells can be added under `devShells` in `flake.nix`.

---

For AI agents: see [AGENTS.md](AGENTS.md) for build commands, coding conventions, repository structure, and editing guidance.
