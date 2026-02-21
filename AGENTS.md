# Agent Instructions

Instructions for AI coding agents working on this nix-config repository.

## Dev Environment

- This is a Nix flake. Use `nix develop` to enter the dev shell (when `devShells` exist).
- Edit `flake.nix` for system packages, Homebrew casks, and nix-darwin options.
- The project uses `.cursor/skills/nix-best-practices` — follow those patterns for flakes, overlays, unfree handling, and binary overlays.

## Build Commands

| Target | Command |
|--------|---------|
| macOS (hammerhead) | `darwin-rebuild switch --flake .#hammerhead` |
| NixOS | `sudo nixos-rebuild switch --flake .#nixos-desktop` |
| Windows (WSL) | `home-manager switch --flake .#user@windows-wsl` |

Update inputs before rebuild: `nix flake update`

## Coding Conventions

- **Hosts are thin**: Host configs import modules; keep logic in modules.
- **Modules are reusable**: Shared logic in `modules/shared`, platform-specific in `modules/nixos`, `modules/darwin`, `modules/home`.
- **Avoid duplication**: Prefer shared modules over copy-paste.
- **Declarative**: Keep configuration declarative; avoid imperative scripts in config.

## Repository Structure

```
nix-config/
├─ flake.nix
├─ flake.lock
├─ hosts/           # Host-specific entrypoints (hostname, hardware, module imports)
├─ modules/
│  ├─ shared/       # Cross-platform: CLI, Git, shell, dev tooling
│  ├─ nixos/        # Linux: bootloader, drivers, services, networking
│  ├─ darwin/       # macOS: system defaults, Homebrew, launchd
│  └─ home/         # User-level: Neovim, Tmux, shell, editor tooling
├─ home/
└─ overlays/        # Custom package overrides or local derivations
```

## Adding a New Machine

1. Create `hosts/<new-host>/default.nix`
2. Import appropriate modules
3. Add configuration entry in `flake.nix` (e.g. `darwinConfigurations."<name>"` or `nixosConfigurations."<name>"`)
4. Rebuild using the corresponding target command

## Editing flake.nix

- **System packages**: Add to `environment.systemPackages` in the configuration.
- **Homebrew**: Add casks to `homebrew.casks`, brews to `homebrew.brews`.
- **Hostname change**: Update `networking.hostName` and rename the `darwinConfigurations."<name>"` key to match.
- Use `follows` for overlay inputs to avoid duplicate nixpkgs (see nix-best-practices skill).

## Future Extensions (Context)

Planned but not yet implemented:

- Secrets management (agenix/sops)
- CI build validation
- Multi-user support
- Remote deployment targets
