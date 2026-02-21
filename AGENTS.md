# Agent Instructions

Instructions for AI coding agents working on this nix-config repository.

## Dev Environment

- This is a Nix flake with a layered architecture. Use `nix develop` to enter the shared dev shell.
- The project uses `.cursor/skills/nix-best-practices` — follow those patterns for flakes, overlays, unfree handling, and binary overlays.

## Architecture (Layered)

| Layer | Purpose | Where to edit |
|-------|---------|---------------|
| System config | Minimal base OS (git, vim, curl, nix) | `modules/shared`, `modules/darwin`, `modules/nixos` |
| Home Manager | Shell/editor config, tools needed in every shell | `modules/home` |
| devShells | Language toolchains, build tools, dev-scoped packages | `devShells` in `flake.nix` |

### Rule of Thumb

- Needed in every shell (ripgrep, fd, zoxide, direnv) → `modules/home` (Home Manager)
- Needed for development generally (jq, just) → shared devShell in `flake.nix`
- Project-specific tooling → project-level flake, not this repo
- GUI apps on macOS → `modules/darwin` (Homebrew casks)
- Base OS plumbing (git, nix, coreutils) → `modules/shared` (system packages)

### Automatic Shell Activation

direnv + nix-direnv are configured via Home Manager. Projects with a `.envrc` containing `use flake` will auto-load their devShell on `cd`.

## Build Commands

| Target | Command |
|--------|---------|
| macOS (hammerhead) | `darwin-rebuild switch --flake .#hammerhead` |
| NixOS | `sudo nixos-rebuild switch --flake .#nixos-desktop` |
| Windows (WSL) | `home-manager switch --flake .#user@windows-wsl` |

Update inputs before rebuild: `nix flake update`

## Coding Conventions

- **Hosts are thin**: Host configs import modules and wire up home-manager; keep logic in modules.
- **Modules are reusable**: Shared logic in `modules/shared`, platform-specific in `modules/nixos`, `modules/darwin`, user-level in `modules/home`.
- **Avoid duplication**: Prefer shared modules over copy-paste.
- **Declarative**: Keep configuration declarative; avoid imperative scripts in config.
- **System packages stay minimal**: Only git, vim, curl, and nix belong in system packages. Everything else goes to Home Manager or devShells.

## Repository Structure

```
nix-config/
├─ flake.nix          # Inputs, darwinConfigurations, devShells
├─ flake.lock
├─ hosts/             # Host-specific entrypoints (thin: imports + wiring)
├─ modules/
│  ├─ shared/         # Cross-platform system base: nix settings, git, vim
│  ├─ nixos/          # Linux: bootloader, drivers, services, networking
│  ├─ darwin/         # macOS: system defaults, Homebrew casks, Touch ID
│  └─ home/           # Home Manager: shell, direnv, CLI tools, editor
├─ home/
└─ overlays/          # Custom package overrides or local derivations
```

## Adding a New Machine

1. Create `hosts/<new-host>/default.nix`
2. Import `modules/shared`, platform module, and `home-manager.<platform>Modules.home-manager`
3. Configure `home-manager.users.<username> = import ../../modules/home`
4. Add configuration entry in `flake.nix` (e.g. `darwinConfigurations."<name>"` or `nixosConfigurations."<name>"`)
5. Rebuild using the corresponding target command

## Adding Tools

- **CLI tool for every shell**: Add to `home.packages` in `modules/home/default.nix`
- **Dev tool**: Add to `devShells.default.buildInputs` in `flake.nix`
- **macOS GUI app**: Add to `homebrew.casks` in `modules/darwin/default.nix`
- **System-level package**: Only if truly needed globally — add to `modules/shared/default.nix`
- Use `follows` for overlay inputs to avoid duplicate nixpkgs (see nix-best-practices skill).

## Future Extensions (Context)

Planned but not yet implemented:

- Secrets management (agenix/sops)
- CI build validation
- Multi-user support
- Remote deployment targets
